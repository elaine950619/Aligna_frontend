import SwiftUI

struct FocusFetchingView: View {
    let focusName: String
    /// Called when min display time has elapsed AND data is ready
    let onComplete: () -> Void
    /// Pass true when mantra + items are ready
    let isDataReady: Bool

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    @State private var textPhase: Int = 0       // 0, 1, 2
    @State private var textOpacity: Double = 0
    @State private var logoScale: Double = 0.92
    @State private var logoOpacity: Double = 0
    @State private var minTimerFired = false
    @State private var hasCompleted = false

    private let stageTexts: [LocalizedStringKey] = [
        "fetch.stage_0",
        "fetch.stage_1",
        "fetch.stage_2"
    ]
    private let minDisplayDuration: TimeInterval = 1.8
    private let stageInterval: TimeInterval = 0.6

    var body: some View {
        ZStack {
            AppBackgroundView(nightMotion: .animated, nightAnimationSpeed: 7.0)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo pulse
                Group {
                    if UIImage(named: "alignaSymbol") != nil {
                        Image("alignaSymbol")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .foregroundColor(themeManager.primaryText)
                    } else {
                        Image(systemName: "sparkles")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .foregroundColor(themeManager.primaryText)
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // Stage text
                Text(stageTexts[min(textPhase, stageTexts.count - 1)])
                    .font(.custom("Merriweather-Regular", size: 15))
                    .foregroundColor(themeManager.descriptionText.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .padding(.horizontal, 40)

                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: isDataReady) { _, ready in
            if ready { tryComplete() }
        }
    }

    private func startAnimations() {
        // Logo fade in + pulse
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        // Continuous gentle pulse
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            logoScale = 1.06
        }

        // Text phase 0 — immediate
        withAnimation(.easeIn(duration: 0.4)) { textOpacity = 1.0 }

        // Phase 1 after stageInterval
        DispatchQueue.main.asyncAfter(deadline: .now() + stageInterval) {
            advanceTextPhase()
        }
        // Phase 2
        DispatchQueue.main.asyncAfter(deadline: .now() + stageInterval * 2) {
            advanceTextPhase()
        }

        // Min timer
        DispatchQueue.main.asyncAfter(deadline: .now() + minDisplayDuration) {
            minTimerFired = true
            tryComplete()
        }
    }

    private func advanceTextPhase() {
        withAnimation(.easeInOut(duration: 0.25)) { textOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            textPhase = min(textPhase + 1, stageTexts.count - 1)
            withAnimation(.easeIn(duration: 0.35)) { textOpacity = 1.0 }
        }
    }

    private func tryComplete() {
        guard minTimerFired && isDataReady && !hasCompleted else { return }
        hasCompleted = true
        withAnimation(.easeInOut(duration: 0.35)) { logoOpacity = 0; textOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onComplete()
        }
    }
}
