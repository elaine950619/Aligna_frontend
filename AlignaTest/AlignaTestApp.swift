//  AlignaTestApp.swift  — 入口（替换整文件）
//  逻辑：未登录 => OnboardingView；已登录 => MainView

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import UIKit
import GoogleSignIn
import AVFoundation
import UserNotifications
import AppIntents
import WidgetKit
import BackgroundTasks

private let widgetSnapshotStorageKey = "alynna.widget.snapshot"

enum SessionCacheManager {
    private static let lastActiveUserIDKey = "lastActiveUserID"

    private static let sharedPresentationKeys: [String] = [
        "lastRecommendationDate",
        "lastRecommendationPlace",
        "lastRecommendationTimestamp",
        "lastRecommendationHasFullSet",
        "lastManualRefreshTimestamp",
        "lastCurrentPlaceUpdate",
        "todayFetchLock",
        "cachedDailyMantra",
        "shouldExpandMantraOnBoot",
        "shouldExpandMantraFromNotification",
        "mantraExpandHapticDay",
        "mantraGuidanceHintTapCount",
        "mantraGenerationHapticDay",
        "widgetLocationName",
        "widgetSunSign",
        "widgetMoonSign",
        "widgetRisingSign",
        "widgetWeatherSummary",
        "widgetWeatherDetailSummary",
        "widgetEnvironmentSummary"
    ]

    private static let sharedAppGroupKeys: [String] = [
        widgetSnapshotStorageKey,
        "widgetAirQualityText",
        "widgetCurrentSoundKey",
        "widgetCurrentSoundIsPlaying",
        "widgetLocationName",
        "widgetSunSign",
        "widgetMoonSign",
        "widgetRisingSign",
        "widgetWeatherSummary",
        "widgetWeatherDetailSummary",
        "widgetEnvironmentSummary"
    ]

    static func handleAuthChange(currentUserID: String?) {
        let defaults = UserDefaults.standard
        let nextUserID = currentUserID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let previousUserID = defaults.string(forKey: lastActiveUserIDKey) ?? ""

        if previousUserID != nextUserID {
            clearSharedPresentationCache()
        }

        if nextUserID.isEmpty {
            defaults.removeObject(forKey: lastActiveUserIDKey)
        } else {
            defaults.set(nextUserID, forKey: lastActiveUserIDKey)
        }
    }

    static func clearSharedPresentationCache() {
        let defaults = UserDefaults.standard
        sharedPresentationKeys.forEach { defaults.removeObject(forKey: $0) }

        if let sharedDefaults = UserDefaults(suiteName: AlynnaAppGroup.id) {
            sharedAppGroupKeys.forEach { sharedDefaults.removeObject(forKey: $0) }
            sharedDefaults.synchronize()
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct ToggleWidgetSoundIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Toggle Widget Sound"

    @Parameter(title: "Sound Key")
    var soundKey: String

    init() { }

    init(soundKey: String) {
        self.soundKey = soundKey
    }

    func perform() async throws -> some IntentResult {
        let trimmedKey = soundKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return .result() }

        await MainActor.run {
            SoundPlayer.shared.togglePlay(named: trimmedKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - AppDelegate（Firebase + Google 回调）
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static let bgTaskIdentifier = "com.aligna.dailymantrarefresh"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        // 可选：设置音频会话，避免被静音开关/打断（按需修改类别/选项）
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ AVAudioSession 配置失败: \(error)")
        }

        UNUserNotificationCenter.current().delegate = self

        // 注册后台处理任务（每日 mantra 静默更新）
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppDelegate.bgTaskIdentifier, using: nil) { task in
            AppDelegate.handleDailyMantraRefreshTask(task: task as! BGProcessingTask)
        }

        return true
    }

    // 每次 app 进入后台时调度下一次后台更新任务
    func applicationDidEnterBackground(_ application: UIApplication) {
        AppDelegate.scheduleDailyMantraRefresh()
    }

    /// 计算下一个每日更新时间点并提交 BGProcessingTask
    static func scheduleDailyMantraRefresh() {
        let defaults = UserDefaults.standard
        let updateHour = max(0, min(23, defaults.integer(forKey: "dailyRhythmUpdateHour")))
        let updateMinute = max(0, min(59, defaults.integer(forKey: "dailyRhythmUpdateMinute")))

        var cal = Calendar.current
        cal.timeZone = .current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = updateHour == 0 && updateMinute == 0 ? 7 : updateHour  // fallback 7:00
        comps.minute = updateHour == 0 && updateMinute == 0 ? 0 : updateMinute
        comps.second = 0

        guard var fireDate = cal.date(from: comps) else { return }
        // 如果今天的更新时间已过，安排明天的
        if fireDate <= now {
            fireDate = cal.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }

        let request = BGProcessingTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = fireDate
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 已安排后台 mantra 更新任务，最早触发：\(fireDate)")
        } catch {
            print("⚠️ 后台任务安排失败: \(error)")
        }
    }

