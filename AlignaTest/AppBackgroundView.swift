import SwiftUI

// MARK: - 装饰同心环
struct DecorativeRings: View {
    let isAnimated: Bool
    let speedMultiplier: Double

    @State private var outerAngle: Double = 0
    @State private var middleAngle: Double = 0
    @State private var innerAngle: Double = 0
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#D4A574").opacity(pulse ? 0.04 : 0.14), lineWidth: 1)
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(isAnimated ? outerAngle : 0))
                .scaleEffect(pulse ? 1.12 : 0.96)
                .animation(
                    isAnimated ? .linear(duration: 50 * speedMultiplier).repeatForever(autoreverses: false) : nil,
                    value: outerAngle
                )

            Circle()
                .stroke(Color(hex: "#D4A574").opacity(pulse ? 0.03 : 0.11), lineWidth: 1)
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(isAnimated ? middleAngle : 0))
                .scaleEffect(pulse ? 1.10 : 0.98)
                .animation(
                    isAnimated ? .linear(duration: 38 * speedMultiplier).repeatForever(autoreverses: false) : nil,
                    value: middleAngle
                )

            Circle()
                .stroke(Color(hex: "#D4A574").opacity(pulse ? 0.02 : 0.09), lineWidth: 1)
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(isAnimated ? innerAngle : 0))
                .scaleEffect(pulse ? 1.08 : 0.99)
                .animation(
                    isAnimated ? .linear(duration: 26 * speedMultiplier).repeatForever(autoreverses: false) : nil,
                    value: innerAngle
                )
        }
        .onAppear {
            guard isAnimated else { return }
            outerAngle = 360
            middleAngle = -360
            innerAngle = 360
            withAnimation(.easeInOut(duration: 5 * speedMultiplier).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct NightStarView: View {
    let position: CGPoint
    let size: CGFloat
    let index: Int
    let isAnimated: Bool
    let speedMultiplier: Double

    @State private var twinkling = false
    @State private var drifting = false

    private var baseOpacity: Double {
        0.34 + min(max((size - 1.8) / 2.8, 0), 1) * 0.18
    }

    private var minOpacity: Double {
        max(0.16, baseOpacity - 0.12 - Double(index % 3) * 0.03)
    }

    private var maxOpacity: Double {
        min(0.96, baseOpacity + 0.16 + Double(index % 4) * 0.02)
    }

    private var minScale: CGFloat {
        max(0.78, 0.88 - CGFloat(index % 4) * 0.03)
    }

    private var maxScale: CGFloat {
        min(1.30, 1.08 + CGFloat(index % 5) * 0.035)
    }

    private var duration: Double {
        (1.5 + Double(index % 5) * 0.35) * speedMultiplier
    }

    private var delay: Double {
        Double(index % 7) * 0.18
    }

    private var driftOffset: CGSize {
        let dx = CGFloat((index % 5) - 2) * 1.8
        let dy = CGFloat((index % 7) - 3) * 1.6
        return CGSize(width: dx, height: dy)
    }

    private var driftDuration: Double {
        (6.0 + Double(index % 6) * 1.1) * speedMultiplier
    }

    var body: some View {
        Circle()
            .fill(Color.white.opacity(isAnimated ? (twinkling ? maxOpacity : minOpacity) : baseOpacity))
            .frame(width: size, height: size)
            .scaleEffect(isAnimated ? (twinkling ? maxScale : minScale) : 1)
            .position(position)
            .offset(isAnimated ? (drifting ? driftOffset : CGSize(width: -driftOffset.width, height: -driftOffset.height)) : .zero)
            .animation(
                isAnimated
                    ? .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                    : nil,
                value: twinkling
            )
            .animation(
                isAnimated
                    ? .easeInOut(duration: driftDuration)
                        .repeatForever(autoreverses: true)
                        .delay(delay * 0.6)
                    : nil,
                value: drifting
            )
            .onAppear {
                guard isAnimated else { return }
                twinkling = true
                drifting = true
            }
    }
}

// MARK: - Daytime background (for all light mode screens)
struct DayBackgroundLayer: View {
    let size: CGSize   // from outer GeometryReader

    var body: some View {
        let width = size.width
        let height = size.height
        let base = min(width, height)

        let blob1Size = base * 0.45
        let blob2Size = base * 0.38

        ZStack {
            // === Main vertical beige gradient (React gradient) ===
            LinearGradient(
                colors: [
                    Color(hex: "#F6EEDD"),
                    Color(hex: "#F8F1E4"),
                    Color(hex: "#FBF6EE"),
                    Color(hex: "#FDF9F3")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            // === Soft global radial glow ===
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#F4D69D").opacity(0.06),
                    .clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: base
            )
            .ignoresSafeArea()

            DayGrainLayer(size: CGSize(width: width, height: height))
                .blendMode(.softLight)
                .opacity(0.35)
                .allowsHitTesting(false)

            // === Ambient blobs (same idea as React) ===
            // top ~15%, left ~20%
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#FFDF9C").opacity(0.12),
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
                            Color(hex: "#FFEBBE").opacity(0.08),
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
            DayStarField()
                .allowsHitTesting(false)



            // === Bottom mountains – exact SVG shapes ===
            VStack {
                Spacer()
                DaySVGMountainsView()
                    .frame(height: height * 0.22)
            }

            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.32),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: height * 0.18)
                .blendMode(.softLight)
            }
        }
        .onAppear {
        }
        .frame(width: width, height: height, alignment: .center)
        .clipped()
    }
}

