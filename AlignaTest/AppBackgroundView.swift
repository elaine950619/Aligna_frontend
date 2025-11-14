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
    let size: CGSize   // from outer GeometryReader

    @State private var sunPulse = false

    var body: some View {
        let width = size.width
        let height = size.height
        let base = min(width, height)

        let sunSize   = width * 0.15
        let blob1Size = base * 0.45
        let blob2Size = base * 0.38

        ZStack {
            // === Main vertical beige gradient (React gradient) ===
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

            // === Soft global radial glow ===
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#F4D69D").opacity(0.08),
                    .clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: base
            )
            .ignoresSafeArea()

            // === Ambient blobs (same idea as React) ===
            // top ~15%, left ~20%
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#FFDF9C").opacity(0.14),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: blob1Size * 0.6
                    )
                )
                .frame(width: blob1Size, height: blob1Size)
                .position(
                    x: width * 0.20,
                    y: height * 0.15
                )

            // top ~75%, right ~15%
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#FFEBBE").opacity(0.10),
                            .clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: blob2Size * 0.6
                    )
                )
                .frame(width: blob2Size, height: blob2Size)
                .position(
                    x: width * 0.85,
                    y: height * 0.75
                )

            // === Rotating “gold” stars, like the React LineArtDecorations ===
//            DayStarField(size: size)
//                .allowsHitTesting(false)

            // === Sun: top ~8%, hugging the right edge ===
            DaySunView(pulse: $sunPulse)
                .frame(width: sunSize, height: sunSize)
                .position(
                    x: width - sunSize,            // right: 0
                    y: height * 0.08 + sunSize / 2     // top: 8%
                )

            // === Bottom mountains – exact SVG shapes ===
            VStack {
                Spacer()
                DaySVGMountainsView()
                    .frame(height: height * 0.22)
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

// MARK: - Hills / mountains using the same SVG paths as React
struct DaySVGMountainsView: View {
    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height

            ZStack(alignment: .bottom) {
                // Thin base strip (rect at y=195 → 200)
                Rectangle()
                    .fill(Color(hex: "#CD853F").opacity(0.05))
                    .frame(height: h * 0.03)
                    .alignmentGuide(.bottom) { d in d[.bottom] }

                // Furthest layer
                SVGMountainLayer(layer: .far)
                    .fill(Color(hex: "#CD853F").opacity(0.12))

                // Mid-far layer
                SVGMountainLayer(layer: .midFar)
                    .fill(Color(hex: "#CD853F").opacity(0.16))

                // Mid layer
                SVGMountainLayer(layer: .mid)
                    .fill(Color(hex: "#CD853F").opacity(0.20))

                // Front hill
                SVGMountainLayer(layer: .front)
                    .fill(Color(hex: "#CD853F").opacity(0.25))

                // Very front strip
                SVGMountainLayer(layer: .strip)
                    .fill(Color(hex: "#CD853F").opacity(0.28))
            }
        }
    }
}

struct SVGMountainLayer: Shape {
    enum Layer {
        case far, midFar, mid, front, strip
    }

    var layer: Layer

    func path(in rect: CGRect) -> Path {
        func sx(_ x: CGFloat) -> CGFloat { rect.width * (x / 400) }
        func sy(_ y: CGFloat) -> CGFloat { rect.height * (y / 200) }

        var path = Path()

        switch layer {
        case .far:
            // M0,200 L0,120 Q80,90 160,105 Q240,120 320,95 Q360,85 400,90 L400,200 Z
            path.move(to: CGPoint(x: sx(0), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(120)))
            path.addQuadCurve(
                to: CGPoint(x: sx(160), y: sy(105)),
                control: CGPoint(x: sx(80), y: sy(90))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(320), y: sy(95)),
                control: CGPoint(x: sx(240), y: sy(120))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(400), y: sy(90)),
                control: CGPoint(x: sx(360), y: sy(85))
            )
            path.addLine(to: CGPoint(x: sx(400), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(200)))

