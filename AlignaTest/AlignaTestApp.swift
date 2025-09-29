//  AlignaTestApp.swift  — 入口（替换整文件）
//  逻辑：未登录 => OnboardingOpeningPage；已登录 => FirstPageView

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UIKit
import GoogleSignIn
import AVFoundation

// MARK: - AppDelegate（Firebase + Google 回调）
class AppDelegate: NSObject, UIApplicationDelegate {
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

        return true
    }

    // Google Sign-In 回调
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) { return true }
        return false
    }
}

// MARK: - 根路由：仅以 Firebase 登录态 决定首屏
struct RootRouter: View {
    // 全局环境对象（在此统一注入，避免页面间丢失）
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var soundPlayer = SoundPlayer()        // ✅ 新增：全局音频播放器

    // 路由状态
    @State private var isReady = false
    @State private var isAuthenticated = (Auth.auth().currentUser != nil)

    var body: some View {
        Group {
            if !isReady {
                ZStack {
                    AppBackgroundView()
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                    ProgressView("Loading…")
                }
                .environmentObject(soundPlayer) // ✅ 注入，保证任意子层都能拿到
            } else if !isAuthenticated {
                // 未登录 → 开场页
                NavigationStack {
                    OnboardingOpeningPage()
                }
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(onboardingViewModel)
                .environmentObject(soundPlayer)  // ✅ 注入
                .preferredColorScheme(themeManager.isNight ? .dark : .light)
            } else {
                // 已登录 → 首页
                FirstPageView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(onboardingViewModel)
                    .environmentObject(soundPlayer)  // ✅ 注入
                    .preferredColorScheme(themeManager.isNight ? .dark : .light)
            }
        }
        .onAppear {
            // 监听登录态变化（冷启动、第三方登录回调后都会触发）
            Auth.auth().addStateDidChangeListener { _, user in
                self.isAuthenticated = (user != nil)
                self.isReady = true
                print("Auth state -> isAuthenticated=\(self.isAuthenticated)")

                // 🧹 关键：一旦变为“未登录”，清掉所有可能误触发 Onboarding 的本地标记
                if user == nil {
                    UserDefaults.standard.set(false, forKey: "shouldOnboardAfterSignIn")
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    UserDefaults.standard.set("",    forKey: "lastRecommendationDate")
                    UserDefaults.standard.set("",    forKey: "lastCurrentPlaceUpdate")
                    UserDefaults.standard.set("",    forKey: "todayFetchLock")
                }
            }
        }

    }
}

// MARK: - App 入口
@main
struct AlignaTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootRouter()
        }
    }
}