private struct DayGrainLayer: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let count = 140
            for index in 0..<count {
                let x = unit(Double(index) * 12.9898) * canvasSize.width
                let y = unit(Double(index) * 78.233) * canvasSize.height
                let r = 0.6 + unit(Double(index) * 45.164) * 0.9
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(0.08))
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func unit(_ seed: Double) -> Double {
        let value = abs(sin(seed) * 43758.5453)
        return value - floor(value)
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
            // M0,200 L0,150 Q60,120 120,135 Q180,150 240,130 Q300,110 360,135 Q380,145 400,140 L400,200 Z
            path.move(to: CGPoint(x: sx(0), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(150)))
            path.addQuadCurve(
                to: CGPoint(x: sx(120), y: sy(135)),
                control: CGPoint(x: sx(60), y: sy(120))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(240), y: sy(130)),
                control: CGPoint(x: sx(180), y: sy(150))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(360), y: sy(135)),
                control: CGPoint(x: sx(300), y: sy(110))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(400), y: sy(140)),
                control: CGPoint(x: sx(380), y: sy(145))
            )
            path.addLine(to: CGPoint(x: sx(400), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(200)))

        case .front:
            // M0,200 L0,165 Q80,145 160,160 Q240,175 320,155 Q360,145 400,150 L400,200 Z
            path.move(to: CGPoint(x: sx(0), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(165)))
            path.addQuadCurve(
                to: CGPoint(x: sx(160), y: sy(160)),
                control: CGPoint(x: sx(80), y: sy(145))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(320), y: sy(155)),
                control: CGPoint(x: sx(240), y: sy(175))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(400), y: sy(150)),
                control: CGPoint(x: sx(360), y: sy(145))
            )
            path.addLine(to: CGPoint(x: sx(400), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(200)))

        case .strip:
            // M0,200 L0,185 Q100,175 200,185 Q300,195 400,190 L400,200 Z
            path.move(to: CGPoint(x: sx(0), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(185)))
            path.addQuadCurve(
                to: CGPoint(x: sx(200), y: sy(185)),
                control: CGPoint(x: sx(100), y: sy(175))
            )
            path.addQuadCurve(
                to: CGPoint(x: sx(400), y: sy(190)),
                control: CGPoint(x: sx(300), y: sy(195))
            )
            path.addLine(to: CGPoint(x: sx(400), y: sy(200)))
            path.addLine(to: CGPoint(x: sx(0), y: sy(200)))
        }

        return path
    }
}

