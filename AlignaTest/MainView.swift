import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit
import UIKit

func getAddressFromCoordinate(
    _ coordinate: CLLocationCoordinate2D,
    preferredLocale: Locale = Locale(identifier: "en_US"),
    completion: @escaping (String?) -> Void
) {
    let geocoder = CLGeocoder()
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

    func humanReadable(from p: CLPlacemark) -> String? {
        let candidates: [String?] = [
            p.locality,
            p.subLocality,
            p.administrativeArea,
            p.subAdministrativeArea,
            p.name,
            p.country
        ]

        if let picked = candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty && !isCoordinateLikeString($0) }) {
            return picked
        }
        return nil
    }

    func reverse(allowRetry: Bool) {
        geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { placemarks, error in
            if let p = placemarks?.first, let name = humanReadable(from: p) {
                completion(name)
                return
            }
            if let e = error as? CLError, e.code == .geocodeFoundNoResult, allowRetry {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    reverse(allowRetry: false)
                }
                return
            }
            completion(nil)
        }
    }

    reverse(allowRetry: true)
}

func isCoordinateLikeString(_ s: String) -> Bool {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let pattern = #"^\s*-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?\s*$"#
    return trimmed.range(of: pattern, options: .regularExpression) != nil
}

enum AlignaType {
    static func logo() -> Font { .custom("Merriweather-Black", size: 50) }
    static func brandTitle() -> Font { .custom("Merriweather-Black", size: 34) }
    static func expandedMantraBoldItalic() -> Font { .custom("Merriweather-Bold", size: 23) }

    static func homeSubtitle() -> Font { .custom("Merriweather-Italic", size: 18) }

    static func gridCategoryTitle() -> Font { .custom("Merriweather-Bold", size: 18) }
    static func gridItemName() -> Font { .custom("Merriweather-Light", size: 16) }

    static func loadingSubtitle() -> Font { .custom("Merriweather-Italic", size: 16) }
    static func helperSmall() -> Font { .custom("Merriweather-Light", size: 14) }

    static let logoLineSpacing: CGFloat = 44 - 38
    static let descLineSpacing: CGFloat = 26 - 18
    static let body16LineSpacing: CGFloat = 22 - 16
    static let small14LineSpacing: CGFloat = 20 - 14
}

struct SafeImage: View {
    let name: String
    let renderingMode: Image.TemplateRenderingMode?
    let contentMode: ContentMode

    init(
        name: String,
        renderingMode: Image.TemplateRenderingMode? = .template,
        contentMode: ContentMode = .fit
    ) {
        self.name = name
        self.renderingMode = renderingMode
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .renderingMode(renderingMode)
                    .resizable()
                    .aspectRatio(contentMode: contentMode == .fit ? .fit : .fill)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: contentMode == .fit ? .fit : .fill)
                    .opacity(0.5)
            }
        }
        .accessibilityLabel(Text(name.isEmpty ? "image" : name))
    }
}

