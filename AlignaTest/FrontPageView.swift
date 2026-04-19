import SwiftUI
import UIKit

struct FrontPageView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showIntro = false


    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height
                let minLength = min(w, h)
                let sectionGap = h * 0.07

                ZStack {
                    AppBackgroundView(nightMotion: .animated)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)

                    VStack(spacing: 0) {
                        VStack(spacing: minLength * 0.022) {
                            if let _ = UIImage(named: "alignaSymbol") {
                                Image("alignaSymbol")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: minLength * 0.14)
                                    .foregroundColor(themeManager.primaryText.opacity(0.92))
                                    .staggered(0, show: $showIntro)
                            }

                            AlignaHeading(
                                textColor: themeManager.primaryText,
                                show: $showIntro,
                                fontSize: minLength * 0.12,
                                letterSpacing: minLength * 0.005
                            )

                            Text("frontpage.tagline")
                                .font(AlynnaTypography.font(.subheadline))
                                .foregroundColor(themeManager.descriptionText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, w * 0.12)
                                .staggered(2, show: $showIntro)
                        }
                        .padding(.top, h * 0.17)
                        .staggered(0, show: $showIntro)

                        Spacer(minLength: sectionGap)

                        VStack(spacing: minLength * 0.032) {
                            NavigationLink(destination: SignUpView()
                                .environmentObject(starManager)
                                .environmentObject(themeManager)
                                .environmentObject(viewModel)) {
                                    Text("frontpage.signup")
                                        .font(AlynnaTypography.font(.headline).weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeManager.accent)
                                        .foregroundColor(themeManager.buttonForegroundOnPrimary)
                                        .cornerRadius(14)
                                }
                                .staggered(4, show: $showIntro)

                            NavigationLink(destination: LoginView()
                                .environmentObject(starManager)
                                .environmentObject(themeManager)
                                .environmentObject(viewModel)) {
                                    Text("frontpage.login")
                                        .font(AlynnaTypography.font(.headline).weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeManager.panelFill.opacity(themeManager.isNight ? 0.22 : 0.30))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(themeManager.panelStrokeHi.opacity(0.6), lineWidth: 1)
                                        )
                                        .foregroundColor(themeManager.primaryText)
                                        .cornerRadius(14)
                                }
                                .staggered(5, show: $showIntro)

                            Text("frontpage.disclaimer")
                                .font(AlynnaTypography.font(.footnote))
                                .foregroundColor(themeManager.descriptionText.opacity(0.6))
                                .padding(.top, 6)
                                .staggered(6, show: $showIntro)
                        }
                        .padding(.horizontal, w * 0.10)
                        .padding(.bottom, h * 0.08)
                    }
                    .preferredColorScheme(themeManager.preferredColorScheme)
                }
            }
        }
        .onAppear {
            starManager.animateStar = true
            showIntro = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
        }
        .onDisappear { showIntro = false }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview("Front Page") {
    NavigationStack {
        FrontPageView()
            .environmentObject(StarAnimationManager())
            .environmentObject(ThemeManager())
            .environmentObject(OnboardingViewModel())
    }
}