    /// 后台任务执行体：调用 FastAPI，将结果存入 Firestore
    private static func handleDailyMantraRefreshTask(task: BGProcessingTask) {
        // 安排下一次（链式调度，保持每天触发）
        scheduleDailyMantraRefresh()

        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ 后台更新：用户未登录，跳过")
            task.setTaskCompleted(success: false)
            return
        }

        // 检查今天是否已经有非 default 的内容
        let defaults = UserDefaults.standard
        let lastRecDate = defaults.string(forKey: "lastRecommendationDate") ?? ""
        let hasFullSet = defaults.bool(forKey: "lastRecommendationHasFullSet")
        let todayStr = {
            var cal = Calendar.current
            cal.timeZone = .current
            let now = Date()
            let comps = cal.dateComponents([.hour, .minute], from: now)
            let currentMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            let updateHour = defaults.integer(forKey: "dailyRhythmUpdateHour")
            let updateMinute = defaults.integer(forKey: "dailyRhythmUpdateMinute")
            let updateMinutes = updateHour * 60 + updateMinute
            let effectiveDate: Date
            if currentMinutes < updateMinutes {
                effectiveDate = cal.date(byAdding: .day, value: -1, to: now) ?? now
            } else {
                effectiveDate = now
            }
            let df = DateFormatter()
            df.calendar = cal
            df.timeZone = .current
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: effectiveDate)
        }()

        if hasFullSet && lastRecDate == todayStr {
            print("ℹ️ 后台更新：今日内容已存在，跳过")
            task.setTaskCompleted(success: true)
            return
        }

        print("🌙 后台更新：开始为 \(todayStr) 拉取 mantra")

        // 构造最小可用的 API 请求（不含实时位置/天气，仅凭 Firestore 用户档案）
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        // 设置任务超时处理
        task.expirationHandler = {
            print("⚠️ 后台任务被系统提前终止")
            task.setTaskCompleted(success: false)
        }

        userRef.getDocument { snap, error in
            guard let data = snap?.data(), error == nil else {
                print("⚠️ 后台更新：无法读取用户档案")
                task.setTaskCompleted(success: false)
                return
            }

            // 从 Firestore 档案读取出生信息
            var birthDateStr = ""
            var birthTimeStr = "08:00"

            if let ts = data["birthday"] as? Timestamp {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                birthDateStr = df.string(from: ts.dateValue())
            } else if let s = data["birthDate"] as? String {
                birthDateStr = s
            }
            if let t = data["birthTime"] as? String {
                birthTimeStr = t
            }

            guard !birthDateStr.isEmpty else {
                print("⚠️ 后台更新：出生日期为空，跳过")
                task.setTaskCompleted(success: false)
                return
            }

            // 调用 FastAPI（不带位置/天气信号的最小 payload）
            guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
                task.setTaskCompleted(success: false)
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 55  // 留 5 秒给 Firestore 写入
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload: [String: Any] = [
                "uid": uid,
                "birth_date": birthDateStr,
                "birth_time": birthTimeStr,
                "latitude": data["birthLat"] ?? 0.0,
                "longitude": data["birthLng"] ?? 0.0,
                "source": "background_refresh"
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            URLSession.shared.dataTask(with: request) { responseData, response, error in
                if let error = error {
                    print("⚠️ 后台更新 API 失败: \(error)")
                    task.setTaskCompleted(success: false)
                    return
                }
                print("✅ 后台更新：API 调用完成，结果将由后端写入 Firestore")
                // 标记本地今日有内容（后端负责写 Firestore，下次前台打开时读取）
                DispatchQueue.main.async {
                    defaults.set(todayStr, forKey: "lastRecommendationDate")
                }
                task.setTaskCompleted(success: true)
            }.resume()
        }
    }

    // Google Sign-In 回调
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) { return true }
        return false
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let destination = userInfo["destination"] as? String, destination == "main_expanded" {
            UserDefaults.standard.set(true, forKey: "shouldExpandMantraFromNotification")
        }
        completionHandler()
    }
}

