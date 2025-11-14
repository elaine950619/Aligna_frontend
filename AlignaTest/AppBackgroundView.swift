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

// MARK: - Daytime background (for all light mode screens)
struct DayBackgroundLayer: View {
    let size: CGSize   // get from outer GeometryReader

    @State private var sunPulse = false

    var body: some View {
        ZStack {
            // Main beige gradient
            LinearGradient(
                colors: [
                    Color(hex: "#F4E9D3"),
                    Color(hex: "#F7EFDC"),
                    Color(hex: "#FAF3E6"),
                    Color(hex: "#FCF5E9")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft global glow
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#F4D69D").opacity(0.15),
                    .clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: max(size.width, size.height)
            )
            .ignoresSafeArea()

            // Ambient blobs (similar to your React light spots)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#FFDF9C").opacity(0.18),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 260, height: 260)
                .position(x: size.width * 0.25,
                          y: size.height * 0.2)

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#FFEBBE").opacity(0.14),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 220, height: 220)
                .position(x: size.width * 0.8,
                          y: size.height * 0.75)

            // Sun in top-right
            DaySunView(pulse: $sunPulse)
                .frame(width: 140, height: 140)
                .position(x: size.width - 70,
                          y: size.height * 0.12)

            // Bottom hills / mountains
            VStack {
                Spacer()
                DayMountainsView()
                    .frame(height: 220)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
            ) {
                sunPulse = true
            }
        }
    }
}

// MARK: - Sun
struct DaySunView: View {
    @Binding var pulse: Bool

    var body: some View {
        ZStack {
            // Halo
            Circle()
                .fill(Color.yellow.opacity(0.28))
                .blur(radius: 18)
                .scaleEffect(pulse ? 1.1 : 0.95)

            // Core
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#FFF4B3"),
                            Color(hex: "#FFD700")
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.yellow.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: Color.yellow.opacity(0.4),
                        radius: 10, x: 0, y: 0)
                .scaleEffect(pulse ? 1.03 : 1.0)
        }
    }
}

// MARK: - Hills / mountains
struct DayMountainsView: View {
    var body: some View {
        ZStack {
            // Furthest layer
            DayMountainShape(curveHeight: 0.35)
                .fill(Color(hex: "#CD853F").opacity(0.12))

            // Middle layer
            DayMountainShape(curveHeight: 0.25)
                .fill(Color(hex: "#CD853F").opacity(0.18))
                .offset(y: 10)

            // Front layer
            DayMountainShape(curveHeight: 0.18)
                .fill(Color(hex: "#CD853F").opacity(0.24))
                .offset(y: 20)

            // Very front thin strip to seal the bottom
            Rectangle()
                .fill(Color(hex: "#CD853F").opacity(0.28))
                .frame(height: 18)
                .alignmentGuide(.bottom) { d in d[.bottom] }
                .offset(y: 92)
        }
    }
}

struct DayMountainShape: Shape {
    /// curveHeight controls how tall the hills are relative to view height
    var curveHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start at bottom-left
        path.move(to: CGPoint(x: 0, y: rect.height))

        let yBase = rect.height * (1 - curveHeight)

        // Simple wavy hill using two curves across the width
        path.addCurve(
            to: CGPoint(x: rect.width * 0.5, y: yBase + 20),
            control1: CGPoint(x: rect.width * 0.15, y: yBase - 10),
            control2: CGPoint(x: rect.width * 0.35, y: yBase + 30)
        )

        path.addCurve(
            to: CGPoint(x: rect.width, y: yBase + 10),
            control1: CGPoint(x: rect.width * 0.65, y: yBase - 20),
            control2: CGPoint(x: rect.width * 0.85, y: yBase + 25)
        )

        // Close bottom
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
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
                    DayBackgroundLayer(size: geo.size)
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
