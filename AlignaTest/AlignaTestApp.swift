//  AlignaTestApp.swift  — 入口（替换整文件）
//  逻辑：未登录 => OnboardingView；已登录 => MainView

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UIKit
import GoogleSignIn
import AVFoundation
import UserNotifications

// MARK: - AppDelegate（Firebase + Google 回调）
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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

        return true
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
    @StateObject private var soundPlayer = SoundPlayer()        // ✅ 新增：全局音频播放器
    @StateObject private var reasoningStore = DailyReasoningStore()

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
                .environmentObject(soundPlayer) // ✅ 注入，保证任意子层都能拿到
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
                .preferredColorScheme(themeManager.isNight ? .dark : .light)
            } else if needsOnboarding == true {
                // 已登录但资料不完整 → Onboarding
                NavigationStack {
                    OnboardingStep1(viewModel: onboardingViewModel)
                }
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(onboardingViewModel)
                .environmentObject(soundPlayer)
                .environmentObject(reasoningStore)
                .preferredColorScheme(themeManager.isNight ? .dark : .light)
            } else {
                // 已登录 → 首页（由 MainView 内部决定是否先走 Loading）
                MainView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(onboardingViewModel)
                    .environmentObject(soundPlayer)  // ✅ 注入
                    .environmentObject(reasoningStore)
                    .preferredColorScheme(themeManager.isNight ? .dark : .light)
            }
        }
        .onAppear {
            guard !isPreviewMode else { return }
            // 监听登录态变化（冷启动、第三方登录回调后都会触发）
            authStateListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
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