        case .midFar:
            // M0,200 L0,140 Q40,110 80,125 Q120,140 160,120 Q200,100 240,115
            // Q280,130 320,125 Q360,120 400,125 L400,200 Z
            path.move(to: CGPoint(x: sx(0), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(140)))
            path.addQuadCurve(
                to: CGPoint(x: sx(80), y: sy(125)),
                control: CGPoint(x: sx(40), y: sy(110))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(160), y: sy(120)),
                control: CGPoint(x: sx(120), y: sy(140))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(240), y: sy(115)),
                control: CGPoint(x: sx(200), y: sy(100))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(320), y: sy(125)),
                control: CGPoint(x: sx(280), y: sy(130))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(400), y: sy(125)),
                control: CGPoint(x: sx(360), y: sy(120))
            )
            path.addLine(to: CGPoint(x: sx(400), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(200)))

        case .mid:
            // M0,200 L0,170 Q60,150 120,165 Q180,180 240,160
            // Q300,140 360,155 Q380,160 400,150 L400,200 Z
            path.move(to: CGPoint(x: sx(0), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(170)))
            path.addQuadCurve(
                to: CGPoint(x: sx(120), y: sy(165)),
                control: CGPoint(x: sx(60), y: sy(150))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(240), y: sy(160)),
                control: CGPoint(x: sx(180), y: sy(180))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(360), y: sy(155)),
                control: CGPoint(x: sx(300), y: sy(140))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(400), y: sy(150)),
                control: CGPoint(x: sx(380), y: sy(160))
            )
            path.addLine(to: CGPoint(x: sx(400), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(200)))

        case .front:
            // M0,200 L0,180 Q30,165 60,175 Q90,185 120,175
            // Q150,165 180,170 Q210,175 240,180
            // Q270,185 300,180 Q330,175 360,180 Q380,182 400,185 L400,200 Z
            path.move(to: CGPoint(x: sx(0), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(180)))

            path.addQuadCurve(
                to: CGPoint(x: sx(60), y: sy(175)),
                control: CGPoint(x: sx(30), y: sy(165))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(120), y: sy(175)),
                control: CGPoint(x: sx(90), y: sy(185))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(180), y: sy(170)),
                control: CGPoint(x: sx(150), y: sy(165))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(240), y: sy(180)),
                control: CGPoint(x: sx(210), y: sy(175))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(300), y: sy(180)),
                control: CGPoint(x: sx(270), y: sy(185))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(360), y: sy(180)),
                control: CGPoint(x: sx(330), y: sy(175))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(400), y: sy(185)),
                control: CGPoint(x: sx(380), y: sy(182))
            )

            path.addLine(to: CGPoint(x: sx(400), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(200)))

        case .strip:
            // M0,200 L0,190 Q50,185 100,188 Q150,191 200,189
            // Q250,187 300,189 Q350,191 400,190 L400,200 Z
            path.move(to: CGPoint(x: sx(0), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(190)))

            path.addQuadCurve(
                to: CGPoint(x: sx(100), y: sy(188)),
                control: CGPoint(x: sx(50), y: sy(185))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(200), y: sy(189)),
                control: CGPoint(x: sx(150), y: sy(191))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(300), y: sy(189)),
                control: CGPoint(x: sx(250), y: sy(187))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(400), y: sy(190)),
                control: CGPoint(x: sx(350), y: sy(191))
            )

            path.addLine(to: CGPoint(x: sx(400), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(200)))
        }

        path.closeSubpath()
        return path
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

struct DayStar: Identifiable {
    enum Kind { case main, small, sparkle, cross, dot, special }

    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let kind: Kind
    let delay: Double
    let duration: Double
}

