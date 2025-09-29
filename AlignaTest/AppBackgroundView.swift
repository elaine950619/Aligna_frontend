import SwiftUI

// MARK: - 装饰同心环
struct DecorativeRings: View {
    @State private var outerAngle: Double = 0
    @State private var middleAngle: Double = 0
    @State private var innerAngle: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Color(hex: "#D4A574").opacity(0.15), lineWidth: 1)
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(outerAngle))
                .animation(.linear(duration: 60).repeatForever(autoreverses: false), value: outerAngle)
                .onAppear { outerAngle = 360 }

            Circle().stroke(Color(hex: "#D4A574").opacity(0.10), lineWidth: 1)
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(middleAngle))
                .animation(.linear(duration: 45).repeatForever(autoreverses: false), value: middleAngle)
                .onAppear { middleAngle = -360 }

            Circle().stroke(Color(hex: "#D4A574").opacity(0.08), lineWidth: 1)
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(innerAngle))
                .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: innerAngle)
                .onAppear { innerAngle = 360 }
        }
    }
}

// MARK: - 背景视图
struct AppBackgroundView: View {
    /// 背景模式（默认自动：跟随 ThemeManager；也可强制日/夜）
    enum Mode { case auto, day, night }
    var mode: Mode = .auto

    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var visible = false

    // 统一计算当前是否夜间
    private var effectiveIsNight: Bool {
        switch mode {
        case .day:
            return false
        case .night:
            return true
        case .auto:
            // 直接读取 ThemeManager 的 isNight（它已根据选项/时钟/系统外观计算）
            return themeManager.isNight
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ===== 背景底色/渐变 =====
                if effectiveIsNight {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "#1a1a2e"), location: 0.00),
                            .init(color: Color(hex: "#16213e"), location: 0.50),
                            .init(color: Color(hex: "#0f3460"), location: 1.00),
                        ]),
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                } else {
                    Color(hex: "#E6D9BD").ignoresSafeArea()
                }

                // ===== 日间贴图 =====
                if !effectiveIsNight {
                    Image("dayBackground")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }

                // ===== 夜间星空 + 同心环 =====
                if effectiveIsNight {
                    Color.clear
                        .task {
                            if starManager.stars.isEmpty {
                                starManager.generateStars(in: geo.size)
                            }
                            visible = true
                        }

                    ForEach(0..<starManager.stars.count, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(visible ? 1 : 0.2))
                            .frame(width: starManager.stars[index].size,
                                   height: starManager.stars[index].size)
                            .position(starManager.stars[index].position)
                            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: visible)
                    }

                    DecorativeRings()
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.3)
                }
            }
            // 让系统控件（导航栏、Picker 等）也跟随固定日/夜/自动
            .preferredColorScheme(themeManager.preferredColorScheme)

            // 保持 ThemeManager 跟系统外观同步（当选择“随系统”时）
            .onAppear { themeManager.setSystemColorScheme(colorScheme) }
            .onChange(of: colorScheme) { _, new in themeManager.setSystemColorScheme(new) }
            .onChange(of: scenePhase) { _, new in if new == .active { themeManager.appBecameActive() } }
        }
    }
}