struct MainView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var soundPlayer: SoundPlayer
    
    @EnvironmentObject var reasoningStore: DailyReasoningStore
    
    @AppStorage("lastRecommendationDate") var lastRecommendationDate: String = ""
    @AppStorage("lastRecommendationPlace") var lastRecommendationPlace: String = ""   // ✅ NEW
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("lastCurrentPlaceUpdate") var lastCurrentPlaceUpdate: String = ""
    @AppStorage("todayFetchLock") private var todayFetchLock: String = ""
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @AppStorage("didDeleteAccount") private var didDeleteAccount: Bool = false
    @AppStorage("dailyMantraNotificationEnabled") private var dailyMantraNotificationEnabled: Bool = false
    @AppStorage("dailyMantraNotificationHour") private var dailyMantraNotificationHour: Int = 9
    @AppStorage("dailyMantraNotificationMinute") private var dailyMantraNotificationMinute: Int = 0
    @AppStorage("cachedDailyMantra") private var cachedDailyMantra: String = ""
    @AppStorage("lastRecommendationTimestamp") private var lastRecommendationTimestamp: Double = 0
    @AppStorage("lastRecommendationHasFullSet") private var lastRecommendationHasFullSet: Bool = false
    @AppStorage("lastManualRefreshTimestamp") private var lastManualRefreshTimestamp: Double = 0
    @AppStorage("shouldExpandMantraOnBoot") private var shouldExpandMantraOnBoot: Bool = false
    @AppStorage("shouldExpandMantraFromNotification") private var shouldExpandMantraFromNotification: Bool = false
    @State private var isFetchingToday: Bool = false
    
    @State private var isMantraExpanded: Bool = false
    @State private var showMantraSaveAlert: Bool = false
    @State private var showTodaySoundPlayer: Bool = false
    @State private var isAutoDismissSoundPlayer = false
    @State private var soundPlayerAutoDismissTask: Task<Void, Never>? = nil
    @State private var showNoSoundToast: Bool = false
    @State private var journalSpinAngle: Double = 0
    @State private var lastPrefetchedSoundKey: String = ""
    @State private var mantraSaveMessage: String = ""

    @State private var showReasoningBubble: Bool = false
    @State private var showRefreshCooldownAlert = false
    @State private var refreshCooldownMessage = ""
    @State private var isManualRefreshFlow = false

    @AppStorage("todayAutoRefetchDone") private var todayAutoRefetchDone: String = ""
    @AppStorage("shouldShowBootLoading") private var shouldShowBootLoading: Bool = false

    @State private var autoRefetchScheduled = false

    @State private var authListenerHandle: AuthStateDidChangeListenerHandle? = nil
    @State private var authWaitTimedOut = false
    @State private var didResolveBootPath = false
    @State private var isBootDataReady = false
    @State private var didCompletePersonalCheckIn = false
    @State private var pendingMantraExpansion = false
    @State private var isMantraReady = false

    @AppStorage("watchdogDay") private var watchdogDay: String = ""
    @AppStorage("todayAutoRefetchAttempts") private var todayAutoRefetchAttempts: Int = 0

    // NEW: 多次重试的配置
    private let maxRefetchAttempts = 3
    private let initialRefetchDelay: TimeInterval = 8.0

    @StateObject private var locationManager = LocationManager()
    @State private var recommendationTitles: [String: String] = [:]
    
    @State private var selectedDate = Date()
    @State private var mainNavigationPath = NavigationPath()
    
    @State private var bootPhase: BootPhase = .loading
    
    @State private var didBootVisuals = false
    @State private var shouldCollapseMantraOnReturn = false

    private var hasRecentRecommendation: Bool {
        guard lastRecommendationHasFullSet else { return false }
        let age = Date().timeIntervalSince1970 - lastRecommendationTimestamp
        return age >= 0 && age < 24 * 60 * 60
    }

    private let colorHexMapping: [String:String] = [
        "amber":"#FFBF00", "cream":"#FFFDD0", "forest_green":"#228B22",
        "ice_blue":"#ADD8E6", "indigo":"#4B0082", "rose":"#FF66CC",
        "sage_green":"#9EB49F", "silver_white":"#C0C0C0", "slate_blue":"#6A5ACD",
        "teal":"#008080"
    ]

    private func todayColorHex() -> String? {
        let key = viewModel.recommendations["Color"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return colorHexMapping[key]
    }

    private func ensureDefaultsIfMissing() {
        // If nothing loaded yet, supply local demo content
        if viewModel.recommendations.isEmpty {
            viewModel.recommendations = DesignRecs.docs
            viewModel.dailyMantra = viewModel.dailyMantra.isEmpty ? DesignRecs.mantra : viewModel.dailyMantra
        }
        if viewModel.dailyMantra.isEmpty, !cachedDailyMantra.isEmpty {
            viewModel.dailyMantra = cachedDailyMantra
        }
        // If we don’t have human-facing titles yet, use local titles
        if recommendationTitles.isEmpty {
            recommendationTitles = DesignRecs.titles
        }
    }
    
    private var updatedOnText: String {
        let date = lastRecommendationDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateText = date.isEmpty ? todayString() : date

        let p = (lastRecommendationPlace.isEmpty ? viewModel.currentPlace : lastRecommendationPlace)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if p.isEmpty {
            return "Updated on \(dateText)"
        } else {
            return "Updated on \(dateText), \(p)"
        }
    }
    private var updatedOnFooterText: String {
        updatedOnText.replacingOccurrences(of: "Updated on", with: "updated on")
    }

    private var todaySoundKey: String {
        viewModel.recommendations["Sound"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isTodaySoundPlaying: Bool {
        !todaySoundKey.isEmpty
            && soundPlayer.isPlaying
            && soundPlayer.currentSoundKey == todaySoundKey
    }

    private var isTodaySoundLoading: Bool {
        !todaySoundKey.isEmpty
            && soundPlayer.isLoading
            && soundPlayer.currentSoundKey == todaySoundKey
    }

    private var noSoundToastView: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("No sound today")
                .font(.custom("Merriweather-Regular", size: 12))
        }
        .foregroundColor(themeManager.primaryText.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .accessibilityLabel("No sound recommendation")
    }

    private func showNoSoundToastIfNeeded() {
        guard !showNoSoundToast else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            showNoSoundToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.2)) {
                showNoSoundToast = false
            }
        }
    }

    private func scheduleSoundPlayerAutoDismiss() {
        isAutoDismissSoundPlayer = true
        soundPlayerAutoDismissTask?.cancel()
        soundPlayerAutoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard showTodaySoundPlayer, isAutoDismissSoundPlayer else { return }
            showTodaySoundPlayer = false
        }
    }

    
    private var mainContent: some View {
        NavigationStack(path: $mainNavigationPath) {
            ZStack {
                // ✅ Full-screen background, not constrained by inner GeometryReader
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                // ✅ Foreground content uses GeometryReader for layout
                GeometryReader { geometry in
                    let minLength = min(geometry.size.width, geometry.size.height)

                    VStack(spacing: minLength * 0.015) {
                        // 顶部按钮
                        HStack {
                            
                            HStack(spacing: geometry.size.width * 0.035) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        journalSpinAngle += 360
                                    }
                                    handleManualRefreshTap()
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 20))
                                        .foregroundColor(themeManager.primaryText)
                                        .frame(width: 28, height: 28)
                                        .rotationEffect(.degrees(journalSpinAngle))
                                }
                                .disabled(isFetchingToday || isManualRefreshFlow)
                                .accessibilityLabel("Refresh")
                            }
                            .padding(.leading, geometry.size.width * 0.05)

                            Spacer()

                            HStack(spacing: geometry.size.width * 0.02) {

                                if isLoggedIn {
                                    NavigationLink(
                                        destination: ProfileView(viewModel: OnboardingViewModel())
                                            .environmentObject(starManager)
                                            .environmentObject(themeManager)
                                    ) {
                                        Image("account")
                                            .resizable()
                                            .renderingMode(.template)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(themeManager.primaryText)
                                    }
                                } else {
                                    NavigationLink(
                                        destination: ProfileView(viewModel: OnboardingViewModel())
                                    ) {
                                        Image("account")
                                            .resizable()
                                            .renderingMode(.template)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(themeManager.primaryText)
                                    }
                                }
                            }
                            .padding(.trailing, geometry.size.width * 0.05)

                        }

                        // ✅ 只保留按钮本身（气泡放到全局 overlay）
                        Text("Daily Rhythm")
                            .font(.custom("Merriweather-SemiBold", size: 34))
                            .lineSpacing(AlignaType.logoLineSpacing)
                            .foregroundColor(themeManager.primaryText)
                            .padding(.top, 20)
                        .opacity(isMantraExpanded ? 0 : 1)
                        .scaleEffect(isMantraExpanded ? 0.92 : 1)
                        .frame(height: isMantraExpanded ? 0 : nil)
                        .allowsHitTesting(false)




                        Button {
                            guard isMantraReady else { return }
                            withAnimation(.easeInOut(duration: 0.45)) {
                                isMantraExpanded.toggle()
                            }
                        } label: {
                            Group {
                                if isMantraExpanded {
                                    Text(viewModel.dailyMantra)
                                        .font(AlignaType.expandedMantraBoldItalic())
                                        .lineSpacing(12)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(
                                            themeManager.primaryText.opacity(themeManager.isNight ? 0.94 : 0.88)
                                        )
                                        .padding(.horizontal, geometry.size.width * 0.14)
                                        .padding(.top, geometry.size.height * 0.16)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text(viewModel.dailyMantra)
                                        .font(AlignaType.homeSubtitle())
                                        .lineSpacing(AlignaType.descLineSpacing)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(themeManager.descriptionText)
                                        .padding(.horizontal, geometry.size.width * 0.1)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: isMantraExpanded ? .infinity : nil, alignment: isMantraExpanded ? .top : .center)
                            .opacity(isMantraReady ? 1 : 0)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .allowsHitTesting(isMantraReady)
                        
                        if isMantraExpanded {
                            HStack(spacing: 12) {
                                Button {
                                    presentMantraShareSheet()
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(AlynnaTypography.font(.footnote))
                                        .foregroundColor(themeManager.primaryText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                }
                                .alert("Share failed", isPresented: $showMantraSaveAlert) {
                                    Button("OK", role: .cancel) { }
                                } message: {
                                    Text(mantraSaveMessage)
                                }

                                Button {
                                    if isTodaySoundPlaying {
                                        soundPlayer.pause()
                                    } else if todaySoundKey.isEmpty {
                                        showNoSoundToastIfNeeded()
                                    } else {
                                        soundPlayer.playSound(named: todaySoundKey)
                                        showTodaySoundPlayer = true
                                        scheduleSoundPlayerAutoDismiss()
                                    }
                                } label: {
                                    Group {
                                        if isTodaySoundLoading {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(themeManager.primaryText)
                                        } else if isTodaySoundPlaying {
                                            Image(systemName: "pause.fill")
                                                .font(AlynnaTypography.font(.footnote))
                                                .foregroundColor(themeManager.primaryText)
                                                .breathingIcon(scale: 1.06, minOpacity: 0.8, duration: 1.6)
                                        } else {
                                            Image(systemName: "play.fill")
                                                .font(AlynnaTypography.font(.footnote))
                                                .foregroundColor(
                                                    themeManager.primaryText.opacity(todaySoundKey.isEmpty ? 0.35 : 1)
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showTodaySoundPlayer, onDismiss: {
                                    isAutoDismissSoundPlayer = false
                                    soundPlayerAutoDismissTask?.cancel()
                                    soundPlayerAutoDismissTask = nil
                                }) {
                                    PlayerPopup(
                                        documentName: todaySoundKey,
                                        dismiss: { showTodaySoundPlayer = false }
                                    )
                                    .presentationBackground(.clear)
                                    .presentationDetents([.fraction(0.6), .large])
                                    .presentationDragIndicator(.visible)
                                    .presentationCornerRadius(24)
                                }

                                let colorDoc = viewModel.recommendations["Color"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                let colorHex = todayColorHex() ?? "#CBBBA0"
                                Button {
                                    if !colorDoc.isEmpty {
                                        mainNavigationPath.append(RecCategory.Color)
                                    }
                                } label: {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .opacity(colorDoc.isEmpty ? 0.4 : 1)
                                }
                                .buttonStyle(.plain)
                                .disabled(colorDoc.isEmpty)
                            }
                            .padding(.top, 8)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.25), value: isMantraExpanded)
                        }
                        // ✅ 当 mantra 更新（新的一天/重新拉取）时，自动收起回 “...”
                        
                        if !isMantraExpanded {
                            let totalH = geometry.size.height
                            let mantraToGridGap = totalH * 0.12
                            let gridToFooterGap = totalH * 0.14
                            let footerHeight: CGFloat = 32
                            let gridSpacing = min(geometry.size.width, geometry.size.height) * 0.018
                            let availableGridHeight = max(0, totalH - mantraToGridGap - gridToFooterGap - footerHeight)
                            let gridHeight = min(availableGridHeight, totalH * 0.30)

                            VStack(spacing: 0) {
                                Spacer(minLength: mantraToGridGap)

                                VStack(spacing: gridSpacing) {
                                    let columns = [
                                        GridItem(.flexible(), spacing: gridSpacing, alignment: .center),
                                        GridItem(.flexible(), spacing: gridSpacing, alignment: .center)
                                    ]

                                    LazyVGrid(columns: columns,
                                              spacing: gridSpacing) {
                                        navItemView(title: "Place", geometry: geometry)
                                        navItemView(title: "Gemstone", geometry: geometry)
                                        navItemView(title: "Color", geometry: geometry)
                                        navItemView(title: "Scent", geometry: geometry)
                                        navItemView(title: "Activity", geometry: geometry)
                                        navItemView(title: "Sound", geometry: geometry)
                                        navItemView(title: "Career", geometry: geometry)
                                        navItemView(title: "Relationship", geometry: geometry)
                                    }
                                    .frame(height: gridHeight)
                                    .padding(.horizontal, geometry.size.width * 0.05)
                                }

                                Spacer(minLength: gridToFooterGap)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.55), value: isMantraExpanded)
                            .animation(.easeInOut(duration: 0.6), value: isMantraExpanded)
                        }
                    }
                    .padding(.top, 16)
                    .frame(width: geometry.size.width,
                           height: geometry.size.height,
                           alignment: .top)
                    .preferredColorScheme(themeManager.preferredColorScheme)
                    .onAppear {
                        starManager.animateStar = true
                        themeManager.appBecameActive()
                        ensureDefaultsIfMissing()
                        fetchAllRecommendationTitles()
                        if !todaySoundKey.isEmpty, todaySoundKey != lastPrefetchedSoundKey {
                            lastPrefetchedSoundKey = todaySoundKey
                            soundPlayer.prefetch(named: todaySoundKey)
                        }
                    }
                    .onChange(of: viewModel.dailyMantra) { _ in
                        if bootPhase == .main {
                            markMantraReadyIfPossible()
                        }
                    }
                    .coordinateSpace(name: "HomeSpace")
                    .overlay(alignment: .topLeading) { }
                }
            }
            // ✅ 只作用在首页这个 ZStack 上，push 新页面后不会带过去
            .safeAreaInset(edge: .bottom) {
                if !isMantraExpanded {
                    (
                        Text("The daily rhythms above are derived from integrated modeling of Earth observation, climate, air-quality, physiological, and astrological data, ")
                        + Text("\(updatedOnFooterText).").bold()
                    )
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if showNoSoundToast {
                    noSoundToastView
                        .padding(.bottom, isMantraExpanded ? 22 : 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationDestination(for: RecCategory.self) { cat in
                RecommendationPagerView(docsByCategory: makeDocsMap(), selected: cat)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
            }
            .alert("Update Unavailable", isPresented: $showRefreshCooldownAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(refreshCooldownMessage)
            }

        }
        .navigationViewStyle(.stack)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }


    private func persistWidgetSnapshotFromViewModel() {
//        // 你已有：viewModel.dailyMantra, recommendationTitles["Color"/"Place"/"Gemstone"/"Scent"]
//        let snap = AlignaWidgetSnapshot(
//            mantra: viewModel.dailyMantra.isEmpty ? "Find your flow." : viewModel.dailyMantra,
//            colorTitle: recommendationTitles["Color"] ?? "Color",
//            placeTitle: recommendationTitles["Place"] ?? "Place",
//            gemstoneTitle: recommendationTitles["Gemstone"] ?? "Gemstone",
//            scentTitle: recommendationTitles["Scent"] ?? "Scent"
//        )
//        AlignaWidgetStore.save(snap) // ↩︎ 写入 App Group + 刷新 Widget
    }

    private func updateLastRecommendationStampIfReady(mantra: String, recs: [String: String]) {
        let trimmed = mantra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, recs.count >= 8 else {
            lastRecommendationHasFullSet = false
            return
        }
        lastRecommendationTimestamp = Date().timeIntervalSince1970
        lastRecommendationHasFullSet = true
    }

    private func makeReasoningSummary(from reasoning: [String: String]) -> String {
        let order = ["Color", "Place", "Gemstone", "Scent", "Activity", "Sound", "Career", "Relationship"]
        let parts = order.compactMap { key -> String? in
            guard let value = reasoning[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            return "\(key): \(value)"
        }
        let limited = Array(parts.prefix(2))
        return limited.joined(separator: " | ")
    }

    private func presentMantraShareSheet() {
        guard let image = captureMantraImage() else {
            mantraSaveMessage = "Could not capture the screenshot."
            showMantraSaveAlert = true
            return
        }

        presentShareController(with: image)
    }

    private func presentShareController(with image: UIImage) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        guard let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        root.present(activity, animated: true)
    }

    private func captureMantraImage() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return nil
        }

        guard let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        let size = window.bounds.size
        let captureView = MantraCaptureView(mantra: viewModel.dailyMantra)
            .environmentObject(starManager)
            .environmentObject(themeManager)

        let controller = UIHostingController(rootView: captureView)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private struct MantraCaptureView: View {
        let mantra: String

        @EnvironmentObject var starManager: StarAnimationManager
        @EnvironmentObject var themeManager: ThemeManager

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    AppBackgroundView(nightMotion: .staticBackground)
                        .ignoresSafeArea()

                    if themeManager.isNight || themeManager.preferredColorScheme == .dark {
                        StaticStarField(size: geometry.size)
                    } else {
                        StaticDayStarField(size: geometry.size)
                    }

                    Text(mantra)
                        .font(AlignaType.expandedMantraBoldItalic())
                        .lineSpacing(12)
                        .multilineTextAlignment(.center)
                        .foregroundColor(
                            themeManager.primaryText.opacity(themeManager.isNight ? 0.94 : 0.88)
                        )
                        .padding(.horizontal, geometry.size.width * 0.14)
                        .padding(.top, geometry.size.height * 0.16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .preferredColorScheme(themeManager.preferredColorScheme)
            }
        }

        private struct StaticStar {
            let position: CGPoint
            let size: CGFloat
            let opacity: Double
        }

        private struct StaticStarField: View {
            let size: CGSize
            private let count = 90

            var body: some View {
                ForEach(0..<count, id: \.self) { index in
                    let star = star(for: index, in: size)
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .position(star.position)
                }
                .allowsHitTesting(false)
            }

            private func star(for index: Int, in size: CGSize) -> StaticStar {
                let x = unit(Double(index) * 12.9898)
                let y = unit(Double(index) * 78.233)
                let s = 1.4 + unit(Double(index) * 45.164) * 2.2
                let o = 0.35 + unit(Double(index) * 93.73) * 0.55

                return StaticStar(
                    position: CGPoint(x: x * size.width, y: y * size.height),
                    size: s,
                    opacity: o
                )
            }

            private func unit(_ seed: Double) -> CGFloat {
                let value = abs(sin(seed) * 43758.5453)
                return CGFloat(value - floor(value))
            }
        }

        private struct StaticDayStar {
            let position: CGPoint
            let size: CGFloat
            let isCross: Bool
            let fill: Color
            let stroke: Color
            let opacity: Double
        }

        private struct StaticDayStarField: View {
            let size: CGSize
            private let count = 20

            var body: some View {
                ForEach(0..<count, id: \.self) { index in
                    let star = star(for: index, in: size)

                    if star.isCross {
                        CrossShape()
                            .stroke(star.stroke.opacity(star.opacity), lineWidth: 1)
                            .frame(width: star.size, height: star.size)
                            .position(star.position)
                    } else {
                        FourPointStarShape()
                            .fill(star.fill.opacity(star.opacity))
                            .overlay(
                                FourPointStarShape()
                                    .stroke(star.stroke.opacity(star.opacity), lineWidth: 1)
                            )
                            .frame(width: star.size, height: star.size)
                            .position(star.position)
                    }
                }
                .allowsHitTesting(false)
            }

            private func star(for index: Int, in size: CGSize) -> StaticDayStar {
                let x = unit(Double(index) * 19.13)
                let y = unit(Double(index) * 57.71)
                let s = 10 + unit(Double(index) * 31.41) * 8
                let o = 0.65 + unit(Double(index) * 83.11) * 0.35
                let isCross = unit(Double(index) * 11.17) > 0.55

                let fillPalette: [Color] = [
                    Color(hex: "#FFF4B3"),
                    Color(hex: "#FFD700"),
                    Color(hex: "#F4D69D")
                ]
                let strokePalette: [Color] = [
                    Color(hex: "#D4A574"),
                    Color(hex: "#C8925F")
                ]

                let fill = fillPalette[index % fillPalette.count]
                let stroke = strokePalette[index % strokePalette.count]

                return StaticDayStar(
                    position: CGPoint(x: x * size.width, y: y * size.height),
                    size: s,
                    isCross: isCross,
                    fill: fill,
                    stroke: stroke,
                    opacity: o
                )
            }

            private func unit(_ seed: Double) -> CGFloat {
                let value = abs(sin(seed) * 43758.5453)
                return CGFloat(value - floor(value))
            }
        }
    }


    
    // 冷启动只看“是否已登录 + 本地标记”来分流；不再在这里查 Firestore 决定是否强拉 Onboarding。
    // === 替换你原来的 startInitialLoad()（整段替换） ===
    private func startInitialLoad() {
        isMantraReady = false

        #if DEBUG
        if _isPreview { bootPhase = .main; return }
        #endif
        // 冷启动先“等用户恢复”，最多等一小会（例如 6 秒）
        waitForAuthenticatedUserThenBoot(maxWait: 6.0)
    }

    // NEW: 等待 Firebase 恢复 currentUser 后再走原有分流逻辑
    private func waitForAuthenticatedUserThenBoot(maxWait: TimeInterval) {
        // 每天首次启动：重置 watchdog 计数/锁
        resetDailyWatchdogIfNeeded()

        if let user = Auth.auth().currentUser, !authWaitTimedOut {
            resolveBootPath(for: user)
            return
        }

        // 没有 currentUser：安装监听，等待恢复
        if authListenerHandle == nil {
            authListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
                if user != nil {
                    // 恢复到用户了 → 移除监听并启动
                    if let h = authListenerHandle { Auth.auth().removeStateDidChangeListener(h) }
                    authListenerHandle = nil
                    authWaitTimedOut = false
                    waitForAuthenticatedUserThenBoot(maxWait: 0) // 递归调用进入分流
                }
            }
        }

        // 兜底超时：防止无限等。到时仍未恢复用户，就按“未登录”进入。
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.5, maxWait)) {
            guard Auth.auth().currentUser == nil else { return }
            authWaitTimedOut = true
            if let h = authListenerHandle { Auth.auth().removeStateDidChangeListener(h) }
            authListenerHandle = nil
            // 超时还没恢复用户 → 走未登录 OpeningPage
            shouldOnboardAfterSignIn = false
            hasCompletedOnboarding = false
            withAnimation(.easeInOut) { bootPhase = .onboarding }
        }
    }

    private func resolveBootPath(for user: User) {
        if didResolveBootPath { return }
        didResolveBootPath = true

        // A) 未登录（极端兜底）
        if user.uid.isEmpty {
            shouldOnboardAfterSignIn = false
            hasCompletedOnboarding = false
            withAnimation(.easeInOut) { bootPhase = .onboarding }
            return
        }

        let ref = Firestore.firestore().collection("users").document(user.uid)
        let source: FirestoreSource = didDeleteAccount ? .server : .default
        ref.getDocument(source: source) { snapshot, error in
            let data = snapshot?.data()
            let nickname = (data?["nickname"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let hasProfile = data != nil && !nickname.isEmpty

            DispatchQueue.main.async {
                if let _ = error {
                    if didDeleteAccount {
                        didDeleteAccount = false
                        ref.getDocument { snapshot, error in
                            DispatchQueue.main.async {
                                if let _ = error {
                                    didResolveBootPath = false
                                    if shouldOnboardAfterSignIn && !hasCompletedOnboarding {
                                        withAnimation(.easeInOut) { bootPhase = .onboarding }
                                        return
                                    }
                                    shouldOnboardAfterSignIn = false
                                    proceedNormalBoot()
                                    return
                                }

                                let data = snapshot?.data()
                                let nickname = (data?["nickname"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                let hasProfile = data != nil && !nickname.isEmpty

                                if hasProfile {
                                    hasCompletedOnboarding = true
                                    shouldOnboardAfterSignIn = false
                                    proceedNormalBoot()
                                    return
                                }

                                if shouldOnboardAfterSignIn || !hasCompletedOnboarding {
                                    withAnimation(.easeInOut) { bootPhase = .onboarding }
                                } else {
                                    proceedNormalBoot()
                                }
                            }
                        }
                        return
                    }

                    // 读取失败则退回本地标记逻辑
                    didResolveBootPath = false
                    if shouldOnboardAfterSignIn && !hasCompletedOnboarding {
                        withAnimation(.easeInOut) { bootPhase = .onboarding }
                        return
                    }
                    shouldOnboardAfterSignIn = false
                    proceedNormalBoot()
                    return
                }

                if didDeleteAccount {
                    didDeleteAccount = false
                }

                if hasProfile {
                    hasCompletedOnboarding = true
                    shouldOnboardAfterSignIn = false
                    proceedNormalBoot()
                    return
                }

                if shouldOnboardAfterSignIn || !hasCompletedOnboarding {
                    withAnimation(.easeInOut) { bootPhase = .onboarding }
                } else {
                    proceedNormalBoot()
                }
            }
        }
    }

    // NEW: 按自然日重置 watchdog 相关的 @AppStorage
    private func resetDailyWatchdogIfNeeded() {
        let today = todayString()
        if watchdogDay != today {
            watchdogDay = today
            todayAutoRefetchAttempts = 0
            todayAutoRefetchDone = ""
            todayFetchLock = ""
        }
    }

    // ====== MainView 内新增 ======
    private func hydrateBirthFromProfileIfNeeded(_ done: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { done(); return }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)
        ref.getDocument { snap, _ in
            defer { done() }
            guard let data = snap?.data() else { return }
            

            // birth date
            if let ts = data["birthday"] as? Timestamp {
                viewModel.birth_date = ts.dateValue()
            } else if let s = data["birthDate"] as? String,
                      let d = parseBirthDateString(s) {
                viewModel.birth_date = d
            }


            // birth time（统一通过 timeToDateFlexible 解析成本地时区的“时分锚定”Date）
            if let t = data["birthTime"] as? String, let d = timeToDateFlexible(t) {
                viewModel.birth_time = d
            }

            // ✅ 出生经纬度 → 注入 viewModel（供上升星座使用）
            if let lat = data["birthLat"] as? CLLocationDegrees,
               let lng = data["birthLng"] as? CLLocationDegrees,
               lat != 0 || lng != 0 {
                viewModel.birthCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }
    }


    // 原先 startInitialLoad 的主体逻辑移到这里（不修改其内容）
    private func proceedNormalBoot() {
        
        startAutoRefetchWatchdog(delay: 8.0)
        locationManager.requestLocation()

        let group = DispatchGroup()

        // FIX: 先把生日/时间从用户档案同步到 viewModel
        group.enter()
        hydrateBirthFromProfileIfNeeded { group.leave() }

        group.enter()
        ensureDailyCurrentPlaceSaved { group.leave() }

        let today = todayString()
        if hasRecentRecommendation {
            group.enter()
            loadTodayRecommendation(day: today, source: .cache, allowRemoteFallback: true) { group.leave() }
        } else {
            group.enter()
            fetchAndSaveRecommendationIfNeeded()
            waitUntilRecommendationsReady(timeout: 12) { group.leave() }
        }

        group.notify(queue: .main) {
            // (If the doc doesn't exist yet, it'll become available after fetch/save.)
            self.reasoningStore.load(for: Date())
            self.isBootDataReady = true
            attemptBootAdvance()
        }
    }


    private func ensureDailyCurrentPlaceSaved(completion: @escaping () -> Void) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())

        // 当天已经写过了，直接过
        if lastCurrentPlaceUpdate == today {
            completion()
            return
        }

        // 等待定位（最多等 8 秒）
        let start = Date()
        let waitLimit: TimeInterval = 8.0

        func attempt() {
            if let coord = locationManager.currentLocation {
                // 有坐标 → 反地理解析城市名 → 写入 Firestore
                getAddressFromCoordinate(coord) { city in
                    let place = city ?? "Unknown"
                    upsertUserCurrentPlace(place: place, coord: coord) { ok in
                        if ok { lastCurrentPlaceUpdate = today }
                        completion()
                    }
                }
                return
            }

            // 超时兜底：没有坐标也尽量落一次（Unknown），不阻塞启动
            if Date().timeIntervalSince(start) > waitLimit {
                upsertUserCurrentPlace(place: "Unknown", coord: nil) { ok in
                    if ok { lastCurrentPlaceUpdate = today }
                    completion()
                }
                return
            }

            // 继续等
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { attempt() }
        }

        attempt()
    }
    private func upsertUserCurrentPlace(
        place: String,
        coord: CLLocationCoordinate2D?,
        completion: @escaping (Bool) -> Void
    ) {
        guard let user = Auth.auth().currentUser else {
            print("❌ 未登录，跳过写入 currentPlace")
            completion(false)
            return
        }
        let db = Firestore.firestore()

        var fields: [String: Any] = ["currentPlace": place]
        if let c = coord {
            fields["currentLat"] = c.latitude
            fields["currentLng"] = c.longitude
        }

        func write(to ref: DocumentReference) {
            ref.setData(fields, merge: true) { err in
                if let err = err {
                    print("❌ 更新 currentPlace 失败：\(err.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ 已更新用户 currentPlace: \(place)")
                    completion(true)
                }
            }
        }

        // 1) users 按 uid
        db.collection("users").whereField("uid", isEqualTo: user.uid).limit(to: 1).getDocuments { s1, _ in
            if let doc = s1?.documents.first { write(to: doc.reference); return }

            // 2) user 按 uid
            db.collection("user").whereField("uid", isEqualTo: user.uid).limit(to: 1).getDocuments { s2, _ in
                if let doc2 = s2?.documents.first { write(to: doc2.reference); return }

                // 3) users / user 按 email（如有）
                if let email = user.email {
                    db.collection("users").whereField("email", isEqualTo: email).limit(to: 1).getDocuments { s3, _ in
                        if let d3 = s3?.documents.first { write(to: d3.reference); return }

                        db.collection("user").whereField("email", isEqualTo: email).limit(to: 1).getDocuments { s4, _ in
                            if let d4 = s4?.documents.first { write(to: d4.reference); return }

                            // 4) 都没有 → 在 users 新建最小档案
                            var payload = fields
                            payload["uid"] = user.uid
                            payload["email"] = email
                            payload["createdAt"] = Timestamp()
                            db.collection("users").addDocument(data: payload) { err in
                                if let err = err {
                                    print("❌ 创建用户文档失败：\(err.localizedDescription)")
                                    completion(false)
                                } else {
                                    print("✅ 已创建用户文档并写入 currentPlace")
                                    completion(true)
                                }
                            }
                        }
                    }
                } else {
                    // 没有 email：用 uid 最小化建档
                    var payload = fields
                    payload["uid"] = user.uid
                    payload["createdAt"] = Timestamp()
                    db.collection("users").addDocument(data: payload) { err in
                        if let err = err {
                            print("❌ 创建用户文档失败：\(err.localizedDescription)")
                            completion(false)
                        } else {
                            print("✅ 已创建用户文档并写入 currentPlace")
                            completion(true)
                        }
                    }
                }
            }
        }
    }




    /// Polls viewModel.recommendations until non-empty (or timeout)
    private func waitUntilRecommendationsReady(timeout: TimeInterval = 12, poll: TimeInterval = 0.2, onReady: @escaping () -> Void) {
        let start = Date()
        func check() {
            if !viewModel.recommendations.isEmpty {
                onReady()
                return
            }
            if Date().timeIntervalSince(start) > timeout {
                // Timeout: still move on (you can choose to stay on loading if you prefer)
                onReady()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + poll, execute: check)
        }
        check()
    }

    private func attemptBootAdvance() {
        guard isBootDataReady, didCompletePersonalCheckIn else { return }
        withAnimation(.easeInOut) { bootPhase = .main }
        pendingMantraExpansion = true
        markMantraReadyIfPossible()
        if shouldShowBootLoading {
            shouldShowBootLoading = false
        }
    }

    private func handleManualRefreshTap() {
        guard manualRefreshAllowed() else {
            refreshCooldownMessage = refreshCooldownText()
            showRefreshCooldownAlert = true
            return
        }
        isManualRefreshFlow = true
        didCompletePersonalCheckIn = false
        isMantraReady = false
        bootPhase = .loading
    }

    private func manualRefreshAllowed() -> Bool {
        let now = Date().timeIntervalSince1970
        return now - lastManualRefreshTimestamp >= 12 * 60 * 60
    }

    private func refreshCooldownText() -> String {
        guard lastManualRefreshTimestamp > 0 else {
            return "You can refresh again in about 12 hours."
        }
        let last = Date(timeIntervalSince1970: lastManualRefreshTimestamp)
        let next = last.addingTimeInterval(12 * 60 * 60)
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let lastText = formatter.string(from: last)
        let nextText = formatter.string(from: next)
        return "Updated at \(lastText). You can refresh again after \(nextText)."
    }

    private func expandMantraIfNeeded() {
        guard pendingMantraExpansion else { return }
        pendingMantraExpansion = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isMantraExpanded = true
        }
    }

    private func markMantraReadyIfPossible() {
        let trimmed = viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard bootPhase == .main, !trimmed.isEmpty else { return }
        if !isMantraReady {
            isMantraReady = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expandMantraIfNeeded()
        }
    }

    var body: some View {
        Group {
            switch bootPhase {
            case .loading:
                LoadingView(
                    onStartLoading: {
                        if isManualRefreshFlow {
                            return
                        }
                        startInitialLoad()
                    },
                    onPersonalComplete: { didProvidePersonal in
                        if didProvidePersonal {
                            forceRefetchDailyIfNotLocked()
                        } else if hasRecentRecommendation {
                            isBootDataReady = true
                        }
                        if isManualRefreshFlow {
                            if didProvidePersonal {
                                lastManualRefreshTimestamp = Date().timeIntervalSince1970
                            }
                            isManualRefreshFlow = false
                            isBootDataReady = true
                        }
                        didCompletePersonalCheckIn = true
                        attemptBootAdvance()
                    },
                    forceFullLoading: isManualRefreshFlow
                )
                .ignoresSafeArea()
                        
            case .onboarding:
                NavigationStack {
                    if shouldOnboardAfterSignIn {
                        // 注册后正式进入引导：Step1
                        OnboardingStep1(viewModel: viewModel)
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .navigationBarBackButtonHidden(true)
                    } else {
                        // 冷启动未登录：先到 OpeningPage（包含 Sign Up / Log In）
                        FrontPageView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .navigationBarBackButtonHidden(true)
                    }
                }
            case .main:
                            mainContent // (extract your existing NavigationStack content into a computed var)
                        }
                    }
                    .onAppear {
                        // run once on cold start
                        if !didBootVisuals {
                            didBootVisuals = true
                            starManager.animateStar = true
                            themeManager.appBecameActive()

                            let trimmed = viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                cachedDailyMantra = trimmed
                                if dailyMantraNotificationEnabled {
                                    MantraNotificationManager.scheduleDaily(
                                        mantra: trimmed,
                                        hour: dailyMantraNotificationHour,
                                        minute: dailyMantraNotificationMinute
                                    )
                                }
                            }
                        }

                        if shouldShowBootLoading {
                            bootPhase = .loading
                        }

                        if shouldCollapseMantraOnReturn {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isMantraExpanded = false
                            }
                            shouldCollapseMantraOnReturn = false
                        }
                    }
                    .onChange(of: mainNavigationPath) { _, newValue in
                        if newValue.isEmpty, shouldCollapseMantraOnReturn {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isMantraExpanded = false
                            }
                            shouldCollapseMantraOnReturn = false
                        }
                    }
                    .onChange(of: viewModel.dailyMantra) { _, newValue in
                        cachedDailyMantra = newValue
                        if dailyMantraNotificationEnabled {
                            MantraNotificationManager.scheduleDaily(
                                mantra: newValue,
                                hour: dailyMantraNotificationHour,
                                minute: dailyMantraNotificationMinute
                            )
                        }
                    }
                    .onChange(of: viewModel.recommendations) { _, newValue in
                        let key = (newValue["Sound"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !key.isEmpty, key != lastPrefetchedSoundKey else { return }
                        lastPrefetchedSoundKey = key
                        soundPlayer.prefetch(named: key)
                    }
                    .onChange(of: shouldExpandMantraFromNotification) { _, newValue in
                        guard newValue else { return }
                        mainNavigationPath = NavigationPath()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isMantraExpanded = true
                        }
                        shouldExpandMantraFromNotification = false
                    }
                }
    private func fetchAllRecommendationTitles() {
        #if DEBUG
        if _isPreview { return }
        #endif
        
        let db = Firestore.firestore()

        for (rawCategory, rawDoc) in viewModel.recommendations {
            // 统一得到规范写法（如果已经是规范写法，也会直接返回自身）
            guard let canon = canonicalCategory(from: rawCategory) ?? canonicalCategory(from: rawCategory.capitalized) ?? rawCategory as String? else {
                print("⚠️ 跳过未知类别：\(rawCategory)")
                continue
            }
            guard let collection = firebaseCollectionName(for: canon) else {
                print("⚠️ 未知集合映射：\(canon)")
                continue
            }

            let documentName = sanitizeDocumentName(rawDoc)
            guard !documentName.isEmpty else {
                print("⚠️ 跳过空文档名（\(canon)）")
                continue
            }

            db.collection(collection).document(documentName).getDocument { snapshot, error in
                if let error = error {
                    print("❌ 加载 \(canon) 标题失败: \(error)")
                    return
                }
                if let data = snapshot?.data(), let title = data["title"] as? String {
                    DispatchQueue.main.async {
                        self.recommendationTitles[canon] = title // 以规范写法作键
                    }
                } else {
                    print("⚠️ \(canon)/\(documentName) 无 title 字段或文档不存在")
                }
            }
        }
    }

    /// 启动“保底看门狗”：若 delay 秒后仍未拿到 mantra 或推荐，则强制走一次 FastAPI 重拉
    // === 替换你原有的 startAutoRefetchWatchdog(delay:)（整段替换） ===
    private func startAutoRefetchWatchdog(delay: TimeInterval = 8.0) {
        // 只安排一次根任务
        guard !autoRefetchScheduled else { return }
        autoRefetchScheduled = true

        func scheduleNext(after: TimeInterval) {
            // 已经有数据就不用继续重试了
            let mantraReady = !viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let recsReady   = !viewModel.recommendations.isEmpty
            if mantraReady && recsReady { return }

            // 达到上限就停
            if todayAutoRefetchAttempts >= maxRefetchAttempts { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + after) {
                // 进入具体一次尝试：再次判断是否已经就绪
                let readyNow = !viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.recommendations.isEmpty
                guard !readyNow else { return }

                // 触发一次强制重拉
                print("🛡️ Watchdog attempt #\(todayAutoRefetchAttempts + 1)")
                forceRefetchDailyIfNotLocked()

                // 增加计数并安排下一次（指数退避，封顶 60s）
                todayAutoRefetchAttempts += 1
                let nextDelay = min(60.0, max(6.0, after * 1.8))
                scheduleNext(after: nextDelay)
            }
        }

        scheduleNext(after: delay <= 0 ? initialRefetchDelay : delay)
    }


    /// 强制当日重拉（跳过“今日已有推荐”的判断），仍复用今日互斥锁与定位等待
    // === 替换你原有的 forceRefetchDailyIfNotLocked()（整段替换） ===
    private func forceRefetchDailyIfNotLocked() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法强制重拉"); return
        }
        let today = todayString()
        let docRef = todayDocRef(uid: uid, day: today)

        // 若已有在途请求，就不重复发
        if todayFetchLock == today || isFetchingToday {
            print("⏳ Watchdog: 今日请求已在进行中，跳过强制重拉")
            return
        }

        todayFetchLock = today
        isFetchingToday = true

        // Watchdog 重拉也需要定位；没有的话先申请并等待
        if locationManager.currentLocation == nil {
            locationManager.requestLocation()
        }
        waitForLocationThenRequest(uid: uid, today: today, docRef: docRef)
    }


    
    // 当天字符串
    private func todayString() -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    // 当天唯一 DocID：uid_yyyy-MM-dd
    private func todayDocRef(uid: String, day: String) -> DocumentReference {
        Firestore.firestore()
            .collection("daily_recommendation")
            .document("\(uid)_\(day)")
    }
    
    /// ✅ 当 FastAPI 生成失败时，把本地默认推荐也写入 daily_recommendation（用于 Timeline/Calendar 回看）
    /// - Note: 使用同一个 docId = uid_yyyy-MM-dd，后续如果 FastAPI 成功，会覆盖掉默认值。
    private func saveDefaultDailyRecommendationToCalendar(
        userId: String,
        today: String,
        docRef: DocumentReference,
        reason: String
    ) {
        // 只写“规范写法”的 key，保证 Timeline/DailyViewModel 能正常读取
        let normalized: [String: String] = DesignRecs.docs.reduce(into: [:]) { acc, kv in
            if let canon = canonicalCategory(from: kv.key) {
                acc[canon] = sanitizeDocumentName(kv.value)
            }
        }

        var data: [String: Any] = normalized
        data["uid"] = userId
        data["createdAt"] = today
        data["mantra"] = DesignRecs.mantra
        
        let fallbackPlace = {
            let p1 = viewModel.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines)
            if !p1.isEmpty { return p1 }
            let p2 = lastRecommendationPlace.trimmingCharacters(in: .whitespacesAndNewlines)
            if !p2.isEmpty { return p2 }
            return "Unknown"
        }()
        data["generatedPlace"] = fallbackPlace

        DispatchQueue.main.async {
            self.lastRecommendationDate = today
            self.lastRecommendationPlace = fallbackPlace
        }

        
        data["isDefault"] = true
        data["fallbackReason"] = reason
        data["updatedAt"] = FieldValue.serverTimestamp()
        
        // ✅ NEW: default per-category reasoning map
        var reasoningMap: [String: String] = [:]
        for canonKey in normalized.keys {
            reasoningMap[canonKey] = defaultReasoning(for: canonKey)
        }
        data["reasoning"] = reasoningMap

        docRef.setData(data, merge: true) { err in
            if let err = err {
                print("❌ 保存默认 daily_recommendation 失败：\(err)")
            } else {
                print("✅ 已保存默认推荐到 Calendar（\(reason)）")
            }
        }
    }

    // 等待定位后只发一次请求（最多等 8 秒）
    private func waitForLocationThenRequest(uid: String, today: String, docRef: DocumentReference) {
        let start = Date()
        let limit: TimeInterval = 8.0

        func attempt() {
            if let coord = locationManager.currentLocation {
                fetchFromFastAPIAndSave(coord: coord, userId: uid, today: today, docRef: docRef)
                return
            }
            if Date().timeIntervalSince(start) > limit {
                print("⚠️ 超时仍未拿到坐标，本次放弃生成；将默认推荐写入 Calendar 以便回看")
                saveDefaultDailyRecommendationToCalendar(
                    userId: uid,
                    today: today,
                    docRef: docRef,
                    reason: "location_timeout"
                )
                todayFetchLock = ""  // 释放互斥锁
                isFetchingToday = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: attempt)
        }
        attempt()
    }

    

    private func fetchAndSaveRecommendationIfNeeded() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ 用户未登录，跳过获取推荐"); return
        }
        let today = todayString()
        let docRef = todayDocRef(uid: uid, day: today)

        // 单日互斥：同一天只允许一条在途请求
        if todayFetchLock == today || isFetchingToday {
            print("⏳ 今日拉取已在进行或已加锁，跳过二次触发")
            return
        }

        // 直接命中 docId 判断是否已有今日推荐（避免并发竞态）
        docRef.getDocument { snap, err in
            if let err = err {
                print("❌ 查询今日推荐失败：\(err.localizedDescription)")
                return
            }
            if let snap = snap, snap.exists {
                let data = snap.data() ?? [:]

                // If today's doc exists but has no reasoning, regenerate to backfill reasoning.
                // This fixes the case where you deleted/recreated a doc while backend didn't
                // provide mapping, or an older writer created the doc without reasoning.
                let hasReasoning = (data["reasoning"] != nil) || (data["mapping"] != nil)
                if hasReasoning {
                    print("📌 今日已有推荐（docId 命中），不重复生成")
                    lastRecommendationDate = today
                    loadTodayRecommendation(day: today)
                    return
                } else {
                    print("⚠️ 今日 doc 存在但缺少 reasoning/mapping，将触发重拉以补全")
                    // fall through to generation path below
                }
            }


            // 尚无今日记录 → 加锁并等待定位就绪后只发一次
            todayFetchLock = today
            isFetchingToday = true
            if locationManager.currentLocation == nil {
                locationManager.requestLocation()
            }
            waitForLocationThenRequest(uid: uid, today: today, docRef: docRef)
        }
    }

    
    private func fetchFromFastAPIAndSave(
        coord: CLLocationCoordinate2D,
        userId: String,
        today: String,
        docRef: DocumentReference
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let birthDateString = dateFormatter.string(from: viewModel.birth_date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let birthTimeString = timeFormatter.string(from: viewModel.birth_time)

        let payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": coord.latitude,
            "longitude": coord.longitude
        ]

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
            print("❌ 无效的 FastAPI URL")
            saveDefaultDailyRecommendationToCalendar(
                userId: userId,
                today: today,
                docRef: docRef,
                reason: "invalid_url"
            )
            todayFetchLock = ""; isFetchingToday = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ JSON 序列化失败: \(error)")
            saveDefaultDailyRecommendationToCalendar(
                userId: userId,
                today: today,
                docRef: docRef,
                reason: "json_serialization_error"
            )
            todayFetchLock = ""; isFetchingToday = false
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer {                    // 不管成功失败都释放“今日锁”
                DispatchQueue.main.async {
                    todayFetchLock = ""
                    isFetchingToday = false
                }
            }

            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "network_error"
                )
                return
            }
            guard let http = response as? HTTPURLResponse else {
                print("❌ 非 HTTP 响应")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "non_http_response"
                )
                return
            }
            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data ?? Data(), encoding: .utf8) ?? "<no body>"
                print("❌ 非 2xx：\(http.statusCode), body=\(body)")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "http_\(http.statusCode)"
                )
                return
            }
            guard let data = data else {
                print("❌ 空数据")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "empty_data"
                )
                return
            }

            do {
                if let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let recs = parsed["recommendations"] as? [String: String],
                   let mantra = parsed["mantra"] as? String {
                    
                    // ✅ Optional per-category reasoning from backend.
                    // Supports your new shape:
                    //   "mapping": { "Place": "...", "Color": "...", ... }
                    // and legacy:
                    //   "reasoning": { ... }
                    func coerceStringDict(_ any: Any?) -> [String: String] {
                        if let dict = any as? [String: String] {
                            return dict
                        }
                        guard let dict = any as? [String: Any] else { return [:] }
                        return dict.reduce(into: [String: String]()) { acc, pair in
                            if let s = pair.value as? String { acc[pair.key] = s }
                        }
                    }

                    print("🧠 FastAPI parsed keys:", parsed.keys.sorted())
                    if let v = parsed["mapping"] { print("🧠 FastAPI mapping type:", String(describing: type(of: v))) }
                    if let v = parsed["reasoning"] { print("🧠 FastAPI reasoning type:", String(describing: type(of: v))) }

                    // Backend may return mapping nested under explanation:
                    // {
                    //   "recommendations": { ... },
                    //   "mantra": "...",
                    //   "explanation": {
                    //      "mapping": { "Place": "...", ... },
                    //      "reasoning_summary": "..."
                    //   }
                    // }
                    let rawReasoning: [String: String] = {
                        if let mappingAny = parsed["mapping"] {
                            return coerceStringDict(mappingAny)
                        }
                        if let explanation = parsed["explanation"] as? [String: Any] {
                            if let mappingAny = explanation["mapping"] {
                                return coerceStringDict(mappingAny)
                            }
                            if let reasoningAny = explanation["reasoning"] as? [String: Any] {
                                if let nested = reasoningAny["mapping"] {
                                    return coerceStringDict(nested)
                                }
                                return coerceStringDict(reasoningAny)
                            }
                        }
                        if let reasoningAny = parsed["reasoning"] as? [String: Any] {
                            if let nested = reasoningAny["mapping"] {
                                return coerceStringDict(nested)
                            }
                            return coerceStringDict(reasoningAny)
                        }
                        if let reasoning = parsed["reasoning"] as? [String: String] {
                            return reasoning
                        }
                        return [:]
                    }()

                    let reasoningSummary: String? = {
                        if let s = parsed["reasoning_summary"] as? String { return s }
                        if let explanation = parsed["explanation"] as? [String: Any],
                           let s = explanation["reasoning_summary"] as? String {
                            return s
                        }
                        return nil
                    }()

                    print("🧠 FastAPI rawReasoning count:", rawReasoning.count, "keys:", rawReasoning.keys.sorted())


                    let reasoning = (parsed["reasoning_summary"] as? String)
                        ?? (parsed["reasoningSummary"] as? String)
                        ?? ""

                    DispatchQueue.main.async {
                        // ✅ 把后端 recommendations 的 key 统一成规范写法
                        let normalized: [String: String] = recs.reduce(into: [:]) { acc, kv in
                            if let canon = canonicalCategory(from: kv.key) {
                                acc[canon] = sanitizeDocumentName(kv.value)
                            }
                        }
                        
                        // ✅ NEW: normalize reasoning keys too (same canon keys as normalized)
                        let normalizedReasoning: [String: String] = rawReasoning.reduce(into: [:]) { acc, kv in
                            if let canon = canonicalCategory(from: kv.key) {
                                acc[canon] = kv.value
                            }
                        }

                        // 更新本地
                        viewModel.recommendations = normalized
                        viewModel.dailyMantra = mantra
                        lastRecommendationDate = today
                        viewModel.reasoningSummary = reasoning
                        updateLastRecommendationStampIfReady(mantra: mantra, recs: normalized)


                        // ✅ 先用一个“可用的地点”占位（立即显示），随后用反地理编码精确覆盖
                        let guessedPlace = viewModel.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !guessedPlace.isEmpty {
                            lastRecommendationPlace = guessedPlace
                        } else if lastRecommendationPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            lastRecommendationPlace = "Unknown"
                        }

                        // 先刷新标题（UI 需要）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            fetchAllRecommendationTitles()
                        }

                        // 幂等：固定 docId = uid_yyyy-MM-dd，setData(merge:)
                        var recommendationData: [String: Any] = normalized
                        recommendationData["uid"] = userId
                        recommendationData["createdAt"] = today
                        recommendationData["mantra"] = mantra
                        recommendationData["generatedPlace"] = lastRecommendationPlace// ✅ NEW

                        // ✅ Write reasoning into Firestore only when backend provides it.
                        // Avoid overwriting with placeholders, so missing reasoning is obvious.
                        if !normalizedReasoning.isEmpty {
                            recommendationData["reasoning"] = normalizedReasoning
                            // Also store under "mapping" for forward compatibility with backend naming.
                            recommendationData["mapping"] = normalizedReasoning
                        } else {
                            recommendationData["reasoning"] = FieldValue.delete()
                            recommendationData["mapping"] = FieldValue.delete()
                            print("⚠️ Backend did not provide reasoning/mapping; not writing placeholder reasoning.")
                        }

                        if let reasoningSummary, !reasoningSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            recommendationData["reasoning_summary"] = reasoningSummary
                        }
                        recommendationData["reasoning_summary"] = reasoning


                        // ✅ 如果之前写过默认值，这里要显式“转正”
                        recommendationData["isDefault"] = false
                        recommendationData["fallbackReason"] = FieldValue.delete()
                        recommendationData["updatedAt"] = FieldValue.serverTimestamp()

                        docRef.setData(recommendationData, merge: true) { err in
                            if let err = err {
                                print("❌ 保存 daily_recommendation 失败：\(err)")
                            } else {
                                print("✅ 今日推荐已保存（幂等写入）")
                            }
                        }
                        
                        // Refresh reasoning store for detail sheets
                        if let d = DateFormatter.appDayKey.date(from: today) {
                            self.reasoningStore.load(for: d)
                        } else {
                            self.reasoningStore.load(for: Date())
                        }

                        persistWidgetSnapshotFromViewModel()

                        // ✅ NEW：用本次生成坐标做反地理编码，拿到更准确的 place 后再覆盖写回
                        getAddressFromCoordinate(coord) { place in
                            let resolved = (place ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !resolved.isEmpty else { return }

                            DispatchQueue.main.async {
                                self.lastRecommendationPlace = resolved
                            }

                            docRef.setData(["generatedPlace": resolved], merge: true) { e in
                                if let e = e {
                                    print("⚠️ 写入 generatedPlace 失败：\(e.localizedDescription)")
                                }
                            }
                        }
                    }
                } else {
                    print("❌ FastAPI 返回缺少必要字段（recommendations/mantra）")
                    saveDefaultDailyRecommendationToCalendar(
                        userId: userId,
                        today: today,
                        docRef: docRef,
                        reason: "missing_fields"
                    )
                }
            } catch {
                print("❌ FastAPI 响应解析失败: \(error)")
                print("↳ raw body:", String(data: data, encoding: .utf8) ?? "<binary>")
                saveDefaultDailyRecommendationToCalendar(
                    userId: userId,
                    today: today,
                    docRef: docRef,
                    reason: "parse_error"
                )
            }
        }.resume()
    }

    
    
    
    private func navItemView(title: String, geometry: GeometryProxy) -> some View {
        let documentName = viewModel.recommendations[title] ?? ""
        let startCat = RecCategory(rawValue: title) // "Place" -> .Place
        return Group {
            if let startCat, !documentName.isEmpty {
                Button {
                    shouldCollapseMantraOnReturn = true
                    mainNavigationPath.append(startCat)
                } label: {
                    VStack(spacing: 2) {   // ⬅️ tighter spacing
                        // 图标图像
                        SafeImage(name: documentName, renderingMode: .template, contentMode: .fit)
                            .foregroundColor(themeManager.primaryText)
                            .frame(width: geometry.size.width * 0.16)  // slightly smaller to balance text
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 1.5)
                            .scaleEffect(isMantraExpanded ? 0.78 : 1)
                            .animation(.spring(response: 0.5, dampingFraction: 0.82, blendDuration: 0.2), value: isMantraExpanded)
                        
                        // 推荐名称（小字体，紧贴图标）
                        Text(recommendationTitles[title] ?? "")
                            .font(AlignaType.gridItemName())
                            .lineSpacing(AlignaType.body16LineSpacing) // 22-16=6
                            .foregroundColor(themeManager.descriptionText)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        
                        // 类别标题（和上面稍微拉开）
                        Text(title)
                            .font(AlignaType.gridCategoryTitle())
                            .lineSpacing(34 - 28) // 6
                            .foregroundColor(themeManager.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(themeManager.panelFill.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(themeManager.panelStrokeHi.opacity(0.6), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didDeleteAccount)) { _ in
            shouldOnboardAfterSignIn = false
            hasCompletedOnboarding = false
            isLoggedIn = false
            authWaitTimedOut = true
            if let h = authListenerHandle {
                Auth.auth().removeStateDidChangeListener(h)
                authListenerHandle = nil
            }
            withAnimation(.easeInOut) { bootPhase = .onboarding }
        }
        .onChange(of: bootPhase, initial: false) { _, phase in
            handleBootPhaseChange(phase)
        }
        /*
        // Removed applyBootPhaseChangeHandler and replaced with inline onChange above
        */
    }
    private func handleBootPhaseChange(_ phase: BootPhase) {
        if phase == .main {
            isMantraExpanded = true
            if shouldExpandMantraOnBoot {
                shouldExpandMantraOnBoot = false
            }
        }
    }

    private func makeDocsMap() -> [RecCategory: String] {
        Dictionary(uniqueKeysWithValues: RecCategory.allCases.map { cat in
            let key = cat.rawValue
            return (cat, viewModel.recommendations[key] ?? "")
        })
    }

    /*
    @ViewBuilder
    private func applyBootPhaseChangeHandler() -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: bootPhase, initial: false) { _, phase in
                handleBootPhaseChange(phase)
            }
        } else {
            self.onChange(of: bootPhase) { phase in
                handleBootPhaseChange(phase)
            }
        }
    }
    */
    // REMOVED applyBootPhaseChangeHandler() as per instructions

    @ViewBuilder
    private func viewForCategory(title: String, documentName: String) -> some View {
        switch title {
        case "Place":
            PlaceDetailView(documentName: documentName)
        case "Gemstone":
            GemstoneDetailView(documentName: documentName)
        case "Color":
            ColorDetailView(documentName: documentName)
        case "Scent":
            ScentDetailView(documentName: documentName)
        case "Activity":
                    ActivityDetailView(
                        documentName: documentName
        //                soundDocumentName: viewModel.recommendations["Sound"] ?? ""
                    )
        case "Sound":
            SoundDetailView(documentName: documentName)
        case "Career":
            CareerDetailView(documentName: documentName)
        case "Relationship":
            RelationshipDetailView(documentName: documentName)
        default:
            Text("⚠️ Unknown Category")
        }
    }
    
    
    private func loadTodayRecommendation(
        day: String? = nil,
        source: FirestoreSource = .default,
        allowRemoteFallback: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法获取推荐")
            completion?()
            return
        }

        let today = day ?? todayString()
        let db = Firestore.firestore()
        let fixedDocRef = todayDocRef(uid: userId, day: today)

        func finish() {
            DispatchQueue.main.async {
                completion?()
            }
        }

        func applyDailyData(_ data: [String: Any]) {
            var recs: [String: String] = [:]
            var fetchedMantra = ""
            var fetchedReasoning = ""
            var reasoningMap: [String: String] = [:]

            let fetchedPlace = (data["generatedPlace"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let rawReasoning = data["reasoning"] as? [String: Any] {
                for (key, value) in rawReasoning {
                    if let s = value as? String {
                        reasoningMap[key] = s
                    }
                }
            } else if let rawReasoning = data["mapping"] as? [String: Any] {
                for (key, value) in rawReasoning {
                    if let s = value as? String {
                        reasoningMap[key] = s
                    }
                }
            }

            for (key, value) in data {

                // ✅ mantra：你之前漏了这段，导致第二次打开时被覆盖为空
                if key == "mantra", let s = value as? String {
                    fetchedMantra = s
                    continue
                }

                // ✅ reasoning summary：支持两种 key
                if (key == "reasoning_summary" || key == "reasoningSummary"),
                   let s = value as? String {
                    fetchedReasoning = s
                    continue
                }

                // ✅ 跳过元数据字段
                if key == "uid"
                    || key == "createdAt"
                    || key == "updatedAt"
                    || key == "isDefault"
                    || key == "fallbackReason"
                    || key == "generatedPlace"
                    || key == "mantra"
                    || key == "reasoning_summary"
                    || key == "reasoningSummary" {
                    continue
                }

                // ✅ 推荐类别字段（大小写无关→规范写法）
                if let canon = canonicalCategory(from: key), let str = value as? String {
                    recs[canon] = sanitizeDocumentName(str)
                }
            }

            DispatchQueue.main.async {
                self.lastRecommendationDate = today

                if !fetchedPlace.isEmpty {
                    self.lastRecommendationPlace = fetchedPlace
                }

                self.viewModel.recommendations = recs

                // ✅ 只有在 Firestore 真有 mantra 时才覆盖；避免把已有 UI 文本刷成空
                let mantraTrim = fetchedMantra.trimmingCharacters(in: .whitespacesAndNewlines)
                if !mantraTrim.isEmpty {
                    self.viewModel.dailyMantra = fetchedMantra
                } else {
                    // 诊断日志：帮助你确认 Firestore 是否写入了 mantra
                    print("⚠️ Firestore 今日文档没有 mantra 或为空（docId=\(userId)_\(today)）")
                }

                let resolvedMantra = mantraTrim.isEmpty ? self.viewModel.dailyMantra : fetchedMantra
                self.updateLastRecommendationStampIfReady(mantra: resolvedMantra, recs: recs)

                let reasoningTrim = fetchedReasoning.trimmingCharacters(in: .whitespacesAndNewlines)
                if !reasoningTrim.isEmpty {
                    self.viewModel.reasoningSummary = fetchedReasoning
                } else {
                    let fallback = makeReasoningSummary(from: reasoningMap)
                    if !fallback.isEmpty {
                        self.viewModel.reasoningSummary = fallback
                        print("⚠️ Firestore 今日文档没有 reasoning_summary 或为空（docId=\(userId)_\(today)），已从 reasoning 生成")
                    } else {
                        print("⚠️ Firestore 今日文档没有 reasoning_summary 或为空（docId=\(userId)_\(today)）")
                    }
                }

                self.ensureDefaultsIfMissing()
                self.fetchAllRecommendationTitles()
                self.persistWidgetSnapshotFromViewModel()
                self.markMantraReadyIfPossible()

                print("✅ 成功加载今日推荐（固定 docId 优先）：\(recs), mantra=\(!mantraTrim.isEmpty), reasoning=\(!reasoningTrim.isEmpty), place=\(fetchedPlace)")
                finish()
            }
        }

        // 1) ✅ 优先读取固定 docId：uid_yyyy-MM-dd
        fixedDocRef.getDocument(source: source) { snap, err in
            if let err = err {
                if source == .cache && allowRemoteFallback {
                    loadTodayRecommendation(day: today, source: .default, allowRemoteFallback: true, completion: completion)
                    return
                }
                print("❌ 读取今日固定 docId 失败：\(err.localizedDescription)；使用本地默认内容")
                DispatchQueue.main.async {
                    self.ensureDefaultsIfMissing()
                    finish()
                }
                return
            }

            if let snap = snap, snap.exists, let data = snap.data() {
                applyDailyData(data)
                return
            }

            if source == .cache && allowRemoteFallback {
                loadTodayRecommendation(day: today, source: .default, allowRemoteFallback: true, completion: completion)
                return
            }

            guard allowRemoteFallback else {
                DispatchQueue.main.async {
                    self.ensureDefaultsIfMissing()
                    finish()
                }
                return
            }

            // 2) 兼容旧数据：回退查询随机 docId 文档
            db.collection("daily_recommendation")
                .whereField("uid", isEqualTo: userId)
                .whereField("createdAt", isEqualTo: today)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ 回退查询今日推荐失败：\(error). 使用本地默认内容")
                        DispatchQueue.main.async {
                            self.ensureDefaultsIfMissing()
                            finish()
                        }
                        return
                    }

                    guard let docs = snapshot?.documents, !docs.isEmpty else {
                        print("⚠️ 今日暂无推荐数据。使用本地默认内容")
                        DispatchQueue.main.async {
                            self.ensureDefaultsIfMissing()
                            finish()
                        }
                        return
                    }

                    let best = docs.max { a, b in
                        let ta = (a.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                        let tb = (b.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                        return ta < tb
                    } ?? docs[0]

                    let data = best.data()
                    applyDailyData(data)

                    // 3) ✅ 迁移写回固定 docId
                    var migrated = data
                    migrated["uid"] = userId
                    migrated["createdAt"] = today
                    migrated["updatedAt"] = FieldValue.serverTimestamp()

                    fixedDocRef.setData(migrated, merge: true) { e in
                        if let e = e {
                            print("⚠️ 迁移写入固定 docId 失败：\(e.localizedDescription)")
                        } else {
                            print("✅ 已迁移今日推荐到固定 docId（避免返回首页随机命中旧文档）")
                        }
                    }
                }
        }
    }
    
    private func debugAndRefreshReasoningSummaryFromFirestore(day: String? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ debugReasoning: 未登录")
            return
        }

        let today = day ?? todayString()
        let docRef = todayDocRef(uid: uid, day: today)

        docRef.getDocument { snap, err in
            if let err = err {
                print("❌ debugReasoning: 读取 docId=\(uid)_\(today) 失败：\(err.localizedDescription)")
                return
            }

            guard let snap = snap, snap.exists, let data = snap.data() else {
                print("⚠️ debugReasoning: 今日文档不存在（docId=\(uid)_\(today)）")
                return
            }

            // ✅ 打印全部 keys，帮你确认到底写进去了什么字段
            let keys = data.keys.sorted()
            print("🔎 debugReasoning: keys = \(keys)")

            // ✅ 尝试读取两种 key
            let r1 = (data["reasoning_summary"] as? String) ?? ""
            let r2 = (data["reasoningSummary"] as? String) ?? ""
            let reasoning = [r1, r2]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? ""

            if reasoning.isEmpty {
                print("⚠️ debugReasoning: reasoning 为空。reasoning_summary=\(r1.count) chars, reasoningSummary=\(r2.count) chars")
            } else {
                print("✅ debugReasoning: 拿到 reasoning，长度=\(reasoning.count)")
                DispatchQueue.main.async {
                    self.viewModel.reasoningSummary = reasoning
                }
            }
        }
    }





    // === Case-insensitive category normalization ===
    // 后端可能返回 "color" / "Color" / "COLOR"；统一映射到规范写法
    private let categoryCanonicalMap: [String: String] = [
        "place": "Place",
        "gemstone": "Gemstone",
        "color": "Color",
        "scent": "Scent",
        "activity": "Activity",
        "sound": "Sound",
        "career": "Career",
        "relationship": "Relationship"
    ]

    private func canonicalCategory(from raw: String) -> String? {
        categoryCanonicalMap[raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    // ✅ 仅允许的类别白名单
    private let allowedCategories: Set<String> = [
        "Place", "Gemstone", "Color", "Scent",
        "Activity", "Sound", "Career", "Relationship"
    ]

    // ✅ 类别 -> 集合名 映射函数（返回可选，未知类别返回 nil）
    private func firebaseCollectionName(for rawCategory: String) -> String? {
        let category = rawCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        switch category {
        case "Place":        return "places"
        case "Gemstone":     return "gemstones"
        case "Color":        return "colors"
        case "Scent":        return "scents"
        case "Activity":     return "activities"
        case "Sound":        return "sounds"
        case "Career":       return "careers"
        case "Relationship": return "relationships"
        default:
            return nil
        }
    }

    // ✅ 文档名清洗：移除会破坏路径的字符（如 /、\、# 等）
    //   Firestore 文档 ID 不允许包含斜杠；这里最小清洗，保留字母数字下划线与连字符。
    private func sanitizeDocumentName(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Reasoning Bubble UI

struct ReasoningBubbleView: View {
    let text: String
    let textColor: Color
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(text)
                    .font(.custom("Merriweather-Regular", size: 14))
                    .foregroundColor(textColor)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 10)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.8))
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            SpeechBubbleShape(tailWidth: 18, tailHeight: 10, tailOffsetX: 0)
                .fill(Color.black.opacity(0.72))
        )
        .overlay(
            SpeechBubbleShape(tailWidth: 18, tailHeight: 10, tailOffsetX: 0)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
        .accessibilityLabel("Reasoning summary bubble")
    }
}

struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 18
    var tailWidth: CGFloat = 18
    var tailHeight: CGFloat = 10
    /// tailOffsetX: 0 means centered; negative moves left, positive moves right
    var tailOffsetX: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()

        // Bubble rect is lowered to make room for the tail on top
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY + tailHeight,
            width: rect.width,
            height: rect.height - tailHeight
        )

        // Rounded rect
        p.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        // Tail (top-middle)
        let centerX = rect.midX + tailOffsetX
        let tailHalf = tailWidth / 2

        let a = CGPoint(x: centerX - tailHalf, y: bubbleRect.minY)
        let b = CGPoint(x: centerX, y: rect.minY)
        let c = CGPoint(x: centerX + tailHalf, y: bubbleRect.minY)

        p.move(to: a)
        p.addLine(to: b)
        p.addLine(to: c)
        p.closeSubpath()

        return p
    }
}



