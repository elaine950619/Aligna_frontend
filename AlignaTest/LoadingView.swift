import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit
import FirebaseAuth
import FirebaseFirestore
import UIKit

func moonPhaseLabel(for date: Date = Date()) -> String {
    let synodicMonth = 29.53058867
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = 2000
    components.month = 1
    components.day = 6
    components.hour = 18
    components.minute = 14

    guard let anchorDate = components.date else {
        return "New Moon"
    }

    let days = date.timeIntervalSince(anchorDate) / 86400
    let phase = days - floor(days / synodicMonth) * synodicMonth

    switch phase {
    case 0..<1.84566:
        return "New Moon"
    case 1.84566..<5.53699:
        return "Waxing Crescent"
    case 5.53699..<9.22831:
        return "First Quarter"
    case 9.22831..<12.91963:
        return "Waxing Gibbous"
    case 12.91963..<16.61096:
        return "Full Moon"
    case 16.61096..<20.30228:
        return "Waning Gibbous"
    case 20.30228..<23.99361:
        return "Third Quarter"
    case 23.99361..<27.68493:
        return "Waning Crescent"
    default:
        return "New Moon"
    }
}

/// Localized display version of moon phase label (for UI only — not for API payloads).
func localizedMoonPhaseLabel(for date: Date = Date()) -> String {
    let key: String
    let raw = moonPhaseLabel(for: date)
    switch raw {
    case "New Moon":       key = "loading.moon_phase.new"
    case "Waxing Crescent": key = "loading.moon_phase.waxing_crescent"
    case "First Quarter":  key = "loading.moon_phase.first_quarter"
    case "Waxing Gibbous": key = "loading.moon_phase.waxing_gibbous"
    case "Full Moon":      key = "loading.moon_phase.full"
    case "Waning Gibbous": key = "loading.moon_phase.waning_gibbous"
    case "Third Quarter":  key = "loading.moon_phase.third_quarter"
    case "Waning Crescent": key = "loading.moon_phase.waning_crescent"
    default:               key = "loading.moon_phase.new"
    }
    return String(localized: String.LocalizationValue(key))
}

enum BootPhase {
    case loading
    case onboarding   // ← 新增：需要走新手引导
    case main
}


func currentZodiacSign(for date: Date = Date()) -> String {
    let cal = Calendar(identifier: .gregorian)
    let (m, d) = (cal.component(.month, from: date), cal.component(.day, from: date))
    switch (m, d) {
    case (3,21...31),(4,1...19):  return "♈️ \(zodiacLocalizedName(for: "Aries"))"
    case (4,20...30),(5,1...20):  return "♉️ \(zodiacLocalizedName(for: "Taurus"))"
    case (5,21...31),(6,1...20):  return "♊️ \(zodiacLocalizedName(for: "Gemini"))"
    case (6,21...30),(7,1...22):  return "♋️ \(zodiacLocalizedName(for: "Cancer"))"
    case (7,23...31),(8,1...22):  return "♌️ \(zodiacLocalizedName(for: "Leo"))"
    case (8,23...31),(9,1...22):  return "♍️ \(zodiacLocalizedName(for: "Virgo"))"
    case (9,23...30),(10,1...22): return "♎️ \(zodiacLocalizedName(for: "Libra"))"
    case (10,23...31),(11,1...21):return "♏️ \(zodiacLocalizedName(for: "Scorpio"))"
    case (11,22...30),(12,1...21):return "♐️ \(zodiacLocalizedName(for: "Sagittarius"))"
    case (12,22...31),(1,1...19): return "♑️ \(zodiacLocalizedName(for: "Capricorn"))"
    case (1,20...31),(2,1...18):  return "♒️ \(zodiacLocalizedName(for: "Aquarius"))"
    default:                      return "♓️ \(zodiacLocalizedName(for: "Pisces"))"
    }
}

/// quick-and-pleasant moon phase label (like your React demo)
func currentMoonPhaseLabel(for date: Date = Date()) -> String {
    // Simple ~29.53 day cycle approximation
    let synodic: Double = 29.53058867
    // Anchor: 2000-01-06 18:14 UTC is a known new moon (approx). Good enough for a splash.
    let anchor = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: .init(secondsFromGMT: 0),
        year: 2000, month: 1, day: 6, hour: 18, minute: 14
    ).date!
    
    let days = date.timeIntervalSince(anchor) / 86400
    let phase = (days - floor(days / synodic) * synodic) // [0, synodic)
    switch phase {
    case 0..<1.84566:  return "New Moon"
    case 1.84566..<5.53699: return "Waxing Crescent"
    case 5.53699..<9.22831: return "First Quarter"
    case 9.22831..<12.91963: return "Waxing Gibbous"
    case 12.91963..<16.61096: return "Full Moon"
    case 16.61096..<20.30228: return "Waning Gibbous"
    case 20.30228..<23.99361: return "Third Quarter"
    case 23.99361..<27.68493: return "Waning Crescent"
    default: return "New Moon"
    }
}

// MARK: - Helpers
extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hexSanitized.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 1)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: opacity)
    }
}
// ====== Time & Parse Helpers (新增) ======
struct ISO8601Calendar {
    private static let f1: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let f2: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func date(from s: String) -> Date? { f1.date(from: s) ?? f2.date(from: s) }
}

/// 仅用“本地时区的时分”构造一个 Date（锚定在固定参考日，避免跨时区/日期导致显示漂移）
func makeLocalDate(hour: Int, minute: Int, tz: TimeZone = .current) -> Date? {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    // 选择一个固定参考日（不会用于展示，只为承载时分）
    var comp = DateComponents()
    comp.year = 2000; comp.month = 1; comp.day = 1
    comp.hour = hour; comp.minute = minute
    return cal.date(from: comp)
}

/// 兼容 "HH:mm" / "H:mm" / "h:mm a" / "hh:mm a"
func timeToDateFlexible(_ s: String, tz: TimeZone = .current) -> Date? {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let fmts = ["HH:mm","H:mm","h:mm a","hh:mm a","h:mma","hh:mma"]
    for pat in fmts {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = pat
        if let d = f.date(from: trimmed) {
            let cal = Calendar(identifier: .gregorian)
            let hm = cal.dateComponents([.hour,.minute], from: d)
            return makeLocalDate(hour: hm.hour ?? 0, minute: hm.minute ?? 0, tz: tz)
        }
    }
    return nil
}
// 兼容 "yyyy-MM-dd" 和 "yyyy/M/d" 的日期解析（本地时区）
private let DF_YMD: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private let DF_YMD_SLASH: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy/M/d"
    return f
}()

@inline(__always)
func parseBirthDateString(_ s: String) -> Date? {
    // 先试 ISO8601（含 T…Z 的情况），再试两种纯日期
    return ISO8601Calendar.date(from: s) ?? DF_YMD.date(from: s) ?? DF_YMD_SLASH.date(from: s)
}

private struct LoadingNotesEditorSheet: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let initialText: String
    let onSave: (String) -> Void

    @State private var draft: String
    @FocusState private var isEditorFocused: Bool

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        _draft = State(initialValue: initialText)
    }

    var body: some View {
        ZStack {
            (themeManager.isNight ? Color(hex: "#0E1820").opacity(0.85) : Color.white.opacity(0.6))
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Button(String(localized: "loading.close")) { dismiss() }
                        .font(.custom("Merriweather-Regular", size: 16))

                    Spacer()

                    Button(String(localized: "loading.save")) {
                        onSave(draft)
                        dismiss()
                    }
                    .font(.custom("Merriweather-Bold", size: 16))
                }
                .foregroundColor(themeManager.accent)
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Text("loading.notes")
                    .font(.custom("Merriweather-Bold", size: 22))
                    .foregroundColor(themeManager.primaryText)

                TextEditor(text: $draft)
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .foregroundColor(themeManager.primaryText.opacity(0.92))
                    .tint(themeManager.accent)
                    .font(.system(.body, design: .rounded))
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(themeManager.panelFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(themeManager.panelStrokeHi.opacity(0.9), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)
            }
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isEditorFocused = true
            }
        }
    }
}


// Subtle text shimmer like your React “brand-title animate-text-shimmer”
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.7), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .blendMode(.screen)
                .mask(content)

            )
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}
extension View { func shimmer() -> some View { modifier(Shimmer()) } }

struct AlynnaGenerationOverlayCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let message: String
    let showDots: Bool
    @State private var dotPhase: Int = 0

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(themeManager.primaryText)

            Text(title)
                .font(.custom("Merriweather-Bold", size: 18))
                .foregroundColor(themeManager.primaryText)

            Text(message)
                .font(.custom("Merriweather-Regular", size: 12))
                .foregroundColor(themeManager.descriptionText.opacity(0.88))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if showDots {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(themeManager.primaryText.opacity(dotPhase == index ? 0.95 : 0.28))
                            .frame(width: 5, height: 5)
                            .offset(y: dotPhase == index ? -2 : 0)
                            .animation(.easeInOut(duration: 0.22), value: dotPhase)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(themeManager.isNight ? Color(hex: "#131F2E").opacity(0.96) : Color.white.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(themeManager.isNight ? Color.white.opacity(0.16) : Color.black.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(themeManager.isNight ? 0.34 : 0.18), radius: 20, x: 0, y: 10)
        .onAppear {
            guard showDots else { return }
            dotPhase = 0
            Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { timer in
                if dotPhase >= 0 {
                    dotPhase = (dotPhase + 1) % 3
                } else {
                    timer.invalidate()
                }
            }
        }
        .onDisappear {
            dotPhase = -1
        }
    }
}

// MARK: - LoadingView

struct LoadingView: View {
    var onStartLoading: (() -> Void)? = nil
    var onPersonalComplete: ((Bool) -> Void)? = nil
    var onFocusSelected: ((String) -> Void)? = nil
    var onAddCustomFocus: (() -> Void)? = nil
    var onCancelLoading: (() -> Void)? = nil
    private let focuses: [FocusSelectionView.FocusItem]
    private let presenceFocusID: String
    private let fixedMessageIndex: Int?
    private let forceFullLoading: Bool

    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var locationPermissionCoordinator: LocationPermissionCoordinator
    @ObservedObject var locationManager: LocationManager
    @AppStorage("showMainGenerationOverlay") private var showMainGenerationOverlay: Bool = false

