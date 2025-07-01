//
//  AlignaTestApp.swift
//  AlignaTest
//
//  Created by Martinnn on 4/30/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct AlignaTestApp: App {
    @StateObject var starManager = StarAnimationManager()
    @StateObject var themeManager = ThemeManager()
    @StateObject var onboardingViewModel = OnboardingViewModel()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                    FirstPageView()
                        .environmentObject(StarAnimationManager())
                        .environmentObject(ThemeManager())
                        .environmentObject(onboardingViewModel)
                } else {
                    NavigationStack {
                        OnboardingStep1(viewModel: OnboardingViewModel())
                    }
                }
        }
    }
}