struct FourPointStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r  = min(rect.width, rect.height) / 2

        var p = Path()
        p.move(to: CGPoint(x: cx,     y: cy - r))
        p.addLine(to: CGPoint(x: cx + r * 0.4, y: cy))
        p.addLine(to: CGPoint(x: cx,     y: cy + r))
        p.addLine(to: CGPoint(x: cx - r * 0.4, y: cy))
        p.closeSubpath()
        return p
    }
}

struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r  = min(rect.width, rect.height) / 2

        var p = Path()
        // vertical
        p.move(to: CGPoint(x: cx, y: cy - r))
        p.addLine(to: CGPoint(x: cx, y: cy + r))
        // horizontal
        p.move(to: CGPoint(x: cx - r, y: cy))
        p.addLine(to: CGPoint(x: cx + r, y: cy))
        return p
    }
}

struct DayStarField: View {
    let size: CGSize

    @State private var stars: [DayStar] = []
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(stars) { star in
                starView(for: star)
            }
        }
        .onAppear {
            if stars.isEmpty {
                generateStars(in: size)
            }
            animate = true
        }
    }

    // MARK: - Generate random but stable stars
    private func generateStars(in size: CGSize) {
        var arr: [DayStar] = []
        let w = size.width
        let h = size.height

        func randX(_ minPct: CGFloat = 0.05, _ maxPct: CGFloat = 0.95) -> CGFloat {
            .random(in: w * minPct ... w * maxPct)
        }
        func randY(_ minPct: CGFloat = 0.10, _ maxPct: CGFloat = 0.90) -> CGFloat {
            .random(in: h * minPct ... h * maxPct)
        }

        // main stars (10)
        for _ in 0..<10 {
            let s = CGFloat.random(in: 8...18)
            arr.append(DayStar(
                position: CGPoint(x: randX(), y: randY()),
                size: s,
                kind: .main,
                delay: Double.random(in: 0...5),
                duration: Double.random(in: 6...14)
            ))
        }

        // small stars (8)
        for _ in 0..<8 {
            let s = CGFloat.random(in: 4...10)
            arr.append(DayStar(
                position: CGPoint(x: randX(0.05, 0.90), y: randY(0.10, 0.85)),
                size: s,
                kind: .small,
                delay: Double.random(in: 0...3),
                duration: Double.random(in: 4...10)
            ))
        }

        // sparkles (6)
        for _ in 0..<6 {
            let s = CGFloat.random(in: 6...14)
            arr.append(DayStar(
                position: CGPoint(x: randX(0.10, 0.90), y: randY(0.15, 0.75)),
                size: s,
                kind: .sparkle,
                delay: Double.random(in: 0...4),
                duration: Double.random(in: 1.5...3.5)
            ))
        }

        // crosses (4)
        for _ in 0..<4 {
            let s = CGFloat.random(in: 4...10)
            arr.append(DayStar(
                position: CGPoint(x: randX(0.10, 0.90), y: randY(0.15, 0.80)),
                size: s,
                kind: .cross,
                delay: Double.random(in: 0...3),
                duration: Double.random(in: 4...8)
            ))
        }

        // dots (8)
        for _ in 0..<8 {
            let s = CGFloat.random(in: 1...3)
            arr.append(DayStar(
                position: CGPoint(x: randX(0.05, 0.90), y: randY(0.10, 0.85)),
                size: s,
                kind: .dot,
                delay: Double.random(in: 0...2),
                duration: Double.random(in: 3...7)
            ))
        }

        // special sparkles (2)
        let specials: [(CGFloat, CGFloat)] = [(0.25, 0.35), (0.75, 0.60)]
        for (idx, pos) in specials.enumerated() {
            let s: CGFloat = idx == 0 ? 14 : 12
            arr.append(DayStar(
                position: CGPoint(x: w * pos.0, y: h * pos.1),
                size: s,
                kind: .special,
                delay: idx == 0 ? 0.5 : 2.8,
                duration: 5 + Double(idx) * 1.5
            ))
        }

        stars = arr
    }

    // MARK: - Per-star rendering + animation
    @ViewBuilder
    private func starView(for star: DayStar) -> some View {
        switch star.kind {
        case .main:
            FourPointStarShape()
                .stroke(Color(hex: "#CD853F").opacity(0.8), lineWidth: 1.5)
                .background(
                    FourPointStarShape()
                        .fill(Color(hex: "#CD853F").opacity(0.3))
                )
                .frame(width: star.size, height: star.size)
                .position(star.position)
                .rotationEffect(.degrees(animate ? 360 : 0))
                .scaleEffect(animate ? 1.2 : 0.8)
                .opacity(animate ? 0.8 : 0.4)
                .shadow(color: Color(hex: "#CD853F").opacity(0.3),
                        radius: 4)
                .animation(
                    .easeInOut(duration: star.duration)
                        .repeatForever(autoreverses: true)
                        .delay(star.delay),
                    value: animate
                )

        case .small:
            FourPointStarShape()
                .stroke(Color(hex: "#CD853F").opacity(0.7), lineWidth: 2)
                .background(
                    FourPointStarShape()
                        .fill(Color(hex: "#CD853F").opacity(0.4))
                )
                .frame(width: star.size, height: star.size)
                .position(star.position)
                .rotationEffect(.degrees(animate ? 360 : 0))
                .scaleEffect(animate ? 1.0 : 0.6)
                .opacity(animate ? 0.7 : 0.3)
                .animation(
                    .easeInOut(duration: star.duration)
                        .repeatForever(autoreverses: true)
                        .delay(star.delay),
                    value: animate
                )

        case .sparkle:
            FourPointStarShape()
                .stroke(Color(hex: "#FFC107").opacity(0.9), lineWidth: 1.5)
                .background(
                    FourPointStarShape()
                        .fill(Color(hex: "#FFC107").opacity(0.6))
                )
                .frame(width: star.size, height: star.size)
                .position(star.position)
                .scaleEffect(animate ? 1.8 : 0.0)
                .opacity(animate ? 0.9 : 0.0)
                .shadow(color: Color(hex: "#FFC107").opacity(0.5),
                        radius: 6)
                .animation(
                    .easeInOut(duration: star.duration)
                        .repeatForever(autoreverses: true)
                        .delay(star.delay),
                    value: animate
                )

        case .cross:
            CrossShape()
                .stroke(Color(hex: "#CD853F").opacity(0.4),
                        style: StrokeStyle(lineWidth: 1,
                                           lineCap: .round))
                .frame(width: star.size, height: star.size)
                .position(star.position)
                .opacity(animate ? 0.6 : 0.2)
                .animation(
                    .easeInOut(duration: star.duration)
                        .repeatForever(autoreverses: true)
                        .delay(star.delay),
                    value: animate
                )

        case .dot:
            Circle()
                .fill(Color(hex: "#CD853F").opacity(0.3))
                .frame(width: star.size, height: star.size)
                .position(star.position)
                .scaleEffect(animate ? 1.2 : 0.8)
                .opacity(animate ? 0.5 : 0.2)
                .animation(
                    .easeInOut(duration: star.duration)
                        .repeatForever(autoreverses: true)
                        .delay(star.delay),
                    value: animate
                )

        case .special:
            FourPointStarShape()
                .stroke(Color(hex: "#FFD700").opacity(0.95), lineWidth: 1.8)
                .background(
                    FourPointStarShape()
                        .fill(Color(hex: "#FFEB78").opacity(0.7))
                )
                .frame(width: star.size, height: star.size)
                .position(star.position)
                .rotationEffect(.degrees(animate ? 720 : 0))
                .scaleEffect(animate ? 1.5 : 0.0)
                .opacity(animate ? 1.0 : 0.0)
                .shadow(color: Color(hex: "#FFD700").opacity(0.6),
                        radius: 8)
                .animation(
                    .easeInOut(duration: star.duration)
                        .repeatForever(autoreverses: true)
                        .delay(star.delay),
                    value: animate
                )
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