    @State private var didStartLoading = false
    @State private var didFetchPlaceSignals = false
    @State private var stage: LoadingStage = .initial  // overridden in onAppear
    @State private var selectedFocusID: String?
    @State private var initialPulse = false

    @AppStorage("lastRecommendationTimestamp") private var lastRecommendationTimestamp: Double = 0
    @AppStorage("lastRecommendationHasFullSet") private var lastRecommendationHasFullSet: Bool = false
    @AppStorage("cachedDailyMantra") private var cachedDailyMantra: String = ""
    @AppStorage("shouldExpandMantraOnBoot") private var shouldExpandMantraOnBoot: Bool = false
    @State private var cosmicEmojiIndex = 0
    @State private var placeEmojiIndex = 0
    @State private var personalIconIndex = 0
    @State private var iconShakePhase: CGFloat = -1
    @State private var dotPhase = 0
    @State private var iconVisible = true
    @State private var autoSkipWorkItem: DispatchWorkItem?
    @State private var autoSkipSecondsRemaining = 0
    @State private var autoSkipTimer: Timer?
    @State private var cosmicPlaceWorkItem: DispatchWorkItem?
    @State private var placePersonalWorkItem: DispatchWorkItem?
    @State private var didAlreadyPassedStages = false
    @State private var personalCompleted = false
    @State private var isProcessingPersonal = false
    @State private var didInteractPersonal = false
    @State private var isGeneratingOverlayVisible = false

    @State private var mood: String? = nil
    @State private var stress: String? = nil
    @State private var sleep: String? = nil
    @State private var source: String? = nil
    @State private var personalNotes: String = ""
    @State private var showPersonalNotesEditor = false

    @State private var sunText: String = "—"
    @State private var moonText: String = "—"
    @State private var risingText: String = "—"
    @State private var locationText: String = "Your Current Location"
    @State private var conditionText: String = "Cloud · Wind · Rain"
    @State private var airQualityText: String = "Air quality —"
    @State private var placeDensityText: String = "Water — · Green — · Built —"
    @AppStorage("widgetLocationName") private var widgetLocationName: String = ""
    @AppStorage("widgetAirQualityText", store: UserDefaults(suiteName: AlynnaAppGroup.id))
    private var widgetAirQualityText: String = ""
    @AppStorage("widgetSunSign") private var widgetSunSign: String = ""
    @AppStorage("widgetMoonSign") private var widgetMoonSign: String = ""
    @AppStorage("widgetRisingSign") private var widgetRisingSign: String = ""
    @AppStorage("widgetWeatherSummary") private var widgetWeatherSummary: String = ""
    @AppStorage("widgetWeatherDetailSummary") private var widgetWeatherDetailSummary: String = ""
    @AppStorage("widgetEnvironmentSummary") private var widgetEnvironmentSummary: String = ""

    // Structured place signals (written to viewModel once fetched)
    @State private var placeTemperature: Double? = nil
    @State private var placeWindDirection: String? = nil
    @State private var placeWindSpeed: Double? = nil
    @State private var placeHumidity: Double? = nil
    @State private var placePressure: Double? = nil

    init(
        onStartLoading: (() -> Void)? = nil,
        onCancelLoading: (() -> Void)? = nil,
        onPersonalComplete: ((Bool) -> Void)? = nil,
        onFocusSelected: ((String) -> Void)? = nil,
        focuses: [FocusSelectionView.FocusItem] = [],
        presenceFocusID: String = "",
        currentFocusID: String? = nil,
        fixedMessageIndex: Int? = nil,
        forceFullLoading: Bool = false,
        locationManager: LocationManager = LocationManager()
    ) {
        self.onStartLoading = onStartLoading
        self.onCancelLoading = onCancelLoading
        self.onPersonalComplete = onPersonalComplete
        self.onFocusSelected = onFocusSelected
        self.focuses = focuses
        self.presenceFocusID = presenceFocusID
        self.fixedMessageIndex = fixedMessageIndex
        self.forceFullLoading = forceFullLoading
        _locationManager = ObservedObject(wrappedValue: locationManager)
        // Pre-select the last chosen focus; fall back to presence
        let initial = currentFocusID?.isEmpty == false ? currentFocusID : presenceFocusID
        _selectedFocusID = State(initialValue: initial)
    }

    fileprivate enum LoadingStage: Int {
        case focusSelection
        case initial
        case cosmic
        case place
        case personal
        case gathering
    }

    private var anyPersonalSelection: Bool {
        mood != nil || stress != nil || sleep != nil
    }

    private var shouldAutoSkipPersonal: Bool {
        let hasNotes = !personalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !didInteractPersonal && !hasNotes
    }

    private var hasRecentRecommendation: Bool {
        guard lastRecommendationHasFullSet else { return false }
        let age = Date().timeIntervalSince1970 - lastRecommendationTimestamp
        return age >= 0 && age < 24 * 60 * 60
    }

    private var shouldGenerateTodayReading: Bool {
        forceFullLoading || !hasRecentRecommendation
    }