// MARK: - 根路由：仅以 Firebase 登录态 决定首屏
struct RootRouter: View {
    enum PreviewRoute {
        case loading
        case signedOut
        case signedIn
    }

    // 全局环境对象（在此统一注入，避免页面间丢失）
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var soundPlayer = SoundPlayer.shared
    @StateObject private var reasoningStore = DailyReasoningStore()
    @StateObject private var locationPermissionCoordinator = LocationPermissionCoordinator()

    // 路由状态
    @State private var isReady = false
    @State private var isAuthenticated = (Auth.auth().currentUser?.isEmailVerified == true)
    @State private var needsOnboarding: Bool? = nil
    @State private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    @AppStorage("shouldShowBootLoading") private var shouldShowBootLoading: Bool = false
    private let isPreviewMode: Bool

    init() {
        self.isPreviewMode = false
    }

#if DEBUG
    init(previewRoute: PreviewRoute) {
        self.isPreviewMode = true
        switch previewRoute {
        case .loading:
            _isReady = State(initialValue: false)
            _isAuthenticated = State(initialValue: false)
            _needsOnboarding = State(initialValue: nil)
        case .signedOut:
            _isReady = State(initialValue: true)
            _isAuthenticated = State(initialValue: false)
            _needsOnboarding = State(initialValue: nil)
        case .signedIn:
            _isReady = State(initialValue: true)
            _isAuthenticated = State(initialValue: true)
            _needsOnboarding = State(initialValue: false)
        }
    }
#endif

    private func setRouteState(isAuthenticated: Bool? = nil, needsOnboarding: Bool? = nil, isReady: Bool? = nil) {
        DispatchQueue.main.async {
            if let value = isAuthenticated, self.isAuthenticated != value {
                self.isAuthenticated = value
            }
            if let value = needsOnboarding, self.needsOnboarding != value {
                self.needsOnboarding = value
            }
            if let value = isReady, self.isReady != value {
                self.isReady = value
            }
        }
    }

