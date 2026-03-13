import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit

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
    static func expandedMantraBoldItalic() -> Font { .custom("Merriweather-Bold", size: 28) }

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
    
    @EnvironmentObject var reasoningStore: DailyReasoningStore
    
    @AppStorage("lastRecommendationDate") var lastRecommendationDate: String = ""
    @AppStorage("lastRecommendationPlace") var lastRecommendationPlace: String = ""   // ✅ NEW
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("lastCurrentPlaceUpdate") var lastCurrentPlaceUpdate: String = ""
    @AppStorage("todayFetchLock") private var todayFetchLock: String = ""
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @State private var isFetchingToday: Bool = false
    
    @State private var isMantraExpanded: Bool = false
    
    @State private var showReasoningBubble: Bool = false

    @AppStorage("todayAutoRefetchDone") private var todayAutoRefetchDone: String = ""

    @State private var autoRefetchScheduled = false

    @State private var authListenerHandle: AuthStateDidChangeListenerHandle? = nil
    @State private var authWaitTimedOut = false

    @AppStorage("watchdogDay") private var watchdogDay: String = ""
    @AppStorage("todayAutoRefetchAttempts") private var todayAutoRefetchAttempts: Int = 0

    // NEW: 多次重试的配置
    private let maxRefetchAttempts = 3
    private let initialRefetchDelay: TimeInterval = 8.0

    @StateObject private var locationManager = LocationManager()
    @State private var recommendationTitles: [String: String] = [:]
    
    @State private var selectedDate = Date()
    
    @State private var bootPhase: BootPhase = .loading
    @State private var splashLocation: String = "Your Current Location"
    @State private var splashZodiac: String = ""
    @State private var splashMoon: String = ""
    
    @State private var didBootVisuals = false
    @State private var alynnaFrame: CGRect = .zero

    
    private func ensureDefaultsIfMissing() {
        // If nothing loaded yet, supply local demo content
        if viewModel.recommendations.isEmpty {
            viewModel.recommendations = DesignRecs.docs
            viewModel.dailyMantra = viewModel.dailyMantra.isEmpty ? DesignRecs.mantra : viewModel.dailyMantra
        }
        // If we don’t have human-facing titles yet, use local titles
        if recommendationTitles.isEmpty {
            recommendationTitles = DesignRecs.titles
        }
    }
    
    private struct AlynnaFrameKey: PreferenceKey {
        static var defaultValue: CGRect = .zero
        static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
            value = nextValue()
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

    
    private var mainContent: some View {
        NavigationStack {
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
                                // Timeline / calendar
                                NavigationLink(
                                    destination: ContentView()
                                        .environmentObject(starManager)
                                        .environmentObject(themeManager)
                                        .environmentObject(viewModel)
                                ) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20))
                                        .foregroundColor(themeManager.foregroundColor)
                                        .frame(width: 28, height: 28)
                                }

                                // Journal button – book icon
                                NavigationLink(
                                    destination: JournalView(date: selectedDate)
                                        .environmentObject(starManager)
                                        .environmentObject(themeManager)
                                ) {
                                    Image(systemName: "book.closed")      // ⬅️ journal symbol
                                        .font(.system(size: 20))
                                        .foregroundColor(themeManager.foregroundColor)
                                        .frame(width: 28, height: 28)
                                }
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
                                            .foregroundColor(themeManager.foregroundColor)
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
                                            .foregroundColor(themeManager.foregroundColor)
                                    }
                                }
                            }
                            .padding(.trailing, geometry.size.width * 0.05)

                        }

                        // ✅ 只保留按钮本身（气泡放到全局 overlay）
                        Button {
                            if viewModel.reasoningSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                debugAndRefreshReasoningSummaryFromFirestore()
                            }

                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                showReasoningBubble.toggle()
                            }
                        } label: {
                            Text("Alynna")
                                .font(AlignaType.logo())
                                .lineSpacing(AlignaType.logoLineSpacing)
                                .foregroundColor(themeManager.foregroundColor)
                                .padding(.top, 20)
                                // ✅ 把 Alynna 的真实位置传出去（在 GeometryReader 的坐标系里）
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: AlynnaFrameKey.self,
                                            value: proxy.frame(in: .named("HomeSpace"))
                                        )
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                        .onPreferenceChange(AlynnaFrameKey.self) { alynnaFrame = $0 }
                        .opacity(isMantraExpanded ? 0 : 1)
                        .scaleEffect(isMantraExpanded ? 0.92 : 1)
                        .frame(height: isMantraExpanded ? 0 : nil)
                        .allowsHitTesting(!isMantraExpanded)




                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isMantraExpanded.toggle()
                            }
                        } label: {
                            Text(viewModel.dailyMantra)
                                .font(
                                    isMantraExpanded
                                    ? AlignaType.expandedMantraBoldItalic()
                                    : AlignaType.homeSubtitle()
                                )
                                .lineSpacing(isMantraExpanded ? 12 : AlignaType.descLineSpacing)
                                .multilineTextAlignment(.center)
                                .foregroundColor(
                                    isMantraExpanded
                                    ? themeManager.primaryText.opacity(themeManager.isNight ? 0.94 : 0.88)
                                    : themeManager.foregroundColor.opacity(0.7)
                                )
                                .padding(.horizontal, isMantraExpanded ? geometry.size.width * 0.14 : geometry.size.width * 0.1)
                                .padding(.top, isMantraExpanded ? geometry.size.height * 0.16 : 0)
                                .lineLimit(isMantraExpanded ? nil : 2)     // ✅ 折叠：最多 1 行
                                .truncationMode(.tail)                    // ✅ 超出：显示 "..."
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: isMantraExpanded ? .infinity : nil, alignment: isMantraExpanded ? .top : .center)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        // ✅ 当 mantra 更新（新的一天/重新拉取）时，自动收起回 “...”
                        .onChange(of: viewModel.dailyMantra) {
                            isMantraExpanded = false
                        }

                        if !isMantraExpanded {
                            Spacer()

                            VStack(spacing: minLength * 0.05) {
                                let columns = [
                                    GridItem(.flexible(), alignment: .center),
                                    GridItem(.flexible(), alignment: .center)
                                ]

                                LazyVGrid(columns: columns,
                                          spacing: geometry.size.height * 0.023) {
                                    navItemView(title: "Place", geometry: geometry)
                                    navItemView(title: "Gemstone", geometry: geometry)
                                    navItemView(title: "Color", geometry: geometry)
                                    navItemView(title: "Scent", geometry: geometry)
                                    navItemView(title: "Activity", geometry: geometry)
                                    navItemView(title: "Sound", geometry: geometry)
                                    navItemView(title: "Career", geometry: geometry)
                                    navItemView(title: "Relationship", geometry: geometry)
                                }
                                .padding(.horizontal, geometry.size.width * 0.05)
                            }

                            // ✅ 给底部说明文字留出空间
                            Spacer().frame(height: geometry.size.height * 0.11)
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
                    }
                    .coordinateSpace(name: "HomeSpace")
                    .overlay(alignment: .topLeading) {
                        if showReasoningBubble {

                            // ✅ （推荐）透明遮罩：点空白处关闭
                            Color.black.opacity(0.001)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                        showReasoningBubble = false
                                    }
                                }
                                .zIndex(99998)

                            ReasoningBubbleView(
                                text: viewModel.reasoningSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "No reasoning summary available yet."
                                    : viewModel.reasoningSummary,
                                textColor: themeManager.foregroundColor.opacity(0.92)
                            ) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    showReasoningBubble = false
                                }
                            }
                            // ✅ 精准定位：紧贴在 Alynna 标志正下方
                            .frame(maxWidth: 320, alignment: .center)
                            .position(
                                x: alynnaFrame.midX,
                                y: alynnaFrame.maxY + 14   // ⭐️ 距离 Alynna 底部的间距，可微调 10~18
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .zIndex(99999)
                        }
                    }
                }
            }
            // ✅ 只作用在首页这个 ZStack 上，push 新页面后不会带过去
            .safeAreaInset(edge: .bottom) {
                (
                    Text("The daily rhythms above are derived from integrated modeling of Earth observation, climate, air-quality, physiological, and astrological data, ")
                    + Text("\(updatedOnFooterText).").bold()
                )
                .font(.system(size: 10))
                .multilineTextAlignment(.center)
                .foregroundColor(themeManager.foregroundColor.opacity(0.28))
                .padding(.horizontal, 24)
                .padding(.bottom, 0)
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

    
    // 冷启动只看“是否已登录 + 本地标记”来分流；不再在这里查 Firestore 决定是否强拉 Onboarding。
    // === 替换你原来的 startInitialLoad()（整段替换） ===
    private func startInitialLoad() {
        
        
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
            // 已有用户（或超时标记未触发）：按你原来的分流逻辑走
            // A) 未登录
            if user.uid.isEmpty {
                shouldOnboardAfterSignIn = false
                hasCompletedOnboarding = false
                withAnimation(.easeInOut) { bootPhase = .onboarding }
                return
            }
            // B) 刚注册需要走引导
            if shouldOnboardAfterSignIn && !hasCompletedOnboarding {
                withAnimation(.easeInOut) { bootPhase = .onboarding }
                return
            }
            // C) 正常首页启动
            shouldOnboardAfterSignIn = false
            proceedNormalBoot()
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

        group.enter()
        fetchAndSaveRecommendationIfNeeded()
        waitUntilRecommendationsReady(timeout: 12) { group.leave() }

        group.notify(queue: .main) {
            
            // (If the doc doesn't exist yet, it'll become available after fetch/save.)
            self.reasoningStore.load(for: Date())
            resolveSplashInfoAndAdvance()

            
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

    private func resolveSplashInfoAndAdvance() {
        // Compute zodiac/moon locally (fast)
        splashZodiac = currentZodiacSign()
        splashMoon   = currentMoonPhaseLabel()

        // Resolve a friendly city name if we have coordinates now
        if let coord = locationManager.currentLocation {
            getAddressFromCoordinate(coord) { place in
                splashLocation = place ?? "Your Current Location"
                withAnimation(.easeInOut) { bootPhase = .infoSplash }
            }
        } else {
            splashLocation = "Your Current Location"
            withAnimation(.easeInOut) { bootPhase = .infoSplash }
        }
    }



    var body: some View {
        Group {
            switch bootPhase {
            case .loading:
                LoadingView(onStartLoading: {
                    startInitialLoad()
                })
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
            case .infoSplash:
                            WelcomeSplashView(location: splashLocation,
                                                zodiac: splashZodiac,
                                                moon: splashMoon)
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .onAppear {
                                // Show the splash briefly, then go main
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    withAnimation(.easeInOut) { bootPhase = .main }
                                }
                            }
                            .ignoresSafeArea()
                                    
                        case .main:
                            mainContent // (extract your existing NavigationStack content into a computed var)
                        }
                    }
                    .onAppear {
                        // run once on cold start
                        guard !didBootVisuals else { return }
                        didBootVisuals = true

                        starManager.animateStar = true
                        themeManager.appBecameActive()
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
                        NavigationLink {
                            // Build the docs map for all eight categories from your viewModel
                            let docsMap: [RecCategory: String] = Dictionary(uniqueKeysWithValues:
                                RecCategory.allCases.map { cat in
                                    let key = cat.rawValue
                                    return (cat, viewModel.recommendations[key] ?? "")
                                }
                            )
                            RecommendationPagerView(docsByCategory: docsMap, selected: startCat)
                                .environmentObject(starManager)
                                .environmentObject(themeManager)
                                .environmentObject(viewModel)
                        } label: {
                    VStack(spacing: 2) {   // ⬅️ tighter spacing
                        // 图标图像
                        SafeImage(name: documentName, renderingMode: .template, contentMode: .fit)
                            .foregroundColor(themeManager.foregroundColor)
                            .frame(width: geometry.size.width * 0.18)  // slightly smaller to balance text
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 1.5)
                        
                        // 推荐名称（小字体，紧贴图标）
                        Text(recommendationTitles[title] ?? "")
                            .font(AlignaType.gridItemName())
                            .lineSpacing(AlignaType.body16LineSpacing) // 22-16=6
                            .foregroundColor(themeManager.foregroundColor.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        
                        // 类别标题（和上面稍微拉开）
                        Text(title)
                            .font(AlignaType.gridCategoryTitle())
                            .lineSpacing(34 - 28) // 6
                            .foregroundColor(themeManager.foregroundColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            } else {
                Button {
                    print("⚠️ 无法进入 '\(title)'，推荐结果尚未加载")
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "questionmark.square.dashed")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.18)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.4))
                        
                        Text("Loading")
                            .font(Font.custom("Merriweather-Regular", size: geometry.size.width * 0.033))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.5))
                        
                        Text(title)
                            .font(Font.custom("Merriweather-Bold", size: geometry.size.width * 0.05))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.5))
                        }
                }
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
    }
    
    
    
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
    
    
    private func loadTodayRecommendation(day: String? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法获取推荐")
            return
        }

        let today = day ?? todayString()
        let db = Firestore.firestore()
        let fixedDocRef = todayDocRef(uid: userId, day: today)

        func applyDailyData(_ data: [String: Any]) {
            var recs: [String: String] = [:]
            var fetchedMantra = ""
            var fetchedReasoning = ""

            let fetchedPlace = (data["generatedPlace"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

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

                let reasoningTrim = fetchedReasoning.trimmingCharacters(in: .whitespacesAndNewlines)
                if !reasoningTrim.isEmpty {
                    self.viewModel.reasoningSummary = fetchedReasoning
                } else {
                    print("⚠️ Firestore 今日文档没有 reasoning_summary 或为空（docId=\(userId)_\(today)）")
                }

                self.ensureDefaultsIfMissing()
                self.fetchAllRecommendationTitles()
                self.persistWidgetSnapshotFromViewModel()

                print("✅ 成功加载今日推荐（固定 docId 优先）：\(recs), mantra=\(!mantraTrim.isEmpty), reasoning=\(!reasoningTrim.isEmpty), place=\(fetchedPlace)")
            }
        }

        // 1) ✅ 优先读取固定 docId：uid_yyyy-MM-dd
        fixedDocRef.getDocument { snap, err in
            if let err = err {
                print("❌ 读取今日固定 docId 失败：\(err.localizedDescription)；使用本地默认内容")
                DispatchQueue.main.async {
                    self.ensureDefaultsIfMissing()
                }
                return
            }

            if let snap = snap, snap.exists, let data = snap.data() {
                applyDailyData(data)
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
                        }
                        return
                    }

                    guard let docs = snapshot?.documents, !docs.isEmpty else {
                        print("⚠️ 今日暂无推荐数据。使用本地默认内容")
                        DispatchQueue.main.async {
                            self.ensureDefaultsIfMissing()
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
    @State var selected: RecCategory
    
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Full-bleed background
            AppBackgroundView()
                .environmentObject(starManager)
                .ignoresSafeArea() // <- key line

            TabView(selection: $selected) {
                ForEach(RecCategory.allCases) { cat in
                    Group {
                        if let doc = docsByCategory[cat], !doc.isEmpty {
                            pageView(for: cat, documentName: doc).id(doc)
                        } else {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading \(cat.rawValue)…")
                                    .foregroundColor(themeManager.foregroundColor.opacity(0.7))
                            }
                        }
                    }
                    .tag(cat)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            
            CustomBackButton(
                //                iconSize: 18,
                ////                paddingSize: 8,
                //                backgroundColor: Color.black.opacity(0.3),
                //                iconColor: themeManager.foregroundColor,
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
                        .foregroundColor(themeManager.foregroundColor)
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
