//  AlignaTestApp.swift  — 入口（替换整文件）
//  逻辑：未登录 => OnboardingOpeningPage；已登录 => FirstPageView

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UIKit
import GoogleSignIn

// MARK: - AppDelegate（Firebase + Google 回调）
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
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

    // 路由状态
    @State private var isReady = false
    @State private var isAuthenticated = (Auth.auth().currentUser != nil)

    var body: some View {
        Group {
            if !isReady {
                ZStack {
                    AppBackgroundView().environmentObject(starManager)
                    ProgressView("Loading…")
                }
            } else if !isAuthenticated {
                // 未登录 → 开场页
                NavigationStack {
                    OnboardingOpeningPage()
                }
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(onboardingViewModel)
                .preferredColorScheme(themeManager.isNight ? .dark : .light)
            } else {
                // 已登录 → 首页
                FirstPageView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(onboardingViewModel)
                    .preferredColorScheme(themeManager.isNight ? .dark : .light)
            }
        }
        .onAppear {
            // 监听登录态变化（冷启动、第三方登录回调后都会触发）
            Auth.auth().addStateDidChangeListener { _, user in
                self.isAuthenticated = (user != nil)
                self.isReady = true
                print("Auth state -> isAuthenticated=\(self.isAuthenticated)")
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