    var body: some View {
        Group {
            if !isReady {
                LoadingView(
                    onStartLoading: nil,
                    onPersonalComplete: nil,
                    fixedMessageIndex: 0,
                    forceFullLoading: false
                )
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(onboardingViewModel)
                .environmentObject(soundPlayer) // ✅ 注入，保证任意子层都能拿到
                .environmentObject(locationPermissionCoordinator)
                .ignoresSafeArea()
            } else if !isAuthenticated {
                // 未登录 → 开场页
                NavigationStack {
                    FrontPageView()
                }
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(onboardingViewModel)
                .environmentObject(soundPlayer)  // ✅ 注入
                .environmentObject(reasoningStore)
                .environmentObject(locationPermissionCoordinator)
                .preferredColorScheme(themeManager.isNight ? .dark : .light)
            } else if needsOnboarding == true {
                // 已登录但资料不完整 → Onboarding
                NavigationStack {
                    OnboardingStep0(viewModel: onboardingViewModel)
                }
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(onboardingViewModel)
                .environmentObject(soundPlayer)
                .environmentObject(reasoningStore)
                .environmentObject(locationPermissionCoordinator)
                .preferredColorScheme(themeManager.isNight ? .dark : .light)
            } else {
                // 已登录 → 首页（由 MainView 内部决定是否先走 Loading）
                MainView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(onboardingViewModel)
                    .environmentObject(soundPlayer)  // ✅ 注入
                    .environmentObject(reasoningStore)
                    .environmentObject(locationPermissionCoordinator)
                    .preferredColorScheme(themeManager.isNight ? .dark : .light)
            }
        }
        .onAppear {
            guard !isPreviewMode else { return }
            // 监听登录态变化（冷启动、第三方登录回调后都会触发）
            authStateListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
                SessionCacheManager.handleAuthChange(currentUserID: user?.uid)

                if UserDefaults.standard.bool(forKey: "didDeleteAccount") {
                    try? Auth.auth().signOut()
                    GIDSignIn.sharedInstance.signOut()
                    setRouteState(isAuthenticated: false, isReady: true)
                    UserDefaults.standard.set(false, forKey: "didDeleteAccount")
                    UserDefaults.standard.set(false, forKey: "shouldOnboardAfterSignIn")
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    UserDefaults.standard.set("", forKey: "lastRecommendationDate")
                    UserDefaults.standard.set("", forKey: "lastCurrentPlaceUpdate")
                    UserDefaults.standard.set("", forKey: "todayFetchLock")
                    return
                }

                // Enforce email verification at the root router level.
                if let user, user.isEmailVerified == false {
                    try? Auth.auth().signOut()
                    GIDSignIn.sharedInstance.signOut()
                    setRouteState(isAuthenticated: false, isReady: true)
                    print("Auth state -> unverified email, signed out")
                    return
                }

                let nextIsAuthenticated = (user != nil)
                setRouteState(isAuthenticated: nextIsAuthenticated)
                print("Auth state -> isAuthenticated=\(nextIsAuthenticated)")

                if user == nil {
                    setRouteState(needsOnboarding: nil, isReady: true)
                    // 🧹 关键：一旦变为“未登录”，清掉所有可能误触发 Onboarding 的本地标记
                    UserDefaults.standard.set(false, forKey: "shouldOnboardAfterSignIn")
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    UserDefaults.standard.set("",    forKey: "lastRecommendationDate")
                    UserDefaults.standard.set("",    forKey: "lastCurrentPlaceUpdate")
                    UserDefaults.standard.set("",    forKey: "todayFetchLock")
                } else {
                    setRouteState(isReady: false)
                    determineRegistrationPathForCurrentUser { path in
                        setRouteState(needsOnboarding: (path == .needsOnboarding), isReady: true)
                    }
                }
            }
        }
        .onDisappear {
            if let authStateListenerHandle {
                Auth.auth().removeStateDidChangeListener(authStateListenerHandle)
                self.authStateListenerHandle = nil
            }
        }

    }
}

#if DEBUG
#Preview("RootRouter Loading") {
    RootRouter(previewRoute: .loading)
}

#Preview("RootRouter Signed Out") {
    RootRouter(previewRoute: .signedOut)
}

#Preview("RootRouter Signed In") {
    RootRouter(previewRoute: .signedIn)
}
#endif

// MARK: - App 入口
@main
struct AlignaTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
            FontRegistrar.registerAllFonts()
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear

            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }

    var body: some Scene {
        WindowGroup {
            RootRouter()
        }
    }
}