enum DesignRecs {
    static let docs: [String:String] = [
        "Place": "echo_niche",
        "Gemstone": "amethyst",
        "Color": "amber",
        "Scent": "bergamot",
        "Activity": "clean_mirror",
        "Sound": "brown_noise",
        "Career": "clear_channel",
        "Relationship": "breathe_sync"
    ]
    static let titles: [String:String] = [
        "Place": "Echo Niche", "Gemstone": "Amethyst", "Color": "Amber",
        "Scent": "Bergamot", "Activity": "Polishing Mirror",
        "Sound": "Brown Noise", "Career": "Clear Channel",
        "Relationship": "Breathe in Sync"
    ]
    static let mantra = "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care."
}


#if DEBUG
extension MainView {
    init(previewBoot: BootPhase) {
        self.init()
        _bootPhase = State(initialValue: previewBoot) // jump straight to .main
    }
}
#endif

#if DEBUG
private struct FirstPagePreviewContainer: View {
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager
    @StateObject private var viewModel: OnboardingViewModel
    @StateObject private var reasoningStore = DailyReasoningStore()

    init() {
        let themeManager = ThemeManager()
        themeManager.selected = .day
        _themeManager = StateObject(wrappedValue: themeManager)

        let viewModel = OnboardingViewModel()
        viewModel.recommendations = [
            "Place": "echo_niche",
            "Gemstone": "amethyst",
            "Color": "amber",
            "Scent": "bergamot",
            "Activity": "clean_mirror",
            "Sound": "brown_noise",
            "Career": "clear_channel",
            "Relationship": "breathe_sync"
        ]
        viewModel.dailyMantra = "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care."
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        MainView(previewBoot: .main)
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .environmentObject(viewModel)
            .environmentObject(reasoningStore)
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Main View") {
    FirstPagePreviewContainer()
}
#endif

#if DEBUG
let _isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#endif


enum RecCategory: String, CaseIterable, Identifiable {
    case Place, Gemstone, Color, Scent, Activity, Sound, Career, Relationship
    var id: String { rawValue }
}

struct RecommendationPagerView: View {
    let docsByCategory: [RecCategory: String]
    let selected: RecCategory