struct DayStar: Identifiable {
    enum ShapeKind {
        case fourPoint
        case cross
    }

    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let shape: ShapeKind
    let fillColor: Color
    let strokeColor: Color
    let delay: Double
    let spinDuration: Double
    let pulseDuration: Double
}

// 4-point star shape (like a sparkle)
struct FourPointStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let midX = w / 2
        let midY = h / 2
        let innerRadius = min(w, h) * 0.2
        let outerRadius = min(w, h) * 0.5

        var path = Path()
        // Top
        path.move(to: CGPoint(x: midX, y: midY - outerRadius))
        path.addLine(to: CGPoint(x: midX + innerRadius, y: midY - innerRadius))
        // Right
        path.addLine(to: CGPoint(x: midX + outerRadius, y: midY))
        path.addLine(to: CGPoint(x: midX + innerRadius, y: midY + innerRadius))
        // Bottom
        path.addLine(to: CGPoint(x: midX, y: midY + outerRadius))
        path.addLine(to: CGPoint(x: midX - innerRadius, y: midY + innerRadius))
        // Left
        path.addLine(to: CGPoint(x: midX - outerRadius, y: midY))
        path.addLine(to: CGPoint(x: midX - innerRadius, y: midY - innerRadius))
        path.closeSubpath()

        return path
    }
}

// 4-line cross (like a simple line star)
struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let midX = w / 2
        let midY = h / 2

        var path = Path()
        // vertical
        path.move(to: CGPoint(x: midX, y: 0))
        path.addLine(to: CGPoint(x: midX, y: h))
        // horizontal
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: w, y: midY))

        return path
    }
}

// MARK: - Animated star view (for day theme)
private struct AnimatedDayStar: View {
    let star: DayStar

    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        let base = {
            switch star.shape {
            case .fourPoint:
                return AnyView(
                    FourPointStarShape()
                        .fill(star.fillColor.opacity(0.88))
                )
            case .cross:
                return AnyView(
                    CrossShape()
                        .stroke(
                            star.strokeColor.opacity(0.95),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round)
                        )
                )
            }
        }()

        base
            .frame(width: star.size, height: star.size)
            .rotationEffect(.degrees(spin ? 360 : 0), anchor: .center)
            .scaleEffect(pulse ? 1.15 : 0.9)
            .opacity(pulse ? 0.95 : 0.6)
            .position(star.position)
            .onAppear {
                withAnimation(
                    .linear(duration: star.spinDuration)
                        .repeatForever(autoreverses: false)
                        .delay(star.delay)
                ) {
                    spin = true
                }

                withAnimation(
                    .easeInOut(duration: star.pulseDuration)
                        .repeatForever(autoreverses: true)
                        .delay(star.delay)
                ) {
                    pulse = true
                }
            }
    }
}




