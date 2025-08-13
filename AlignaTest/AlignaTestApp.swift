//
//  AlignaTestApp.swift
//  AlignaTest
//
//  Created by Martinnn on 4/30/25.
//

import SwiftUI
import FirebaseCore
import UIKit
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("✅ AppDelegate - FirebaseApp.configure()")
        FirebaseApp.configure()
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("📩 AppDelegate - OpenURL 回调: \(url.absoluteString)")
        if GIDSignIn.sharedInstance.handle(url) {
            print("✅ Google 登录 URL 已处理")
            return true
        }
        return false
    }
}


@main
struct AlignaTestApp: App {
    @StateObject var starManager = StarAnimationManager()
    @StateObject var themeManager = ThemeManager()
    @StateObject var onboardingViewModel = OnboardingViewModel()
    @StateObject var soundPlayer = SoundPlayer()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    FirstPageView()
                } else {
                    NavigationStack {
                        OnboardingOpeningPage()
                    }
                }
            }
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .environmentObject(onboardingViewModel)
            .environmentObject(soundPlayer)
        }
    }
}