    @State private var selectedIndex: Int = 1

    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var categories: [RecCategory] { RecCategory.allCases }
    private var loopedCategories: [RecCategory] {
        guard let first = categories.first, let last = categories.last else { return [] }
        return [last] + categories + [first]
    }

    var body: some View {
        ZStack {
            // Full-bleed background
            AppBackgroundView()
                .environmentObject(starManager)
                .ignoresSafeArea() // <- key line

            TabView(selection: $selectedIndex) {
                ForEach(loopedCategories.indices, id: \.self) { idx in
                    let cat = loopedCategories[idx]
                    Group {
                        if let doc = docsByCategory[cat], !doc.isEmpty {
                            pageView(for: cat, documentName: doc).id(doc)
                        } else {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading \(cat.rawValue)…")
                                    .foregroundColor(themeManager.descriptionText.opacity(0.7))
                            }
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .onAppear {
                if let start = categories.firstIndex(of: selected) {
                    selectedIndex = start + 1
                }
            }
            .onChange(of: selectedIndex) { _, newValue in
                let lastIndex = loopedCategories.count - 1
                if newValue == 0 {
                    withAnimation(.none) { selectedIndex = lastIndex - 1 }
                } else if newValue == lastIndex {
                    withAnimation(.none) { selectedIndex = 1 }
                }
            }

            CustomBackButton(
                //                iconSize: 18,
                ////                paddingSize: 8,
                //                backgroundColor: Color.black.opacity(0.3),
                //                iconColor: themeManager.primaryText,
                ////                topPadding: 120,
                //                horizontalPadding: 24
            )
            .onTapGesture {
                dismiss()          // pop back to FirstPageView
            }
        }
        // Prevent the default nav bar blur from showing at the top
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar) // if you don’t want any bar at all
        .preferredColorScheme(themeManager.preferredColorScheme)
    }
    
    @ViewBuilder
    private func pageView(for cat: RecCategory, documentName: String) -> some View {
        switch cat {
        case .Place:
            PlaceDetailView(documentName: documentName)
        case .Gemstone:
            GemstoneDetailView(documentName: documentName)
        case .Color:
            ColorDetailView(documentName: documentName)
        case .Scent:
            ScentDetailView(documentName: documentName)
        case .Activity:
            ActivityDetailView(documentName: documentName)
//                               soundDocumentName: docsByCategory[.Sound] ?? "")
        case .Sound:
            SoundDetailView(documentName: documentName)
        case .Career:
            CareerDetailView(documentName: documentName)
        case .Relationship:
            RelationshipDetailView(documentName: documentName)
        }
    }
}







// Back button

struct CustomBackButton: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    // Match the Account Detail look (clean icon, no circle)
    var iconSize: CGFloat = 26
    var topPadding: CGFloat = 20
    var horizontalPadding: CGFloat = 20
    var showsBackground: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(themeManager.primaryText)
                        .padding(showsBackground ? 12 : 0)
                        .background(showsBackground ? Color.white.opacity(0.10) : Color.clear)
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                Spacer()
            }
            .padding(.top, topPadding)
            .padding(.horizontal, horizontalPadding)
            Spacer()
        }
    }
}





// 替换你文件中现有的 OnboardingViewModel
import FirebaseFirestore
import FirebaseAuth
import MapKit