struct DayStarField: View {
    @State private var stars: [DayStar] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(stars) { star in
                    AnimatedDayStar(star: star)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .task(id: geo.size) {
                generateStars(in: geo.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Layout / generation

    private func generateStars(in size: CGSize) {
        let w = size.width
        let h = size.height

        guard w > 0, h > 0 else { return }   // 👈 extra safety
        var generated: [DayStar] = []

        // warm, sun-like palette
        let fills: [Color] = [
            Color(hex: "#FFF4B3").opacity(0.38),
            Color(hex: "#FFD700").opacity(0.45),
            Color(hex: "#F4D69D").opacity(0.44)
        ]
        let strokes: [Color] = [
            Color(hex: "#D4A574").opacity(0.45),
            Color(hex: "#C8925F").opacity(0.42)
        ]

        func makeRandomStar() {
            let nx = CGFloat.random(in: 0.05...0.95)
            let ny = CGFloat.random(in: 0.05...0.95)

            let s = CGFloat.random(in: 8...16)
            let shape: DayStar.ShapeKind = Bool.random() ? .fourPoint : .cross

            let fill  = fills.randomElement()   ?? fills[0]
            let stroke = strokes.randomElement() ?? strokes[0]
            let delay = Double.random(in: 0...3)
            let spinDuration  = Double.random(in: 8...16)
            let pulseDuration = Double.random(in: 4...8)

            generated.append(
                DayStar(
                    position: CGPoint(x: w * nx, y: h * ny),
                    size: s,
                    shape: shape,
                    fillColor: fill,
                    strokeColor: stroke,
                    delay: delay,
                    spinDuration: spinDuration,
                    pulseDuration: pulseDuration
                )
            )
        }

        let starCount = 16
        for _ in 0..<starCount {
            makeRandomStar()
        }
        stars = generated
    }
}







// MARK: - 背景视图
struct AppBackgroundView: View {
    /// 背景模式（默认自动：跟随 ThemeManager；也可强制日/夜）
    enum Mode { case auto, day, night }
    enum NightMotion { case staticBackground, animated }
    var mode: Mode = .auto
    var nightMotion: NightMotion = .staticBackground
    var nightAnimationSpeed: Double = 1.0

    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

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
                            .init(color: Color(hex: "#151424"), location: 0.00),
                            .init(color: Color(hex: "#121a33"), location: 0.45),
                            .init(color: Color(hex: "#0b2344"), location: 1.00),
                        ]),
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.06),
                            Color.clear
                        ]),
                        center: .top,
                        startRadius: 0,
                        endRadius: geo.size.height * 0.6
                    )
                    .ignoresSafeArea()
                } else {
                    Color(hex: "#E6D9BD").ignoresSafeArea()
                }

                // ===== 日间贴图 =====
                if !effectiveIsNight {
                    let fullSize = CGSize(
                        width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                        height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                    )
                    DayBackgroundLayer(size: fullSize)
                        .frame(width: fullSize.width, height: fullSize.height)
                        .offset(x: -geo.safeAreaInsets.leading, y: -geo.safeAreaInsets.top)
                        .ignoresSafeArea()
                }

                // ===== 夜间星空 + 同心环 =====
                if effectiveIsNight {
                    Color.clear
                        .task(id: geo.size) {
                            starManager.generateStars(in: geo.size)
                        }

                    ForEach(0..<starManager.stars.count, id: \.self) { index in
                        let star = starManager.stars[index]

                        NightStarView(
                            position: star.position,
                            size: star.size,
                            index: index,
                            isAnimated: nightMotion == .animated,
                            speedMultiplier: max(0.6, nightAnimationSpeed)
                        )
                    }

                    DecorativeRings(
                        isAnimated: nightMotion == .animated,
                        speedMultiplier: max(0.6, nightAnimationSpeed)
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .offset(y: -geo.size.height * 0.06)
                        .allowsHitTesting(false)

                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.black.opacity(0.35)
                        ]),
                        center: .center,
                        startRadius: geo.size.width * 0.2,
                        endRadius: geo.size.width * 0.9
                    )
                    .ignoresSafeArea()
                }
            }
            // let the whole background match the GeometryReader’s size
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .preferredColorScheme(themeManager.preferredColorScheme)
            .onAppear { themeManager.setSystemColorScheme(colorScheme) }
            .onChange(of: colorScheme) { _, new in themeManager.setSystemColorScheme(new) }
            .onChange(of: scenePhase) { _, new in if new == .active { themeManager.appBecameActive() } }
        }
    }
}

private struct AppBackgroundPreviewContainer: View {
    let mode: AppBackgroundView.Mode

    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager

    init(mode: AppBackgroundView.Mode) {
        self.mode = mode

        let themeManager = ThemeManager()
        switch mode {
        case .night:
            themeManager.selected = .night
        case .day, .auto:
            themeManager.selected = .day
        }
        _themeManager = StateObject(wrappedValue: themeManager)
    }

    var body: some View {
        AppBackgroundView(mode: mode)
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .ignoresSafeArea()
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Day Background") {
    AppBackgroundPreviewContainer(mode: .day)
}

#Preview("Night Background") {
    AppBackgroundPreviewContainer(mode: .night)
}
