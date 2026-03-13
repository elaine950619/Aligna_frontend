import SwiftUI

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
                    AppBackgroundView(mode: .night)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)

                    VStack(spacing: 0) {
                        VStack(spacing: minLength * 0.022) {
                            AlignaHeading(
                                textColor: themeManager.fixedNightTextPrimary,
                                show: $showIntro,
                                fontSize: minLength * 0.12,
                                letterSpacing: minLength * 0.005
                            )

                            Text("A gentle reading of your day.")
                                .font(.custom("Merriweather-Bold", size: 27))
                                .foregroundColor(themeManager.fixedNightTextPrimary.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, w * 0.10)
                                .staggered(1, show: $showIntro)

                            Text("Alynna brings together reflection, ritual, and mood so each day can feel a little clearer, softer, and more your own.")
                                .font(AlignaTypography.font(.subheadline))
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, w * 0.12)
                                .staggered(2, show: $showIntro)
                        }
                        .padding(.top, h * 0.12)
                        .staggered(0, show: $showIntro)

                        Spacer(minLength: sectionGap)

                        Image("openingSymbol")
                            .resizable()
                            .scaledToFit()
                            .frame(width: minLength * 0.30)
                            .foregroundColor(themeManager.fixedNightTextPrimary.opacity(0.92))
                            .staggered(3, show: $showIntro)

                        Spacer(minLength: sectionGap)

                        VStack(spacing: minLength * 0.032) {
                            NavigationLink(destination: SignUpView()
                                .environmentObject(starManager)
                                .environmentObject(themeManager)
                                .environmentObject(viewModel)) {
                                    Text("Sign Up")
                                        .font(AlignaTypography.font(.headline))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeManager.fixedNightTextPrimary)
                                        .foregroundColor(.black)
                                        .cornerRadius(14)
                                }
                                .staggered(4, show: $showIntro)

                            NavigationLink(destination: LoginView()
                                .environmentObject(starManager)
                                .environmentObject(themeManager)
                                .environmentObject(viewModel)) {
                                    Text("Log In")
                                        .font(AlignaTypography.font(.headline))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                        )
                                        .foregroundColor(.white)
                                        .cornerRadius(14)
                                }
                                .staggered(5, show: $showIntro)

                            Text("Begin with what this day is holding.")
                                .font(AlignaTypography.font(.footnote))
                                .foregroundColor(themeManager.fixedNightTextTertiary)
                                .padding(.top, 6)
                                .staggered(6, show: $showIntro)
                        }
                        .padding(.horizontal, w * 0.10)
                        .padding(.bottom, h * 0.08)
                    }
                    .preferredColorScheme(.dark)
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
    OnboardingPreviewContainer { _ in
        FrontPageView()
    }
}