    private var shouldRunFullLoading: Bool {
        forceFullLoading
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                // === Main content ===
                VStack(spacing: 22) {
                    stageContent
                }
                .frame(maxWidth: 520, maxHeight: stage == .focusSelection ? .infinity : nil, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.top, stage == .focusSelection ? 0 : 28)
                .padding(.bottom, stage == .focusSelection ? 0 : 24)

                VStack {
                    Spacer()
                    if let footer = footerText {
                        Text(footer)
                            .font(.custom("Merriweather-Regular", size: 10))
                            .foregroundColor(themeManager.descriptionText.opacity(0.7))
                            .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal, 16)

                // === Confirm button pinned to bottom for focus selection ===
                if stage == .focusSelection {
                    let sandColor = Color(red: 0.94, green: 0.88, blue: 0.72)
                    VStack {
                        Spacer()
                        Button {
                            if let id = selectedFocusID {
                                advanceFromFocusSelection(focusID: id)
                            }
                        } label: {
                            Text("focus.confirm_button")
                                .font(.custom("Merriweather-Regular", size: 16))
                                .foregroundColor(selectedFocusID != nil
                                    ? Color(red: 0.12, green: 0.10, blue: 0.08)
                                    : themeManager.descriptionText.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedFocusID != nil
                                            ? sandColor
                                            : themeManager.panelFill.opacity(0.3))
                                )
                        }
                        .disabled(selectedFocusID == nil)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                }

                // === Personal stage back arrow (only in full loading flow) ===
                if stage == .personal && forceFullLoading {
                    VStack {
                        HStack {
                            Button {
                                cancelAllStageWork()
                                didAlreadyPassedStages = true
                                withAnimation(.easeInOut(duration: 0.3)) { stage = .focusSelection }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(themeManager.primaryText)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 12)
                            Spacer()
                        }
                        .padding(.top, 64)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(true)
                }

                // === Gathering stage back arrow ===
                if stage == .gathering && forceFullLoading {
                    VStack {
                        HStack {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) { stage = .personal }
                                loadPersonalSelections()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(themeManager.primaryText)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 12)
                            Spacer()
                        }
                        .padding(.top, 64)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(true)
                }

            }
            .onAppear {
                if !didStartLoading {
                    didStartLoading = true
                    onStartLoading?()
                }
                // Set correct initial stage — .focusSelection only for full loading flows with focuses
                if forceFullLoading && !focuses.isEmpty {
                    stage = .focusSelection
                    selectedFocusID = nil
                } else {
                    stage = .initial
                }
                locationPermissionCoordinator.refreshAuthorizationStatus()
                scheduleStageProgression()
                startEmojiTimers()
                startIconShake()
                startDotTimer()
                startIconFadeTimer()
                fetchChartDataFromFirestore()
                // Seed place/weather immediately if location is already known;
                // otherwise ask for it so .onReceive fires when it arrives.
                if let coord = locationManager.currentLocation {
                    fetchPlaceAndWeather(for: coord)
                } else if locationPermissionCoordinator.authorizationStatus != .denied &&
                            locationPermissionCoordinator.authorizationStatus != .restricted {
                    locationManager.requestLocation()
                }
            }
            .onChange(of: stage, initial: false) { _, newStage in
                startIconShake()
                if newStage == .personal {
                    loadPersonalSelections()
                    scheduleAutoSkipIfNeeded()
                } else {
                    autoSkipWorkItem?.cancel()
                    autoSkipTimer?.invalidate()
                    autoSkipSecondsRemaining = 0
                }
            }
            .onChange(of: didInteractPersonal, initial: false) { _, interacted in
                if interacted {
                    autoSkipWorkItem?.cancel()
                    autoSkipTimer?.invalidate()
                    autoSkipSecondsRemaining = 0
                }
            }
            .onChange(of: personalNotes, initial: false) { _, notes in
                let hasNotes = !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if hasNotes {
                    didInteractPersonal = true
                }
            }
            .onReceive(locationManager.$currentLocation.compactMap { $0 }) { coord in
                fetchPlaceAndWeather(for: coord)
            }
            .onChange(of: locationPermissionCoordinator.authorizationStatus) { _, status in
                if (status == .authorizedAlways || status == .authorizedWhenInUse),
                   locationManager.currentLocation == nil {
                    locationManager.requestLocation()
                }
            }
            .preferredColorScheme(themeManager.preferredColorScheme)
            .sheet(isPresented: $showPersonalNotesEditor) {
                LoadingNotesEditorSheet(initialText: personalNotes) { updatedText in
                    personalNotes = updatedText
                }
                .environmentObject(starManager)
                .environmentObject(themeManager)
            }
        }
    }

    private var stageContent: some View {
        let headerHeight: CGFloat = 120
        let contentHeight: CGFloat = 240
        return VStack(spacing: 12) {
            switch stage {
            case .focusSelection:
                focusSelectionStage

            case .initial:
                initialHeader
                    .frame(height: headerHeight + contentHeight, alignment: .top)

            case .cosmic:
                stageHeader(title: String(localized: "loading.cosmic"),
                            subtitle: cosmicSubtitleView,
                            iconName: cosmicIcons[cosmicEmojiIndex],
                            topPadding: 0)
                    .frame(height: headerHeight + contentHeight, alignment: .top)

            case .place:
                stageHeader(title: String(localized: "loading.place"),
                            subtitle: placeSubtitleView,
                            iconName: placeIcons[placeEmojiIndex],
                            topPadding: 0)
                    .frame(height: headerHeight + contentHeight, alignment: .top)

            case .personal:
                stageHeader(title: String(localized: "loading.personal"),
                            subtitle: personalSubtitleText,
                            iconName: personalIcons[personalIconIndex],
                            topPadding: 6)
                    .frame(height: headerHeight, alignment: .top)
                VStack(spacing: 8) {
                    personalCheckIn
                }
                .frame(height: contentHeight, alignment: .top)
                .padding(.top, 28)

            case .gathering:
                stageHeader(title: String(localized: "loading.gathering"),
                            subtitle: EmptyView(),
                            iconName: "sparkles.rectangle.stack.fill",
                            topPadding: 6)
                    .frame(height: headerHeight, alignment: .top)
                VStack(spacing: 10) {
                    gatheringSummary
                }
                .frame(height: contentHeight, alignment: .top)
                .padding(.top, 10)
            }
        }
    }

    private func stageHeader<Subtitle: View>(title: String, subtitle: Subtitle, iconName: String, topPadding: CGFloat) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.custom("Merriweather-Bold", size: 20))
                .foregroundColor(themeManager.primaryText)
            iconView(iconName, size: 56)
                .opacity(iconVisible ? 1.0 : 0.35)
                .offset(x: iconShakePhase * 2, y: iconShakePhase * -1)
                .animation(.easeInOut(duration: 0.35), value: iconVisible)
            subtitle
            if stage == .cosmic || stage == .place {
                loadingDots
            }
        }
        .padding(.top, topPadding)
    }


    // MARK: - Focus Selection Full Screen
    @ViewBuilder
    private var focusSelectionFullScreen: some View {
        let sandColor = Color(red: 0.94, green: 0.88, blue: 0.72)
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        let groupDefs: [(key: String, labelKey: String)] = [
            ("everyday",      "focus.group.everyday"),
            ("relationships", "focus.group.relationships"),
            ("body",          "focus.group.body"),
            ("transitions",   "focus.group.transitions"),
            ("inner",         "focus.group.inner"),
            ("practical",     "focus.group.practical"),
        ]

        VStack(spacing: 0) {
            // Title — sits in the upper area with safe area padding
            Text("focus.select_title")
                .font(.custom("Merriweather-Bold", size: 20))
                .foregroundColor(themeManager.primaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 56)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            // Scrollable grid fills all available space
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Presence focus — half-width in 2-col grid
                    if let presenceItem = focuses.first(where: { $0.id == presenceFocusID }) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            focusCardInline(presenceItem, sandColor: sandColor)
                        }
                        .padding(.bottom, 12)
                    }

                    ForEach(groupDefs, id: \.key) { group in
                        let groupItems = focuses.filter { $0.groupKey == group.key }
                        if !groupItems.isEmpty {
                            HStack(spacing: 10) {
                                Text(String(localized: String.LocalizationValue(group.labelKey)))
                                    .font(.custom("Merriweather-Regular", size: 10))
                                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .fixedSize()
                                Rectangle()
                                    .fill(themeManager.descriptionText.opacity(0.15))
                                    .frame(height: 1)
                            }
                            .padding(.bottom, 10)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(groupItems) { item in
                                    focusCardInline(item, sandColor: sandColor)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }

                    let customItems = focuses.filter { $0.groupKey.isEmpty && $0.id != presenceFocusID }
                    if !customItems.isEmpty {
                        HStack(spacing: 10) {
                            Text(String(localized: "focus.add_custom"))
                                .font(.custom("Merriweather-Regular", size: 10))
                                .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .fixedSize()
                            Rectangle()
                                .fill(themeManager.descriptionText.opacity(0.15))
                                .frame(height: 1)
                        }
                        .padding(.bottom, 10)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(customItems) { item in
                                focusCardInline(item, sandColor: sandColor)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            // Confirm button pinned to bottom
            Button {
                if let id = selectedFocusID {
                    advanceFromFocusSelection(focusID: id)
                }
            } label: {
                Text("focus.confirm_button")
                    .font(.custom("Merriweather-Regular", size: 16))
                    .foregroundColor(selectedFocusID != nil
                        ? Color(red: 0.12, green: 0.10, blue: 0.08)
                        : themeManager.descriptionText.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selectedFocusID != nil
                                ? sandColor
                                : themeManager.panelFill.opacity(0.3))
                    )
            }
            .disabled(selectedFocusID == nil)
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Focus Selection Stage (fixed-height, kept for stageContent switch)
    @ViewBuilder
    private var focusSelectionStage: some View {
        let sandColor = Color(red: 0.94, green: 0.88, blue: 0.72)
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        // Groups mirroring FocusSelectionView order
        let groupDefs: [(key: String, labelKey: String)] = [
            ("everyday",      "focus.group.everyday"),
            ("relationships", "focus.group.relationships"),
            ("body",          "focus.group.body"),
            ("transitions",   "focus.group.transitions"),
            ("inner",         "focus.group.inner"),
            ("practical",     "focus.group.practical"),
        ]

        VStack(spacing: 0) {
            // Back arrow row
            HStack {
                Button {
                    onCancelLoading?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(themeManager.primaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
                Spacer()
            }
            .padding(.top, 64)

            // Title
            Text("focus.select_title")
                .font(.custom("Merriweather-Bold", size: 20))
                .foregroundColor(themeManager.primaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Scrollable focus grid — fills all remaining height in the stage frame
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Presence focus — same 2-col grid as other cards ──
                    if let presenceItem = focuses.first(where: { $0.id == presenceFocusID }) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            focusCardInline(presenceItem, sandColor: sandColor)
                        }
                        .padding(.bottom, 12)
                    }

                    // ── Grouped sections ──
                    ForEach(groupDefs, id: \.key) { group in
                        let groupItems = focuses.filter { $0.groupKey == group.key }
                        if !groupItems.isEmpty {
                            HStack(spacing: 10) {
                                Text(String(localized: String.LocalizationValue(group.labelKey)))
                                    .font(.custom("Merriweather-Regular", size: 10))
                                    .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .fixedSize()
                                Rectangle()
                                    .fill(themeManager.descriptionText.opacity(0.15))
                                    .frame(height: 1)
                            }
                            .padding(.bottom, 10)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(groupItems) { item in
                                    focusCardInline(item, sandColor: sandColor)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }

                    // Custom user focuses (ungrouped, not presence)
                    let customItems = focuses.filter { $0.groupKey.isEmpty && $0.id != presenceFocusID }
                    if !customItems.isEmpty {
                        HStack(spacing: 10) {
                            Text(String(localized: "focus.add_custom"))
                                .font(.custom("Merriweather-Regular", size: 10))
                                .foregroundColor(themeManager.descriptionText.opacity(0.45))
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .fixedSize()
                            Rectangle()
                                .fill(themeManager.descriptionText.opacity(0.15))
                                .frame(height: 1)
                        }
                        .padding(.bottom, 10)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(customItems) { item in
                                focusCardInline(item, sandColor: sandColor)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                // Bottom padding so last cards clear the pinned confirm button
                .padding(.bottom, 100)
            }
        }
    }



    @ViewBuilder
    private func focusCardInline(_ item: FocusSelectionView.FocusItem, sandColor: Color) -> some View {
        let isSelected = selectedFocusID == item.id
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedFocusID = item.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.custom("Merriweather-Bold", size: 13))
                    .foregroundColor(isSelected
                        ? Color(red: 0.12, green: 0.10, blue: 0.08)
                        : themeManager.primaryText.opacity(0.88))
                    .lineLimit(1)
                Text(item.description)
                    .font(.custom("Merriweather-Regular", size: 10))
                    .foregroundColor(isSelected
                        ? Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.60)
                        : themeManager.descriptionText.opacity(0.50))
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                        ? sandColor.opacity(themeManager.isNight ? 0.88 : 0.80)
                        : themeManager.panelFill.opacity(themeManager.isNight ? 0.28 : 0.36))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? sandColor : Color.white.opacity(0.10),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var initialHeader: some View {
        VStack(spacing: 20) {
            Text("loading.initial")
                .font(.custom("Merriweather-Bold", size: 20))
                .foregroundColor(themeManager.primaryText)
            logoView(size: 56)
                .scaleEffect(initialPulse ? 1.0 : 0.96)
                .opacity((initialPulse ? 1.0 : 0.0) * (iconVisible ? 1.0 : 0.35))
                .offset(x: iconShakePhase * 2, y: iconShakePhase * -1)
                .animation(.easeOut(duration: 0.6), value: initialPulse)
                .animation(.easeInOut(duration: 0.35), value: iconVisible)
            initialSubtitleText
                .foregroundColor(themeManager.descriptionText.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .onAppear {
            initialPulse = true
        }
    }

    private func iconView(_ iconName: String, size: CGFloat) -> some View {
        Image(systemName: iconName)
            .font(.system(size: size))
            .foregroundColor(themeManager.primaryText)
            .frame(width: size, height: size, alignment: .center)
            .textSelection(.disabled)
    }

    @ViewBuilder
    private func logoView(size: CGFloat) -> some View {
        if UIImage(named: "alignaSymbol") != nil {
            Image("alignaSymbol")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size, alignment: .center)
                .foregroundColor(themeManager.primaryText)
                .textSelection(.disabled)
        } else {
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size, alignment: .center)
                .foregroundColor(themeManager.primaryText)
                .textSelection(.disabled)
        }
    }

    private var loadingDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(themeManager.primaryText.opacity(dotPhase == index ? 0.9 : 0.25))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.top, 2)
    }

    private func localizedCheckInOptionLabel(_ value: String) -> String {
        switch value {
        case "Joy":   return String(localized: "loading.mood_joy")
        case "Anger": return String(localized: "loading.mood_anger")
        case "Grief": return String(localized: "loading.mood_grief")
        case "Calm":  return String(localized: "loading.mood_calm")
        case "Low":   return String(localized: "loading.stress_low")
        case "Med":   return String(localized: "loading.stress_med")
        case "High":  return String(localized: "loading.stress_high")
        case "Peak":  return String(localized: "loading.stress_peak")
        case "Poor":  return String(localized: "loading.sleep_poor")
        case "OK":    return String(localized: "loading.sleep_ok")
        case "Great": return String(localized: "loading.sleep_great")
        case "Rest":  return String(localized: "loading.sleep_rest")
        default:      return value
        }
    }

    private var personalCheckIn: some View {
        VStack(spacing: 4) {
            compactRow(
                title: String(localized: "loading.mood"),
                options: [("sun.max.fill", "Joy"), ("flame.fill", "Anger"), ("cloud.rain.fill", "Grief"), ("leaf.fill", "Calm")],
                selection: $mood
            )
            compactRow(
                title: String(localized: "loading.stress"),
                options: [("minus.circle", "Low"), ("equal.circle", "Med"), ("plus.circle", "High"), ("bolt.circle", "Peak")],
                selection: $stress
            )
            compactRow(
                title: String(localized: "loading.sleep"),
                options: [("bed.double.fill", "Poor"), ("moon.zzz.fill", "OK"), ("sun.max.fill", "Great"), ("zzz", "Rest")],
                selection: $sleep
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("loading.notes")
                    .font(.custom("Merriweather-Bold", size: 13))
                    .foregroundColor(themeManager.primaryText.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    didInteractPersonal = true
                    showPersonalNotesEditor = true
                } label: {
                    ZStack(alignment: .topLeading) {
                        if personalNotes.isEmpty {
                            Text("loading.tap_to_edit_notes")
                                .font(.custom("Merriweather-Regular", size: 11))
                                .foregroundColor(themeManager.descriptionText.opacity(0.85))
                                .padding(.top, 5)
                                .padding(.leading, 6)
                        } else {
                            Text(personalNotes)
                                .font(.custom("Merriweather-Regular", size: 11))
                                .foregroundColor(themeManager.primaryText)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 2)
                                .padding(.leading, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 66, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(themeManager.primaryText.opacity(0.22), lineWidth: 1)
                )
                .cornerRadius(8)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

            Button {
                didInteractPersonal = true
                continueToGathering()
            } label: {
                HStack(spacing: 8) {
                    if isProcessingPersonal {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(themeManager.buttonForegroundOnPrimary)
                            .scaleEffect(0.75)
                    }
                    Text(isProcessingPersonal ? String(localized: "loading.preparing_next") : primaryActionLabel)
                }
                .font(.custom("Merriweather-Bold", size: 13))
                .foregroundColor(themeManager.buttonForegroundOnPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 22)
                .background(themeManager.primaryText)
                .cornerRadius(12)
            }
            .disabled(isProcessingPersonal)
            .padding(.top, 2)
        }
    }

    private var gatheringSummary: some View {
        VStack(spacing: 10) {
            gatheringCard(
                title: String(localized: "loading.from_cosmos"),
                iconName: "moon.stars.fill",
                rows: cosmosSummaryRows
            )

            gatheringCard(
                title: String(localized: "loading.from_environment"),
                iconName: "cloud.sun.fill",
                rows: environmentSummaryRows
            )

            gatheringCard(
                title: String(localized: "loading.from_within"),
                iconName: "person.fill",
                rows: personalSummaryRows
            )

            Text("loading.signals_privacy")
                .font(AlignaType.helperSmall())
                .foregroundColor(themeManager.descriptionText.opacity(0.82))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.horizontal, 12)

            HStack(spacing: 10) {
                Button {
                    handleNotNow()
                } label: {
                    Text("loading.not_now")
                        .font(.custom("Merriweather-Bold", size: 13))
                        .foregroundColor(themeManager.primaryText)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 18)
                        .background(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(themeManager.primaryText.opacity(0.18), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isGeneratingOverlayVisible)

                Button {
                    beginGenerationOverlay()
                } label: {
                    HStack(spacing: 8) {
                        if isGeneratingOverlayVisible {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(themeManager.buttonForegroundOnPrimary)
                                .scaleEffect(0.75)
                        }
                        Text(buttonTitleForGathering)
                    }
                    .font(.custom("Merriweather-Bold", size: 13))
                    .foregroundColor(themeManager.buttonForegroundOnPrimary)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity)
                    .background(themeManager.primaryText)
                    .cornerRadius(12)
                }
                .disabled(isGeneratingOverlayVisible)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private func compactRow(
        title: String,
        options: [(String, String)],
        selection: Binding<String?>
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Merriweather-Bold", size: 14))
                .foregroundColor(themeManager.primaryText.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 3) {
                ForEach(options, id: \.1) { option in
                    Button {
                        didInteractPersonal = true
                        if isProcessingPersonal {
                            isProcessingPersonal = false
                        }
                        selection.wrappedValue = option.1
                    } label: {
                        VStack(spacing: 4) {
                            iconView(option.0, size: 13)
                                .foregroundColor(themeManager.primaryText)
                            Text(localizedCheckInOptionLabel(option.1))
                                .font(.custom("Merriweather-Bold", size: 9))
                                .foregroundColor(themeManager.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selection.wrappedValue == option.1 ? themeManager.primaryText.opacity(0.14) : Color.white.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(themeManager.primaryText.opacity(0.22), lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var cosmicIcons: [String] { ["sun.max.fill", "moon.stars.fill", "sparkles", "sparkle"] }
    private var placeIcons: [String] { ["cloud.rain.fill", "wind", "cloud.fill", "water.waves", "tree.fill"] }
    private var personalIcons: [String] { ["person.circle", "person.circle.fill", "person.crop.circle", "person.crop.circle.fill", "person.2.circle"] }

    private var footerText: String? {
        switch stage {
        case .focusSelection:
            return nil
        case .initial:
            return nil
        case .cosmic:
            return String(localized: "loading.cosmic_footer")
        case .place:
            return String(localized: "loading.place_footer")
        case .personal:
            return nil
        case .gathering:
            return nil
        }
    }

    private var cosmicSubtitleView: some View {
        func clean(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "—" { return nil }
            return trimmed
        }

        let sun = clean(sunText).map { zodiacLocalizedName(for: $0) }
        let moon = clean(moonText).map { zodiacLocalizedName(for: $0) }
        let rising = clean(risingText).map { zodiacLocalizedName(for: $0) }
        let phaseName = localizedMoonPhaseLabel(for: Date()).trimmingCharacters(in: .whitespacesAndNewlines)

        let sunLine = sun.map { String(format: String(localized: "loading.sun_in"), $0) } ?? String(localized: "loading.sun_in_dash")
        let moonLine = moon.map { String(format: String(localized: "loading.moon_in"), $0) } ?? String(localized: "loading.moon_in_dash")
        let risingLine = rising.map { String(format: String(localized: "loading.rising_in"), $0) } ?? String(localized: "loading.rising_in_dash")
        let phaseLine = phaseName.isEmpty ? String(localized: "loading.moon_phase_dash") : String(format: String(localized: "loading.moon_phase_label"), phaseName)

        return VStack(spacing: 6) {
            Text(sunLine)
            Text(moonLine)
            Text(risingLine)
            Text(phaseLine)
        }
        .font(AlignaType.helperSmall())
        .foregroundColor(themeManager.descriptionText.opacity(0.85))
        .multilineTextAlignment(.center)
    }

    private var placeSubtitleView: some View {
        let location = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        let condition = conditionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let airQuality = airQualityText.trimmingCharacters(in: .whitespacesAndNewlines)
        let density = placeDensityText.trimmingCharacters(in: .whitespacesAndNewlines)

        let locationLine = location.isEmpty || location == "Your Current Location" ? String(localized: "loading.sensing_place") : "I'm sensing \(location)."
        let conditionLine = condition.isEmpty || condition == "Cloud · Wind · Rain" ? String(localized: "loading.sampling_air") : condition
        let airQualityLine = airQuality.isEmpty || airQuality == "Air quality —" ? String(localized: "loading.measuring_air_quality") : airQuality
        let densityLine = density.isEmpty ? "Water — · Green — · Built —" : density

        return VStack(spacing: 6) {
            Text(locationLine)
            Text(conditionLine)
            Text(airQualityLine)
            Text(densityLine)
        }
        .font(AlignaType.helperSmall())
        .foregroundColor(themeManager.descriptionText.opacity(0.85))
        .multilineTextAlignment(.center)
    }

    private var personalSubtitleText: Text {
        let text = isProcessingPersonal ? String(localized: "loading.personal_logged") : String(localized: "loading.personal_subtitle")
        return Text(text)
            .font(AlignaType.helperSmall())
            .foregroundColor(themeManager.descriptionText.opacity(0.85))
    }

    private var initialSubtitleText: Text {
        Text("loading.warming_up")
            .font(AlignaType.helperSmall())
    }

    private var placeSubtitle: String {
        func clean(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "Your Current Location" || trimmed == "Cloud · Wind · Rain" { return nil }
            return trimmed
        }

        let location  = clean(locationText)
        let condition = clean(conditionText)
        let airQuality = clean(airQualityText)
        let density = clean(placeDensityText)

        var lines: [String] = []
        if let location  { lines.append("I’m sensing \(location).") }
        if let condition { lines.append(condition) }
        if let airQuality { lines.append(airQuality) }
        if let density { lines.append(density) }

        if lines.isEmpty {
            return "I’m locating your place…\nI’m sampling today’s air…"
        }
        return lines.joined(separator: "\n")
    }

    private func scheduleStageProgression() {
        guard fixedMessageIndex == nil else { return }

        if !shouldRunFullLoading {
            shouldExpandMantraOnBoot = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onPersonalComplete?(false)
            }
            return
        }

        // If we start at focusSelection, stage timers begin AFTER the user
        // confirms their focus (triggered by advanceFromFocusSelection()).
        // So we only schedule here when skipping focus selection.
        if stage != .focusSelection {
            schedulePostFocusProgression()
        }
    }

    /// Schedules initial→cosmic→place→personal once past focus selection.
    private func schedulePostFocusProgression() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if stage == .initial { stage = .cosmic }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) {
            if stage == .cosmic { stage = .place }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.5) {
            if stage == .place { stage = .personal }
        }
    }

    /// Schedules cosmic→place→personal when skipping .initial (coming from focus selection).
    private func schedulePostCosmicProgression() {
        let item1 = DispatchWorkItem { if stage == .cosmic { stage = .place } }
        let item2 = DispatchWorkItem { if stage == .place  { stage = .personal } }
        cosmicPlaceWorkItem  = item1
        placePersonalWorkItem = item2
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: item1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: item2)
    }

    /// Called when user confirms focus selection; skips .initial and goes straight to .cosmic.
    private func advanceFromFocusSelection(focusID: String) {
        onFocusSelected?(focusID)
        if didAlreadyPassedStages {
            // Already went through cosmic/place — skip straight to personal
            withAnimation(.easeInOut(duration: 0.35)) { stage = .personal }
            loadPersonalSelections()
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { stage = .cosmic }
            schedulePostCosmicProgression()
        }
    }

    private func startEmojiTimers() {
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            cosmicEmojiIndex = (cosmicEmojiIndex + 1) % cosmicIcons.count
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            placeEmojiIndex = (placeEmojiIndex + 1) % placeIcons.count
        }
        Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { _ in
            personalIconIndex = (personalIconIndex + 1) % personalIcons.count
        }
    }

    private func startIconShake() {
        iconShakePhase = -1
        withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) {
            iconShakePhase = 1
        }
    }

    private func startDotTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dotPhase = (dotPhase + 1) % 3
        }
    }

    private func startIconFadeTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in
            iconVisible.toggle()
        }
    }

    private func fetchChartDataFromFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("chartData").document(uid).getDocument { snap, _ in
            guard let data = snap?.data(),
                  let chartData = data["chartData"] as? [String: Any] else { return }

            let sunRaw = (chartData["sun"] as? String ?? chartData["sunSign"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let moonRaw = (chartData["moon"] as? String ?? chartData["moonSign"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let risingRaw = (chartData["ascendant"] as? String ?? chartData["ascendantSign"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            func stripEmoji(_ text: String) -> String {
                let disallowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ").inverted
                let cleaned = text.components(separatedBy: disallowed).joined()
                return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let sun = stripEmoji(sunRaw)
            let moon = stripEmoji(moonRaw)
            let rising = stripEmoji(risingRaw)

            DispatchQueue.main.async {
                if !sun.isEmpty { sunText = sun }
                if !moon.isEmpty { moonText = moon }
                if !rising.isEmpty { risingText = rising }
                widgetSunSign = sun
                widgetMoonSign = moon
                widgetRisingSign = rising
            }
        }
    }

    private var dateStringForQuery: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private func normalizedSelection(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func syncPersonalSelectionsToViewModel() {
        viewModel.checkInMood = normalizedSelection(mood)
        viewModel.checkInStress = normalizedSelection(stress)
        viewModel.checkInSleep = normalizedSelection(sleep)
        viewModel.checkInNotes = personalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentCheckInPayload() -> [String: Any] {
        [
            "mood": normalizedSelection(mood) ?? "",
            "stress": normalizedSelection(stress) ?? "",
            "sleep": normalizedSelection(sleep) ?? "",
            "personal_notes": personalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }

    private func savePersonalSelections() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ds = dateStringForQuery
        let db = Firestore.firestore()

        syncPersonalSelectionsToViewModel()

        let payload: [String: Any] = [
            "mood": normalizedSelection(mood) ?? "",
            "stress": normalizedSelection(stress) ?? "",
            "sleep": normalizedSelection(sleep) ?? "",
            "personal_notes": personalNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            "updatedAt": Timestamp()
        ]

        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: uid)
            .whereField("createdAt", isEqualTo: ds)
            .limit(to: 1)
            .getDocuments { snapshot, _ in
                if let recDoc = snapshot?.documents.first {
                    recDoc.reference.setData([
                        "check_in_inputs": currentCheckInPayload(),
                        "updatedAt": Timestamp()
                    ], merge: true)

                    let recID = recDoc.documentID
                    let journalsRef = db.collection("daily_recommendation")
                        .document(recID)
                        .collection("journals")
                    journalsRef.order(by: "createdAt", descending: false)
                        .limit(to: 1)
                        .getDocuments { journSnap, _ in
                            if let journDoc = journSnap?.documents.first {
                                journalsRef.document(journDoc.documentID)
                                    .setData(payload, merge: true)
                            } else {
                                journalsRef.addDocument(data: payload.merging([
                                    "createdAt": Timestamp()
                                ]) { $1 })
                            }
                        }
                }
            }

        db.collection("users").document(uid)
            .collection("journals").document(ds)
            .setData(payload, merge: true)
    }

    private func loadPersonalSelections() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ds = dateStringForQuery
        let db = Firestore.firestore()

        func applySelections(from data: [String: Any]) {
            func nonEmptyString(_ key: String) -> String? {
                let raw = data[key] as? String ?? ""
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

            mood = nonEmptyString("mood")
            stress = nonEmptyString("stress")
            sleep = nonEmptyString("sleep")
            personalNotes = nonEmptyString("personal_notes") ?? nonEmptyString("text") ?? ""
            syncPersonalSelectionsToViewModel()
        }

        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: uid)
            .whereField("createdAt", isEqualTo: ds)
            .limit(to: 1)
            .getDocuments { snapshot, _ in
                if let recDoc = snapshot?.documents.first {
                    db.collection("daily_recommendation")
                        .document(recDoc.documentID)
                        .collection("journals")
                        .order(by: "createdAt", descending: false)
                        .limit(to: 1)
                        .getDocuments { journSnap, _ in
                            if let journDoc = journSnap?.documents.first {
                                DispatchQueue.main.async {
                                    applySelections(from: journDoc.data())
                                }
                            }
                        }
                } else {
                    db.collection("users").document(uid)
                        .collection("journals").document(ds)
                        .getDocument { doc, _ in
                            DispatchQueue.main.async {
                                applySelections(from: doc?.data() ?? [:])
                            }
                        }
                }
            }
    }

    private func scheduleAutoSkipIfNeeded() {
        // Auto-skip disabled — user must tap Continue manually
    }

    private var primaryActionLabel: String {
        return String(localized: "loading.continue")
    }

    private struct GatheringSegment: Hashable {
        let label: String
        let value: String
    }

    private var cosmosSummaryRows: [[GatheringSegment]] {
        [
            [
                GatheringSegment(label: String(localized: "loading.segment.sun"), value: summaryValue(zodiacLocalizedName(for: sunText), fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.moon"), value: summaryValue(zodiacLocalizedName(for: moonText), fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.rising"), value: summaryValue(zodiacLocalizedName(for: risingText), fallback: "—"))
            ],
            [
                GatheringSegment(label: String(localized: "loading.segment.moon_phase"), value: summaryValue(localizedMoonPhaseLabel(for: Date()), fallback: "—"))
            ]
        ]
    }

    private var environmentSummaryRows: [[GatheringSegment]] {
        [
            [
                GatheringSegment(label: String(localized: "loading.segment.location"), value: summaryValue(locationText, fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.weather"), value: summaryValue(compactWeatherSummaryValue, fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.wind"), value: summaryValue(compactWindSummaryValue, fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.air_quality"), value: summaryValue(compactAirQualityValue, fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.pm25"), value: summaryValue(compactPM25Value, fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.humidity"), value: summaryValue(compactHumidityValue, fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.pressure"), value: summaryValue(compactPressureValue, fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.water"), value: summaryValue(compactWaterValue, fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.green"), value: summaryValue(compactGreenValue, fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.built"), value: summaryValue(compactBuiltValue, fallback: "—"))
            ]
        ]
    }

    private var personalSummaryRows: [[GatheringSegment]] {
        var rows: [[GatheringSegment]] = [
            [
                GatheringSegment(label: String(localized: "loading.segment.mood"), value: summaryValue(normalizedSelection(mood), fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.stress"), value: summaryValue(normalizedSelection(stress), fallback: "—")),
                GatheringSegment(label: String(localized: "loading.segment.sleep"), value: summaryValue(normalizedSelection(sleep), fallback: "—"))
            ]
        ]

        let noteText = personalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !noteText.isEmpty {
            rows.append([
                GatheringSegment(label: String(localized: "loading.segment.notes"), value: String(noteText.prefix(72)))
            ])
        }
        return rows
    }

    private var compactConditionSummary: String {
        let isChinese = currentRecommendationLanguageCode() == "zh-Hans"
        let text = conditionText.replacingOccurrences(of: "\n", with: " · ").trimmingCharacters(in: .whitespacesAndNewlines)
        let isPlaceholder = text.isEmpty || text == "Cloud · Wind · Rain" || text == "云 · 风 · 雨"
        return isPlaceholder
            ? (isChinese ? "今日天气正在感知中。" : "Today's weather is taking shape.")
            : text
    }

    private var compactAirQualitySummary: String {
        let text = airQualityText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || text == "Air quality —" ? "Air quality is being sensed." : text
    }

    private var compactWeatherSummaryValue: String {
        compactConditionSummary
            .components(separatedBy: "·")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? compactConditionSummary
    }

    private var compactWindSummaryValue: String? {
        if let speed = placeWindSpeed {
            return "\(Int(speed.rounded())) mph"
        }
        return compactConditionSummary
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.contains("mph") })
            .map { segment in
                if let range = segment.range(of: #"(\d+)\s*mph"#, options: .regularExpression) {
                    return String(segment[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return segment.replacingOccurrences(of: "Wind dir", with: "")
                    .replacingOccurrences(of: "Wind", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
    }

    private var compactAirQualityValue: String {
        metricValue(in: compactAirQualitySummary, prefix: "Air quality")
            ?? compactAirQualitySummary
    }

    private var compactPM25Value: String? {
        metricValue(in: compactAirQualitySummary, prefix: "PM2.5")
    }

    private var compactHumidityValue: String? {
        metricValue(in: compactConditionSummary, prefix: "Humidity")
    }

    private var compactPressureValue: String? {
        metricValue(in: compactConditionSummary, prefix: "Pressure")
    }

    private var compactDensitySummary: String {
        let text = placeDensityText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || text == "Water — · Green — · Built —" ? "Landscape signals are being gathered." : text
    }

    private var compactWaterValue: String? {
        metricValue(in: compactDensitySummary, prefix: "Water")
    }

    private var compactGreenValue: String? {
        metricValue(in: compactDensitySummary, prefix: "Green")
    }

    private var compactBuiltValue: String? {
        metricValue(in: compactDensitySummary, prefix: "Built")
    }

    private func metricValue(in source: String, prefix: String) -> String? {
        source
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.localizedCaseInsensitiveContains(prefix) })
            .map { metric in
                metric.replacingOccurrences(of: prefix, with: "", options: [.caseInsensitive])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
    }

    private func summaryLine(_ text: String?, placeholder: String? = nil) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || trimmed == "—" {
            return placeholder
        }
        return trimmed
    }

    private func summaryValue(_ text: String?, fallback: String) -> String {
        summaryLine(text, placeholder: fallback) ?? fallback
    }

    private func gatheringCard(title: String, iconName: String, rows: [[GatheringSegment]]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.primaryText.opacity(0.88))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())

                Text(title)
                    .font(.custom("Merriweather-Bold", size: 14))
                    .foregroundColor(themeManager.primaryText)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(rows.prefix(3)).indices, id: \.self) { index in
                    summarySegmentsText(rows[index])
                        .foregroundColor(themeManager.descriptionText.opacity(0.9))
                        .lineLimit(3)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(themeManager.primaryText.opacity(0.14), lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal, 6)
    }

    private func summarySegmentsText(_ segments: [GatheringSegment]) -> Text {
        segments.enumerated().reduce(Text("")) { partial, entry in
            let separator = entry.offset == 0 ? Text("") : Text(" · ").font(.custom("Merriweather-Regular", size: 12))
            let segment = Text("\(entry.element.label) ")
                .font(.custom("Merriweather-Bold", size: 12))
            + Text(entry.element.value)
                .font(.custom("Merriweather-Regular", size: 12))
            return partial + separator + segment
        }
    }

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(themeManager.isNight ? 0.34 : 0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(themeManager.primaryText)
                    .opacity(iconVisible ? 1.0 : 0.45)
                    .scaleEffect(iconVisible ? 1.0 : 0.94)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: iconVisible)

                Text("loading.generating_mantra")
                    .font(.custom("Merriweather-Bold", size: 18))
                    .foregroundColor(themeManager.primaryText)

                Text("loading.weaving_signals")
                    .font(.custom("Merriweather-Regular", size: 12))
                    .foregroundColor(themeManager.descriptionText.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                loadingDots
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: 300)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(themeManager.panelFill.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(themeManager.panelStrokeHi.opacity(0.65), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
            .allowsHitTesting(true)
        }
        .transition(.opacity)
    }

    private func cancelAllStageWork() {
        cosmicPlaceWorkItem?.cancel();   cosmicPlaceWorkItem = nil
        placePersonalWorkItem?.cancel(); placePersonalWorkItem = nil
        autoSkipWorkItem?.cancel();      autoSkipWorkItem = nil
        autoSkipTimer?.invalidate()
        autoSkipSecondsRemaining = 0
    }

    private func continueToGathering() {
        guard stage == .personal else { return }
        autoSkipWorkItem?.cancel()
        autoSkipTimer?.invalidate()
        autoSkipSecondsRemaining = 0
        isProcessingPersonal = false
        withAnimation(.easeInOut(duration: 0.3)) {
            stage = .gathering
        }
    }

    private func handleNotNow() {
        // 用户主动跳过，明确不生成
        showMainGenerationOverlay = false
        completePersonal()
    }

    private func beginGenerationOverlay() {
        guard !isGeneratingOverlayVisible else { return }
        if shouldGenerateTodayReading {
            isGeneratingOverlayVisible = true
            showMainGenerationOverlay = true
        } else {
            isGeneratingOverlayVisible = false
            showMainGenerationOverlay = false
        }
        completePersonal()
    }

    private var buttonTitleForGathering: String {
        if isGeneratingOverlayVisible {
            return String(localized: "loading.generating_mantra_now")
        }
        return shouldGenerateTodayReading ? String(localized: "loading.generate_mantra") : String(localized: "loading.see_mantra")
    }

    private func fetchPlaceAndWeather(for coord: CLLocationCoordinate2D) {
        guard !didFetchPlaceSignals else { return }
        didFetchPlaceSignals = true

        // Reverse geocode → locationText + viewModel.currentPlace
        getAddressFromCoordinate(coord) { name in
            if let name {
                DispatchQueue.main.async {
                    locationText = name
                    widgetLocationName = name
                    viewModel.currentPlace = name
                }
            }
            // Sync GPS coordinate to user profile if it differs from stored location
            syncLocationToProfile(coord: coord, placeName: name ?? "")
        }

        // Weather via Open-Meteo (no API key) — fetch structured fields
        let fields = "temperature_2m,weathercode,wind_speed_10m,wind_direction_10m,relative_humidity_2m,surface_pressure"
        let urlStr = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(coord.latitude)&longitude=\(coord.longitude)"
            + "&current=\(fields)"
            + "&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto"
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any] else { return }

            let code  = current["weathercode"] as? Int ?? 0
            let temp  = current["temperature_2m"] as? Double
            let wspd  = current["wind_speed_10m"] as? Double
            let wdeg  = current["wind_direction_10m"] as? Double
            let rhum  = current["relative_humidity_2m"] as? Double
            let pres  = current["surface_pressure"] as? Double

            let description   = placeWeatherDescription(for: code)    // 英文，用于后台 payload
            let descriptionZH = placeWeatherDescriptionZH(for: code)  // 中文，用于界面显示
            let windDir       = wdeg.map { windCompassDirection(degrees: $0) }

            // Build display strings (language-aware)
            let isChinese = currentRecommendationLanguageCode() == "zh-Hans"
            let displayDescription = isChinese ? descriptionZH : description
            let tempStr = temp.map { "\(Int($0.rounded()))°F" } ?? ""
            let dirText = wdeg.map { windDirectionText(for: $0) } ?? ""
            let windText = isChinese
                ? "风向 \(dirText) · \(Int((wspd ?? 0).rounded())) mph"
                : "Wind dir \(dirText) · \(Int((wspd ?? 0).rounded())) mph"
            let humidityText = isChinese
                ? "湿度 \(Int((rhum ?? 0).rounded()))%"
                : "Humidity \(Int((rhum ?? 0).rounded()))%"
            let pressureText = isChinese
                ? "气压 \(Int((pres ?? 0).rounded())) hPa"
                : "Pressure \(Int((pres ?? 0).rounded())) hPa"
            let text = "\(displayDescription) · \(tempStr)\n\(windText)\n\(humidityText) · \(pressureText)"

            // Widget-compact summaries (only when all required values are available)
            let widgetSummary: String? = temp.flatMap { t in wspd.map { w in
                compactWeatherSummary(description: description, temperature: t, windSpeed: w)
            }}
            let widgetDetailSummary: String? = wspd.flatMap { w in rhum.flatMap { h in pres.map { p in
                compactWeatherDetailSummary(windSpeed: w, humidity: h, pressure: p)
            }}}

            DispatchQueue.main.async {
                conditionText = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? (isChinese ? "云 · 风 · 雨" : "Cloud · Wind · Rain") : text
                if let ws = widgetSummary       { widgetWeatherSummary = ws }
                if let wd = widgetDetailSummary { widgetWeatherDetailSummary = wd }
                placeTemperature   = temp
                placeWindDirection = windDir
                placeWindSpeed     = wspd
                placeHumidity      = rhum
                placePressure      = pres

                // Persist into viewModel — 中文版用于界面显示，英文版（description）用于 API payload
                viewModel.weatherCondition = descriptionZH.isEmpty ? nil : descriptionZH
                viewModel.temperature      = temp
                viewModel.windDirection    = windDir
                viewModel.windSpeed        = wspd
                viewModel.humidity         = rhum
                viewModel.pressure         = pres

                print("[PlaceSignals] place=\(viewModel.currentPlace) condition=\(description) temp=\(temp.map { String($0) } ?? "nil")°F wind=\(windDir ?? "nil") @\(wspd.map { String($0) } ?? "nil")mph humidity=\(rhum.map { String($0) } ?? "nil")% pressure=\(pres.map { String($0) } ?? "nil")hPa")
            }
        }.resume()

        // Air quality via Open-Meteo (AQI + PM2.5)
        fetchAirQuality(for: coord)

        // Land cover density (approx) via WorldCover WMS RGB sampling
        fetchLandCoverDensity(for: coord)
    }

    /// Compares the current GPS coordinate with the profile-stored location.
    /// If they differ by more than ~500 m, updates currentPlace / currentLat / currentLng in Firestore.
    private func syncLocationToProfile(coord: CLLocationCoordinate2D, placeName: String) {
        guard !placeName.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let candidateCollections = ["user", "users"]
        let freshLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)

        // Query both collections for the user document
        func tryCollection(_ collections: [String]) {
            guard let col = collections.first else { return }
            let rest = Array(collections.dropFirst())

            db.collection(col)
                .whereField("uid", isEqualTo: uid)
                .limit(to: 1)
                .getDocuments { snapshot, _ in
                    if let doc = snapshot?.documents.first {
                        let data = doc.data()
                        let storedLat = data["currentLat"] as? CLLocationDegrees
                        let storedLng = data["currentLng"] as? CLLocationDegrees

                        // If no stored coordinate, always write; otherwise compare distance
                        var shouldUpdate = true
                        if let lat = storedLat, let lng = storedLng {
                            let storedLocation = CLLocation(latitude: lat, longitude: lng)
                            shouldUpdate = freshLocation.distance(from: storedLocation) > 500
                        }

                        if shouldUpdate {
                            let payload: [String: Any] = [
                                "currentPlace": placeName,
                                "currentLat": coord.latitude,
                                "currentLng": coord.longitude,
                                "updatedAt": FieldValue.serverTimestamp()
                            ]
                            db.collection(col).document(doc.documentID)
                                .setData(payload, merge: true) { err in
                                    if let err = err {
                                        print("[LocationSync] Firestore write failed: \(err.localizedDescription)")
                                    } else {
                                        print("[LocationSync] Updated profile location to \(placeName) (\(coord.latitude), \(coord.longitude)) in '\(col)'")
                                    }
                                }
                        } else {
                            print("[LocationSync] Location unchanged (<500m), no update needed")
                        }
                    } else if !rest.isEmpty {
                        tryCollection(rest)
                    }
                    // If not found in any collection, silently skip
                }
        }

        tryCollection(candidateCollections)
    }

    private enum LandCoverCategory {
        case water
        case green
        case built
        case other
    }

    private struct LandCoverColor {
        let r: Int
        let g: Int
        let b: Int
        let category: LandCoverCategory
    }

    private func fetchAirQuality(for coord: CLLocationCoordinate2D) {
        let urlStr = "https://air-quality-api.open-meteo.com/v1/air-quality"
            + "?latitude=\(coord.latitude)&longitude=\(coord.longitude)"
            + "&current=us_aqi,pm2_5&timezone=auto"
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any] else { return }

            let aqiValue = current["us_aqi"] as? Double
            let pmValue = current["pm2_5"] as? Double

            let aqiInt = aqiValue.map { Int($0.rounded()) }
            let aqiText = aqiInt.map { "AQI \($0)" }
            let pmText = pmValue.map { "PM2.5 \(Int($0.rounded()))" }

            let combined: String
            if let aqiText, let pmText {
                combined = "Air quality \(aqiText) · \(pmText)"
            } else if let aqiText {
                combined = "Air quality \(aqiText)"
            } else if let pmText {
                combined = "Air quality \(pmText)"
            } else {
                return
            }

            let readable: String
            if let aqi = aqiInt {
                let label = airQualityLabel(for: aqi)
                readable = "Air Quality: \(label)"
            } else if let pmText {
                readable = "Air Quality: \(pmText)"
            } else {
                readable = combined
            }

            DispatchQueue.main.async {
                airQualityText = combined
                widgetAirQualityText = readable
                viewModel.airQualityAQI = aqiValue
                viewModel.airQualityPM25 = pmValue
            }
        }.resume()
    }

    private func airQualityLabel(for aqi: Int) -> String {
        switch aqi {
        case ..<51: return "Good"
        case 51..<101: return "Moderate"
        case 101..<151: return "Unhealthy for Sensitive"
        case 151..<201: return "Unhealthy"
        case 201..<301: return "Very Unhealthy"
        default: return "Hazardous"
        }
    }

    private func fetchLandCoverDensity(for coord: CLLocationCoordinate2D) {
        Task {
            let text = await computeLandCoverDensity(for: coord)
            let widgetSummary = compactEnvironmentSummary(from: text)
            DispatchQueue.main.async {
                placeDensityText = text
                widgetEnvironmentSummary = widgetSummary
            }
        }
    }

    private func computeLandCoverDensity(for coord: CLLocationCoordinate2D) async -> String {
        let samples = sampleGridCoordinates(center: coord, radiusMeters: 500, gridCount: 5)
        var waterCount = 0
        var greenCount = 0
        var builtCount = 0
        var totalCount = 0

        await withTaskGroup(of: LandCoverCategory?.self) { group in
            for sample in samples {
                group.addTask {
                    await fetchLandCoverClass(at: sample)
                }
            }

            for await result in group {
                guard let category = result else { continue }
                totalCount += 1
                switch category {
                case .water:
                    waterCount += 1
                case .green:
                    greenCount += 1
                case .built:
                    builtCount += 1
                case .other:
                    break
                }
            }
        }

        guard totalCount > 0 else { return "Water — · Green — · Built —" }

        let waterPct = Int((Double(waterCount) / Double(totalCount) * 100).rounded())
        let greenPct = Int((Double(greenCount) / Double(totalCount) * 100).rounded())
        let builtPct = Int((Double(builtCount) / Double(totalCount) * 100).rounded())

        return "Water \(waterPct)% · Green \(greenPct)% · Built \(builtPct)%"
    }

    private func compactWeatherSummary(
        description: String,
        temperature: Double,
        windSpeed: Double
    ) -> String {
        let zh = currentRecommendationLanguageCode() == "zh-Hans"

        let tempTone: String
        switch temperature {
        case ..<45: tempTone = zh ? "寒冷" : "Cold"
        case ..<60: tempTone = zh ? "凉爽" : "Cool"
        case ..<75: tempTone = zh ? "温和" : "Mild"
        case ..<86: tempTone = zh ? "温暖" : "Warm"
        default:    tempTone = zh ? "炎热" : "Hot"
        }

        // Match against English weather codes (description is always the API English value)
        let lowered = description.lowercased()
        let skyTone: String
        if lowered.contains("thunder") {
            skyTone = zh ? "有雷暴" : "stormy"
        } else if lowered.contains("snow") {
            skyTone = zh ? "有雪" : "snowy"
        } else if lowered.contains("rain") || lowered.contains("drizzle") || lowered.contains("shower") {
            skyTone = zh ? "有雨" : "rainy"
        } else if lowered.contains("fog") || lowered.contains("mist") {
            skyTone = zh ? "有雾" : "misty"
        } else if lowered.contains("cloud") || lowered.contains("overcast") {
            skyTone = zh ? "多云" : "cloudy"
        } else {
            skyTone = zh ? "晴朗" : "clear"
        }

        if windSpeed >= 18 {
            return zh ? "\(tempTone)多风" : "\(tempTone) and windy"
        }
        return zh ? "\(tempTone)\(skyTone)" : "\(tempTone), \(skyTone)"
    }

    private func compactWeatherDetailSummary(
        windSpeed: Double,
        humidity: Double,
        pressure: Double
    ) -> String {
        let zh = currentRecommendationLanguageCode() == "zh-Hans"

        let windLabel: String
        switch windSpeed {
        case ..<3:  windLabel = zh ? "静风" : "Calm"
        case ..<8:  windLabel = zh ? "微风" : "Light"
        case ..<15: windLabel = zh ? "清风" : "Breezy"
        case ..<22: windLabel = zh ? "有风" : "Windy"
        case ..<30: windLabel = zh ? "大风" : "Blustery"
        default:    windLabel = zh ? "阵风" : "Gusty"
        }

        let humidityLabel: String
        switch humidity {
        case ..<30: humidityLabel = zh ? "干燥" : "Dry"
        case ..<45: humidityLabel = zh ? "舒适" : "Comfortable"
        case ..<60: humidityLabel = zh ? "适中" : "Balanced"
        case ..<75: humidityLabel = zh ? "潮湿" : "Humid"
        default:    humidityLabel = zh ? "闷热" : "Muggy"
        }

        let pressureLabel: String
        switch pressure {
        case ..<1005: pressureLabel = zh ? "低压" : "Heavy"
        case ..<1019: pressureLabel = zh ? "适中" : "Balanced"
        default:      pressureLabel = zh ? "高压" : "Crisp"
        }

        return zh
            ? "风况 \(windLabel) · 湿度 \(humidityLabel) · 气压 \(pressureLabel)"
            : "Wind \(windLabel) · Humidity \(humidityLabel) · Pressure \(pressureLabel)"
    }

    private func compactEnvironmentSummary(from density: String) -> String {
        let pattern = #"Water\s+(\d+)%\s+·\s+Green\s+(\d+)%\s+·\s+Built\s+(\d+)%"#
        let zh = currentRecommendationLanguageCode() == "zh-Hans"
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: density,
                range: NSRange(density.startIndex..., in: density)
            ),
            match.numberOfRanges == 4,
            let waterRange = Range(match.range(at: 1), in: density),
            let greenRange = Range(match.range(at: 2), in: density),
            let builtRange = Range(match.range(at: 3), in: density),
            let water = Int(density[waterRange]),
            let green = Int(density[greenRange]),
            let built = Int(density[builtRange])
        else {
            return zh ? "正在感知周围环境" : "Sensing your surroundings"
        }

        if green >= max(water, built) + 15 {
            if water >= 25 { return zh ? "绿色为主，水岸相映" : "Mostly green, touched by water" }
            if built >= 25 { return zh ? "绿色为主，都市轻触" : "Mostly green with quiet urban edges" }
            return zh ? "绿意深厚，安静自然" : "Mostly green and softly grounded"
        }

        if built >= max(green, water) + 15 {
            if green >= 20 { return zh ? "城市为主，绿意点缀" : "Mostly built with pockets of green" }
            if water >= 20 { return zh ? "城市为主，水岸相邻" : "Mostly built, edged by water" }
            return zh ? "城市地带，人工主导" : "Mostly built and city-held"
        }

        if water >= max(green, built) + 15 {
            if green >= 20 { return zh ? "水岸主导，绿意柔化" : "Water-led, softened by green" }
            if built >= 20 { return zh ? "水岸主导，都市相邻" : "Water-led with urban edges" }
            return zh ? "水域辽阔，空旷开放" : "Mostly water and open space"
        }

        if green >= 30 && built >= 30 { return zh ? "绿色与城市均衡交织" : "Balanced between green and city" }
        if green >= 25 && water >= 20 { return zh ? "绿色与水域均衡相融" : "Balanced between green and water" }
        return zh ? "多元环境，轻柔均衡" : "Mixed surroundings, gently balanced"
    }

    private func sampleGridCoordinates(
        center: CLLocationCoordinate2D,
        radiusMeters: Double,
        gridCount: Int
    ) -> [CLLocationCoordinate2D] {
        let offsets = Array(0..<gridCount).map { idx -> Double in
            let step = radiusMeters / Double(gridCount - 1)
            return (-radiusMeters) + Double(idx) * step
        }

        let latScale = 1.0 / 111_320.0
        let lonScale = 1.0 / (111_320.0 * max(0.1, cos(center.latitude * .pi / 180)))

        var points: [CLLocationCoordinate2D] = []
        for dy in offsets {
            for dx in offsets {
                let lat = center.latitude + dy * latScale
                let lon = center.longitude + dx * lonScale
                points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
        return points
    }

    private func fetchLandCoverClass(at coord: CLLocationCoordinate2D) async -> LandCoverCategory? {
        let zoom = 14
        guard let tile = tileInfo(for: coord, zoom: zoom) else { return nil }

        var components = URLComponents(string: "https://services.terrascope.be/wmts/v2")
        components?.queryItems = [
            URLQueryItem(name: "layer", value: "WORLDCOVER_2020_MAP"),
            URLQueryItem(name: "style", value: ""),
            URLQueryItem(name: "tilematrixset", value: "EPSG:3857"),
            URLQueryItem(name: "Service", value: "WMTS"),
            URLQueryItem(name: "Request", value: "GetTile"),
            URLQueryItem(name: "Version", value: "1.0.0"),
            URLQueryItem(name: "Format", value: "image/png"),
            URLQueryItem(name: "TileMatrix", value: "EPSG:3857:\(zoom)"),
            URLQueryItem(name: "TileCol", value: "\(tile.x)"),
            URLQueryItem(name: "TileRow", value: "\(tile.y)"),
        ]

        guard let url = components?.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let rgb = rgbFromImageData(data, x: tile.pixelX, y: tile.pixelY) else { return nil }
            return categoryForRGB(rgb)
        } catch {
            return nil
        }
    }

    private struct TileInfo {
        let x: Int
        let y: Int
        let pixelX: Int
        let pixelY: Int
    }

    private func tileInfo(for coord: CLLocationCoordinate2D, zoom: Int) -> TileInfo? {
        let lat = min(max(coord.latitude, -85.05112878), 85.05112878)
        let lon = coord.longitude
        let n = pow(2.0, Double(zoom))

        let xFloat = (lon + 180.0) / 360.0 * n
        let latRad = lat * .pi / 180.0
        let yFloat = (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * n

        let xTile = Int(floor(xFloat))
        let yTile = Int(floor(yFloat))
        guard xTile >= 0, yTile >= 0 else { return nil }

        let pixelX = Int(((xFloat - floor(xFloat)) * 256.0).rounded())
        let pixelY = Int(((yFloat - floor(yFloat)) * 256.0).rounded())

        return TileInfo(x: xTile, y: yTile, pixelX: min(max(pixelX, 0), 255), pixelY: min(max(pixelY, 0), 255))
    }

    private func rgbFromImageData(_ data: Data, x: Int, y: Int) -> (Int, Int, Int)? {
        guard let image = UIImage(data: data)?.cgImage else { return nil }
        guard let dataProvider = image.dataProvider,
              let providerData = dataProvider.data else { return nil }
        let bytes = CFDataGetBytePtr(providerData)
        let bytesPerPixel = 4
        let bytesPerRow = image.bytesPerRow
        let offset = y * bytesPerRow + x * bytesPerPixel
        guard offset + 2 < CFDataGetLength(providerData) else { return nil }
        return (Int(bytes?[offset] ?? 0), Int(bytes?[offset + 1] ?? 0), Int(bytes?[offset + 2] ?? 0))
    }

    private func categoryForRGB(_ rgb: (Int, Int, Int)) -> LandCoverCategory {
        let legend: [LandCoverColor] = [
            LandCoverColor(r: 0, g: 100, b: 200, category: .water),      // 80 Permanent water bodies
            LandCoverColor(r: 0, g: 100, b: 0, category: .green),         // 10 Tree cover
            LandCoverColor(r: 255, g: 187, b: 34, category: .green),      // 20 Shrubland
            LandCoverColor(r: 255, g: 255, b: 76, category: .green),      // 30 Grassland
            LandCoverColor(r: 240, g: 150, b: 255, category: .green),     // 40 Cropland
            LandCoverColor(r: 0, g: 150, b: 160, category: .green),       // 90 Herbaceous wetland
            LandCoverColor(r: 0, g: 207, b: 117, category: .green),       // 95 Mangroves
            LandCoverColor(r: 250, g: 0, b: 0, category: .built)          // 50 Built-up
        ]

        var bestDistance = Int.max
        var bestCategory: LandCoverCategory = .other
        for color in legend {
            let dr = rgb.0 - color.r
            let dg = rgb.1 - color.g
            let db = rgb.2 - color.b
            let dist = dr * dr + dg * dg + db * db
            if dist < bestDistance {
                bestDistance = dist
                bestCategory = color.category
            }
        }

        return bestDistance <= 900 ? bestCategory : .other
    }

    /// Convert wind-direction degrees (0–360) to 8-point compass string.
    private func windCompassDirection(degrees: Double) -> String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees / 45.0).rounded()) % 8
        return dirs[index]
    }

    private func placeWeatherDescription(for code: Int) -> String {
        switch code {
        case 0:       return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48:  return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Showers"
        case 95:      return "Thunderstorm"
        default:      return "Mixed conditions"
        }
    }

    private func placeWeatherDescriptionZH(for code: Int) -> String {
        let key: String
        switch code {
        case 0:       key = "weather.clear"
        case 1:       key = "weather.mostly_clear"
        case 2:       key = "weather.partly_cloudy"
        case 3:       key = "weather.cloudy"
        case 45, 48:  key = "weather.foggy"
        case 51, 53:  key = "weather.light_drizzle"
        case 55:      key = "weather.drizzle"
        case 61:      key = "weather.light_rain"
        case 63:      key = "weather.moderate_rain"
        case 65:      key = "weather.heavy_rain"
        case 71:      key = "weather.light_snow"
        case 73:      key = "weather.moderate_snow"
        case 75:      key = "weather.heavy_snow"
        case 80:      key = "weather.showers"
        case 81:      key = "weather.moderate_showers"
        case 82:      key = "weather.heavy_showers"
        case 95:      key = "weather.thunderstorm"
        default:      key = "weather.mixed"
        }
        return String(localized: String.LocalizationValue(key))
    }

    private func windDirectionText(for degrees: Double) -> String {
        let directions = [
            "N", "NNE", "NE", "ENE",
            "E", "ESE", "SE", "SSE",
            "S", "SSW", "SW", "WSW",
            "W", "WNW", "NW", "NNW"
        ]
        let index = Int((degrees + 11.25) / 22.5) % directions.count
        return directions[index]
    }

    private func completePersonal() {
        guard !personalCompleted else { return }
        autoSkipWorkItem?.cancel()
        autoSkipTimer?.invalidate()
        autoSkipSecondsRemaining = 0
        personalCompleted = true
        syncPersonalSelectionsToViewModel()

        let didModify = didInteractPersonal
        if didModify {
            savePersonalSelections()
        }
        onPersonalComplete?(didModify)
    }
}


#if DEBUG
private extension LoadingView {
    init(previewStage: LoadingStage) {
        self.init(onStartLoading: nil, onPersonalComplete: nil, fixedMessageIndex: 0, forceFullLoading: true)
        _stage = State(initialValue: previewStage)
        if previewStage == .personal {
            _autoSkipSecondsRemaining = State(initialValue: 3)
        }
    }

    init(previewGatheringSeeded: Bool) {
        self.init(onStartLoading: nil, onPersonalComplete: nil, fixedMessageIndex: 0, forceFullLoading: true)
        _stage = State(initialValue: .gathering)
        _sunText = State(initialValue: "Virgo")
        _moonText = State(initialValue: "Pisces")
        _risingText = State(initialValue: "Libra")
        _locationText = State(initialValue: "Brooklyn")
        _conditionText = State(initialValue: "Cool, rainy · 61°F")
        _airQualityText = State(initialValue: "Air quality AQI 42 · PM2.5 9")
        _placeDensityText = State(initialValue: "Water 18% · Green 41% · Built 36%")
        _mood = State(initialValue: "Calm")
        _stress = State(initialValue: "Med")
        _sleep = State(initialValue: "OK")
        _source = State(initialValue: "Work")
        _personalNotes = State(initialValue: "Need steadier pacing and less noise today.")
        _didInteractPersonal = State(initialValue: true)
    }
}

private struct LoadingViewPreviewContainer: View {
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager
    let isNight: Bool
    let stage: LoadingView.LoadingStage

    init(isNight: Bool = false, stage: LoadingView.LoadingStage) {
        self.isNight = isNight
        self.stage = stage
        let themeManager = ThemeManager()
        themeManager.selected = isNight ? .night : .day
        _themeManager = StateObject(wrappedValue: themeManager)
    }

    var body: some View {
        LoadingView(previewStage: stage)
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Loading Cosmic") {
    LoadingViewPreviewContainer(stage: .cosmic)
}

#Preview("Loading Initial") {
    LoadingViewPreviewContainer(stage: .initial)
}

#Preview("Loading Place") {
    LoadingViewPreviewContainer(stage: .place)
}

#Preview("Loading Personal") {
    LoadingViewPreviewContainer(stage: .personal)
}

#Preview("Loading Gathering") {
    LoadingViewPreviewContainer(stage: .gathering)
}

#Preview("Loading Gathering Filled") {
    LoadingView(previewGatheringSeeded: true)
        .environmentObject(StarAnimationManager())
        .environmentObject({
            let manager = ThemeManager()
            manager.selected = .day
            return manager
        }())
}

#Preview("Loading Night") {
    LoadingViewPreviewContainer(isNight: true, stage: .cosmic)
}
#endif
