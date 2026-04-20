import SwiftUI

// MARK: - 装饰同心环
struct DecorativeRings: View {
    let isAnimated: Bool
    let speedMultiplier: Double

    @State private var outerAngle: Double = 0
    @State private var middleAngle: Double = 0
    @State private var innerAngle: Double = 0
    @State private var pulseOuter = false
    @State private var pulseMiddle = false
    @State private var pulseInner = false

    // 外环：冷蓝轨道色
    private let outerColor  = Color(hex: "#7CA5C8")
    // 中环：原金棕，主视觉焦点
    private let middleColor = Color(hex: "#D4A574")
    // 内环：淡紫，最内核
    private let innerColor  = Color(hex: "#A89BC2")

    var body: some View {
        ZStack {

            // ── 外环光晕底座 ──
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            outerColor.opacity(pulseOuter ? 0.04 : 0.01),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 120,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .scaleEffect(pulseOuter ? 1.08 : 0.97)
                .animation(
                    isAnimated ? .easeInOut(duration: 6 * speedMultiplier).repeatForever(autoreverses: true) : nil,
                    value: pulseOuter
                )

            // ── 外环 stroke ──
            Circle()
                .stroke(outerColor.opacity(pulseOuter ? 0.16 : 0.07), lineWidth: 0.75)
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(isAnimated ? outerAngle : 0))
                .scaleEffect(pulseOuter ? 1.06 : 0.97)
                .animation(
                    isAnimated ? .linear(duration: 80 * speedMultiplier).repeatForever(autoreverses: false) : nil,
                    value: outerAngle
                )
                .animation(
                    isAnimated ? .easeInOut(duration: 6 * speedMultiplier).repeatForever(autoreverses: true) : nil,
                    value: pulseOuter
                )

            // ── 外环刻度点（12个，代表黄道十二宫）──
            ForEach(0..<12) { i in
                let angle = Double(i) * 30.0
                let rad = angle * .pi / 180.0
                let r: CGFloat = 150
                Circle()
                    .fill(outerColor.opacity(pulseOuter ? 0.30 : 0.13))
                    .frame(width: i % 3 == 0 ? 3 : 1.5,
                           height: i % 3 == 0 ? 3 : 1.5)
                    .offset(x: r * CGFloat(sin(rad)),
                            y: -r * CGFloat(cos(rad)))
                    .rotationEffect(.degrees(isAnimated ? outerAngle : 0))
                    .animation(
                        isAnimated ? .linear(duration: 80 * speedMultiplier).repeatForever(autoreverses: false) : nil,
                        value: outerAngle
                    )
                    .animation(
                        isAnimated ? .easeInOut(duration: 6 * speedMultiplier).repeatForever(autoreverses: true) : nil,
                        value: pulseOuter
                    )
            }

            // ── 中环光晕底座（最强，金色核心）──
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            middleColor.opacity(pulseMiddle ? 0.06 : 0.02),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 90,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .scaleEffect(pulseMiddle ? 1.07 : 0.98)
                .animation(
                    isAnimated ? .easeInOut(duration: 5 * speedMultiplier).repeatForever(autoreverses: true) : nil,
                    value: pulseMiddle
                )

            // ── 中环 stroke（主环，线宽最粗）──
            Circle()
                .stroke(middleColor.opacity(pulseMiddle ? 0.24 : 0.12), lineWidth: 1.0)
                .frame(width: 260, height: 260)
                .shadow(color: middleColor.opacity(pulseMiddle ? 0.14 : 0.05), radius: pulseMiddle ? 6 : 3)
                .rotationEffect(.degrees(isAnimated ? middleAngle : 0))
                .scaleEffect(pulseMiddle ? 1.05 : 0.98)
                .animation(
                    isAnimated ? .linear(duration: 45 * speedMultiplier).repeatForever(autoreverses: false) : nil,
                    value: middleAngle
                )
                .animation(
                    isAnimated ? .easeInOut(duration: 5 * speedMultiplier).repeatForever(autoreverses: true) : nil,
                    value: pulseMiddle
                )

            // ── 中环刻度点（4个，四元素方位）──
            ForEach(0..<4) { i in
                let angle = Double(i) * 90.0
                let rad = angle * .pi / 180.0
                let r: CGFloat = 130
                Circle()
                    .fill(middleColor.opacity(pulseMiddle ? 0.42 : 0.20))
                    .frame(width: 4, height: 4)
                    .shadow(color: middleColor.opacity(0.22), radius: 3)
                    .offset(x: r * CGFloat(sin(rad)),
                            y: -r * CGFloat(cos(rad)))
                    .rotationEffect(.degrees(isAnimated ? middleAngle : 0))
                    .animation(
                        isAnimated ? .linear(duration: 45 * speedMultiplier).repeatForever(autoreverses: false) : nil,
                        value: middleAngle
                    )
                    .animation(
                        isAnimated ? .easeInOut(duration: 5 * speedMultiplier).repeatForever(autoreverses: true) : nil,
                        value: pulseMiddle
                    )
            }

            // ── 内环光晕底座 ──
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            innerColor.opacity(pulseInner ? 0.07 : 0.02),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 60,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(pulseInner ? 1.06 : 0.99)
                .animation(
                    isAnimated ? .easeInOut(duration: 4 * speedMultiplier).repeatForever(autoreverses: true) : nil,
                    value: pulseInner
                )

            // ── 内环 stroke（trim 缺口，仪表盘感）──
            Circle()
                .trim(from: 0.0, to: 0.92)
                .stroke(innerColor.opacity(pulseInner ? 0.26 : 0.12), lineWidth: 1.25)
                .frame(width: 220, height: 220)
                .shadow(color: innerColor.opacity(pulseInner ? 0.16 : 0.05), radius: pulseInner ? 5 : 2)
                .rotationEffect(.degrees(isAnimated ? innerAngle : 0))
                .scaleEffect(pulseInner ? 1.04 : 0.99)
                .animation(
                    isAnimated ? .linear(duration: 25 * speedMultiplier).repeatForever(autoreverses: false) : nil,
                    value: innerAngle
                )
                .animation(
                    isAnimated ? .easeInOut(duration: 4 * speedMultiplier).repeatForever(autoreverses: true) : nil,
                    value: pulseInner
                )
        }
        .onAppear {
            guard isAnimated else { return }
            outerAngle  =  360
            middleAngle = -360
            innerAngle  =  360

            // 三环错峰呼吸，间隔 1.5s，避免同步抖动
            withAnimation(.easeInOut(duration: 6 * speedMultiplier).repeatForever(autoreverses: true)) {
                pulseOuter = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5 * speedMultiplier) {
                withAnimation(.easeInOut(duration: 5 * speedMultiplier).repeatForever(autoreverses: true)) {
                    pulseMiddle = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0 * speedMultiplier) {
                withAnimation(.easeInOut(duration: 4 * speedMultiplier).repeatForever(autoreverses: true)) {
                    pulseInner = true
                }
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

    // Mountain parallax sway
    @State private var mountainSway: CGFloat = 0

    var body: some View {
        let width = size.width
        let height = size.height

        ZStack {
            // === Main vertical warm-light gradient ===
            LinearGradient(
                colors: [
                    Color(hex: "#FFF8E8"),
                    Color(hex: "#FEF8EE"),
                    Color(hex: "#FFFBF6"),
                    Color(hex: "#FFFEFB")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            DayGrainLayer(size: CGSize(width: width, height: height))
                .blendMode(.softLight)
                .opacity(0.30)
                .allowsHitTesting(false)

            // === Rotating gold stars ===
            DayStarField()
                .allowsHitTesting(false)

            // === Bottom mountains with parallax sway ===
            VStack {
                Spacer()
                DaySVGMountainsView(sway: mountainSway)
                    .frame(height: height * 0.22)
            }

            // === Bottom edge softening ===
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.28),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: height * 0.16)
                .blendMode(.softLight)
            }
        }
        .frame(width: width, height: height, alignment: .center)
        .clipped()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 9.0)
                .repeatForever(autoreverses: true)
            ) {
                mountainSway = 1.0
            }
        }
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
    /// Animated sway value 0→1 driven by parent; each layer applies a
    /// scaled horizontal offset to create a parallax depth effect.
    var sway: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            // Max sway amplitude for the closest layer (in points)
            let amp: CGFloat = w * 0.025
            // sway goes 0→1 (easeInOut autoreverse), map to -amp…+amp
            let s = (sway * 2 - 1) * amp   // -amp … +amp

            ZStack(alignment: .bottom) {
                // Thin base strip
                Rectangle()
                    .fill(Color(hex: "#E8A84A").opacity(0.08))
                    .frame(height: h * 0.03)
                    .alignmentGuide(.bottom) { d in d[.bottom] }

                // Furthest layer — barely moves (parallax 0.15×)
                SVGMountainLayer(layer: .far)
                    .fill(Color(hex: "#E8A84A").opacity(0.14))
                    .offset(x: s * 0.15)

                // Mid-far layer — 0.28×
                SVGMountainLayer(layer: .midFar)
                    .fill(Color(hex: "#E8A84A").opacity(0.20))
                    .offset(x: s * 0.28)

                // Mid layer — 0.45×
                SVGMountainLayer(layer: .mid)
                    .fill(Color(hex: "#E8A84A").opacity(0.26))
                    .offset(x: s * 0.45)

                // Front hill — 0.68×
                SVGMountainLayer(layer: .front)
                    .fill(Color(hex: "#E8A84A").opacity(0.32))
                    .offset(x: s * 0.68)

                // Very front strip — full amplitude
                SVGMountainLayer(layer: .strip)
                    .fill(Color(hex: "#E8A84A").opacity(0.38))
                    .offset(x: s * 1.0)
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

        // warm palette: gold (primary) + rose-orange accent (~30%)
        let fills: [Color] = [
            Color(hex: "#FFF4B3").opacity(0.38),   // pale gold
            Color(hex: "#FFD700").opacity(0.45),   // bright gold
            Color(hex: "#F4D69D").opacity(0.44),   // apricot gold
            Color(hex: "#F4A882").opacity(0.36),   // rose-orange accent
            Color(hex: "#FFDAB0").opacity(0.40)    // soft peach accent
        ]
        let strokes: [Color] = [
            Color(hex: "#D4A574").opacity(0.45),   // warm brown
            Color(hex: "#C8925F").opacity(0.42),   // amber
            Color(hex: "#D4816A").opacity(0.40)    // rose-orange stroke
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
                // ===== 生命力主题背景 =====
                if themeManager.isVitality {
                    VitalityBackgroundLayer()
                        .ignoresSafeArea()
                }

                // ===== 爱意主题背景 =====
                if themeManager.isLove {
                    LoveBackgroundLayer()
                        .ignoresSafeArea()
                }

                // ===== 雨天背景 =====
                if themeManager.isRain {
                    RainBackgroundLayer(isDark: themeManager.rainIsDark)
                        .ignoresSafeArea()
                }

                // ===== 背景底色/渐变 =====
                if effectiveIsNight && !themeManager.isRain && !themeManager.isVitality && !themeManager.isLove {
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
                } else if !effectiveIsNight && !themeManager.isVitality && !themeManager.isLove {
                    Color(hex: "#E6D9BD").ignoresSafeArea()
                }

                // ===== 日间贴图 =====
                if !effectiveIsNight && !themeManager.isVitality && !themeManager.isLove {
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
                if effectiveIsNight && !themeManager.isRain && !themeManager.isVitality && !themeManager.isLove {
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

// MARK: - Rain Background

struct RainBackgroundLayer: View {
    /// true = 夜间雨（更深暗）；false = 日间雨（蓝灰明亮）
    var isDark: Bool = false

    @State private var rainOffset: CGFloat = -120

    // 日间：蓝灰色调偏亮
    private let dayGradient: [Gradient.Stop] = [
        .init(color: Color(hex: "#1E2E42"), location: 0.0),
        .init(color: Color(hex: "#263A52"), location: 0.5),
        .init(color: Color(hex: "#2E4660"), location: 1.0),
    ]
    // 夜间：墨蓝更深
    private let nightGradient: [Gradient.Stop] = [
        .init(color: Color(hex: "#0E1820"), location: 0.0),
        .init(color: Color(hex: "#131F2E"), location: 0.5),
        .init(color: Color(hex: "#192840"), location: 1.0),
    ]

    private var gradientStops: [Gradient.Stop] { isDark ? nightGradient : dayGradient }
    private var cloudOpacity: Double { isDark ? 0.14 : 0.20 }
    private var haloOpacity: Double  { isDark ? 0.04 : 0.08 }

    var body: some View {
        ZStack {
            // 1. Base gradient (switches day ↔ night)
            LinearGradient(
                stops: gradientStops,
                startPoint: .top, endPoint: .bottom
            )
            .animation(.easeInOut(duration: 1.2), value: isDark)
            .ignoresSafeArea()

            // 2. Cloud fog blobs
            GeometryReader { geo in
                Ellipse()
                    .fill(Color(hex: "#3A5470").opacity(cloudOpacity))
                    .frame(width: geo.size.width * 0.85, height: 180)
                    .blur(radius: 44)
                    .offset(x: -geo.size.width * 0.05, y: geo.size.height * 0.02)

                Ellipse()
                    .fill(Color(hex: "#3A5470").opacity(cloudOpacity * 0.65))
                    .frame(width: geo.size.width * 0.65, height: 130)
                    .blur(radius: 36)
                    .offset(x: geo.size.width * 0.25, y: geo.size.height * 0.10)
            }
            .animation(.easeInOut(duration: 1.2), value: isDark)
            .ignoresSafeArea()

            // 3. Rain streaks (white primary + cool violet-blue accent ~30%)
            GeometryReader { geo in
                let w = geo.size.width
                ForEach(0..<20, id: \.self) { i in
                    let xBase = (CGFloat(i) / 20.0) * w
                    let xJitter = CGFloat((i * 37 + 11) % 28) - 14.0
                    let x = xBase + xJitter
                    let length = CGFloat(14 + (i % 6) * 3)
                    let opacity = 0.045 + Double(i % 4) * 0.012
                    let speed = 1.1 + Double(i % 5) * 0.14
                    let stagger = Double(i) * (1.4 / 20.0)
                    // every 3rd streak gets the violet-blue accent tint
                    let streakColor: Color = (i % 3 == 2)
                        ? Color(hex: "#9BB8D4").opacity(opacity * 1.4)
                        : Color.white.opacity(opacity)

                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + 3, y: length))
                    }
                    .stroke(streakColor, lineWidth: 0.85)
                    .offset(y: rainOffset + (geo.size.height > 0 ? CGFloat((i * 53) % Int(geo.size.height)) : 0))
                    .animation(
                        .linear(duration: speed)
                        .repeatForever(autoreverses: false)
                        .delay(stagger),
                        value: rainOffset
                    )
                }
            }
            .ignoresSafeArea()

            // 4. Soft light halo (primary rain-blue) + secondary violet accent
            RadialGradient(
                colors: [Color(hex: "#7EB8D4").opacity(haloOpacity), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: 0,
                endRadius: 340
            )
            .animation(.easeInOut(duration: 1.2), value: isDark)
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: "#7A8FBF").opacity(haloOpacity * 0.7), Color.clear],
                center: UnitPoint(x: 0.75, y: 0.22),
                startRadius: 0,
                endRadius: 220
            )
            .animation(.easeInOut(duration: 1.2), value: isDark)
            .ignoresSafeArea()


        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                rainOffset = 900
            }
        }
    }
}

// MARK: - Vitality Background

struct VitalityBackgroundLayer: View {
    @State private var particleOffset: CGFloat = 0
    @State private var swayPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // 1. 清晨薄雾底色（浅雾绿 → 冷白绿）
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#E3E9E0"), location: 0.0),
                    .init(color: Color(hex: "#EDF2EA"), location: 0.45),
                    .init(color: Color(hex: "#F3F6F1"), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // 2. 雾感光斑（大面积柔光晕染）
            GeometryReader { geo in
                // 顶部左侧大光斑
                Ellipse()
                    .fill(Color(hex: "#B7C8B4").opacity(0.18))
                    .frame(width: geo.size.width * 0.75, height: 240)
                    .blur(radius: 60)
                    .position(x: geo.size.width * 0.3, y: 80)

                // 右侧中部光斑
                Ellipse()
                    .fill(Color(hex: "#C5D2C0").opacity(0.14))
                    .frame(width: geo.size.width * 0.55, height: 200)
                    .blur(radius: 50)
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.35)

                // 底部中央暖黄光（晨光穿透叶隙打在地面）
                Ellipse()
                    .fill(Color(hex: "#DDD5AF").opacity(0.15))
                    .frame(width: geo.size.width * 0.60, height: 160)
                    .blur(radius: 50)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.82)
            }
            .ignoresSafeArea()

            // 3. 底部大叶片（椭圆芭蕉叶剪影，浅绿点缀）
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // 左侧主叶（偏大，低透明度）
                VitalityLeafShape(curve: 0.22)
                    .fill(Color(hex: "#89A18B").opacity(0.16))
                    .frame(width: 180, height: 260)
                    .rotationEffect(.degrees(-22 + Double(swayPhase) * 1.0), anchor: .bottom)
                    .position(x: w * 0.10, y: h - 50)

                // 左侧后叶（更淡、更小）
                VitalityLeafShape(curve: 0.18)
                    .fill(Color(hex: "#4DA868").opacity(0.12))
                    .frame(width: 130, height: 190)
                    .rotationEffect(.degrees(-36 + Double(swayPhase) * 0.7), anchor: .bottom)
                    .position(x: w * 0.04, y: h - 30)

                // 右侧主叶
                VitalityLeafShape(curve: -0.22)
                    .fill(Color(hex: "#6BBD80").opacity(0.16))
                    .frame(width: 170, height: 240)
                    .rotationEffect(.degrees(24 - Double(swayPhase) * 0.9), anchor: .bottom)
                    .position(x: w * 0.90, y: h - 40)

                // 右侧后叶
                VitalityLeafShape(curve: -0.18)
                    .fill(Color(hex: "#4DA868").opacity(0.11))
                    .frame(width: 120, height: 180)
                    .rotationEffect(.degrees(38 - Double(swayPhase) * 0.6), anchor: .bottom)
                    .position(x: w * 0.97, y: h - 20)

                // 中央底部小叶（作为地面点缀）
                VitalityLeafShape(curve: 0.10)
                    .fill(Color(hex: "#82C98A").opacity(0.14))
                    .frame(width: 100, height: 150)
                    .rotationEffect(.degrees(-10 + Double(swayPhase) * 1.4), anchor: .bottom)
                    .position(x: w * 0.38, y: h - 5)

                VitalityLeafShape(curve: -0.10)
                    .fill(Color(hex: "#82C98A").opacity(0.13))
                    .frame(width: 95, height: 140)
                    .rotationEffect(.degrees(14 - Double(swayPhase) * 1.2), anchor: .bottom)
                    .position(x: w * 0.62, y: h)
            }
            .ignoresSafeArea()

            // 4. 草叶层（纤细，贴近底边）
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ForEach(0..<18, id: \.self) { i in
                    let xFrac = CGFloat((i * 53 + 9) % 101) / 101.0
                    let x = xFrac * w
                    let bladeH = CGFloat(35 + (i % 5) * 14)
                    let lean = Double((i % 7) - 3) * 5.0
                    let sway = lean + Double(swayPhase) * (i % 2 == 0 ? 2.2 : -2.0)
                    let opacity = 0.14 + Double(i % 4) * 0.05

                    VitalityGrassBlade()
                        .fill(i % 4 == 3 ? Color(hex: "#C8D44A").opacity(0.42) : Color(hex: "#5DBB74").opacity(opacity))
                        .frame(width: 2.5 + CGFloat(i % 3) * 0.5, height: bladeH)
                        .rotationEffect(.degrees(sway), anchor: .bottom)
                        .position(x: x, y: h - bladeH / 2)
                }
            }
            .ignoresSafeArea()

            // 5. 蕨叶侧影（左右边缘，极淡）
            GeometryReader { geo in
                let h = geo.size.height

                VitalityFernShape()
                    .stroke(Color(hex: "#5DBB74").opacity(0.18), lineWidth: 1.2)
                    .frame(width: 72, height: 110)
                    .rotationEffect(.degrees(-6 + Double(swayPhase) * 0.7), anchor: .bottom)
                    .position(x: 28, y: h * 0.70)

                VitalityFernShape()
                    .stroke(Color(hex: "#4DA868").opacity(0.13), lineWidth: 1.0)
                    .frame(width: 54, height: 82)
                    .rotationEffect(.degrees(-18 + Double(swayPhase) * 0.5), anchor: .bottom)
                    .position(x: 14, y: h * 0.58)

                VitalityFernShape()
                    .stroke(Color(hex: "#5DBB74").opacity(0.16), lineWidth: 1.2)
                    .frame(width: 72, height: 100)
                    .rotationEffect(.degrees(6 - Double(swayPhase) * 0.6), anchor: .bottom)
                    .scaleEffect(x: -1, y: 1)
                    .position(x: geo.size.width - 28, y: h * 0.66)
            }
            .ignoresSafeArea()

            // 6. 飘浮光粒（嫩芽孢子，非常淡）
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ForEach(0..<20, id: \.self) { i in
                    let xFrac = CGFloat((i * 31 + 7) % 89) / 89.0
                    let x = xFrac * w
                    let baseY = h > 0 ? h - CGFloat((i * 53 + 13) % Int(h)) : h
                    let size = CGFloat(2 + (i % 3))
                    let opacity = 0.06 + Double(i % 4) * 0.02
                    let speed = 5.0 + Double(i % 5) * 0.9
                    let stagger = Double(i) * (speed / 20.0)

                    Circle()
                        .fill(i % 3 == 2 ? Color(hex: "#E8D84A").opacity(0.45) : Color(hex: "#7DD890").opacity(opacity))
                        .frame(width: size, height: size)
                        .blur(radius: size * 0.5)
                        .position(x: x, y: baseY)
                        .offset(y: particleOffset - CGFloat(i % 4) * 45)
                        .animation(
                            .linear(duration: speed)
                            .repeatForever(autoreverses: false)
                            .delay(stagger),
                            value: particleOffset
                        )
                }
            }
            .ignoresSafeArea()

            // 7. 顶部雾白渐变（营造清晨晨雾感）
            LinearGradient(
                colors: [Color.white.opacity(0.28), Color.clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.30)
            )
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(
                .linear(duration: 6.0)
                .repeatForever(autoreverses: false)
            ) {
                particleOffset = -700
            }
            withAnimation(
                .easeInOut(duration: 4.0)
                .repeatForever(autoreverses: true)
            ) {
                swayPhase = 1.0
            }
        }
    }
}

/// 单片椭圆叶轮廓（芭蕉/龟背竹风格，curve 控制叶身弯曲方向：正数向左弯，负数向右弯）
private struct VitalityLeafShape: Shape {
    /// 控制叶身偏转，范围约 -0.35 ~ 0.35
    var curve: CGFloat = 0.20

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // 叶柄底部中心
        let base = CGPoint(x: w * 0.5, y: h)
        // 叶尖（顶部，沿 curve 方向偏移）
        let tip = CGPoint(x: w * (0.5 + curve * 0.5), y: 0)

        // 叶身中轴线上的控制锚点（叶最宽处约在 55% 高度）
        let midX = w * (0.5 + curve * 0.35)
        let midY = h * 0.45

        // 左侧叶缘：从 base → 向左鼓出 → tip
        let lOut = CGPoint(x: midX - w * 0.48, y: midY)
        path.move(to: base)
        path.addCurve(
            to: tip,
            control1: CGPoint(x: lOut.x, y: h * 0.72),
            control2: CGPoint(x: lOut.x + w * 0.06, y: midY * 0.45)
        )

        // 右侧叶缘：从 tip → 向右收回 → base
        let rOut = CGPoint(x: midX + w * 0.28, y: midY)
        path.addCurve(
            to: base,
            control1: CGPoint(x: rOut.x, y: midY * 0.55),
            control2: CGPoint(x: rOut.x - w * 0.04, y: h * 0.68)
        )
        path.closeSubpath()
        return path
    }
}

/// 草叶形状（尖细的草茎）
private struct VitalityGrassBlade: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: h))
        path.addCurve(
            to: CGPoint(x: w * 0.4, y: 0),
            control1: CGPoint(x: w * 0.2, y: h * 0.7),
            control2: CGPoint(x: w * 0.35, y: h * 0.3)
        )
        path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.05))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w * 0.7, y: h * 0.35),
            control2: CGPoint(x: w * 0.85, y: h * 0.65)
        )
        path.closeSubpath()
        return path
    }
}

/// 蕨叶形状（多羽状小叶沿主茎排列）
private struct VitalityFernShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // 主茎
        path.move(to: CGPoint(x: w * 0.5, y: h))
        path.addLine(to: CGPoint(x: w * 0.5, y: 0))

        // 沿主茎排列的 5 对小羽叶
        let leafCount = 5
        for i in 0..<leafCount {
            let t = CGFloat(i + 1) / CGFloat(leafCount + 1)
            let stemY = h * (1 - t)
            let leafLen = w * 0.42 * (1 - t * 0.4)
            let stemX = w * 0.5

            // 左侧小叶
            path.move(to: CGPoint(x: stemX, y: stemY))
            path.addCurve(
                to: CGPoint(x: stemX - leafLen, y: stemY - leafLen * 0.3),
                control1: CGPoint(x: stemX - leafLen * 0.4, y: stemY - leafLen * 0.05),
                control2: CGPoint(x: stemX - leafLen * 0.8, y: stemY - leafLen * 0.1)
            )
            path.addCurve(
                to: CGPoint(x: stemX, y: stemY),
                control1: CGPoint(x: stemX - leafLen * 0.7, y: stemY + leafLen * 0.1),
                control2: CGPoint(x: stemX - leafLen * 0.3, y: stemY + leafLen * 0.05)
            )

            // 右侧小叶
            path.move(to: CGPoint(x: stemX, y: stemY))
            path.addCurve(
                to: CGPoint(x: stemX + leafLen, y: stemY - leafLen * 0.3),
                control1: CGPoint(x: stemX + leafLen * 0.4, y: stemY - leafLen * 0.05),
                control2: CGPoint(x: stemX + leafLen * 0.8, y: stemY - leafLen * 0.1)
            )
            path.addCurve(
                to: CGPoint(x: stemX, y: stemY),
                control1: CGPoint(x: stemX + leafLen * 0.7, y: stemY + leafLen * 0.1),
                control2: CGPoint(x: stemX + leafLen * 0.3, y: stemY + leafLen * 0.05)
            )
        }
        return path
    }
}

// MARK: - 爱意主题背景

struct LoveBackgroundLayer: View {
    @State private var bubbleOffset: CGFloat = 0
    @State private var swayPhase: CGFloat = 0
    @State private var petalOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // 1. 底层渐变（浅玫瑰白 → 粉白雾气）
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#F4ECEE"), location: 0.0),
                    .init(color: Color(hex: "#F6F0F1"), location: 0.48),
                    .init(color: Color(hex: "#F2EBEE"), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // 2. 晕染光斑（大面积柔光晕）
            GeometryReader { geo in
                Ellipse()
                    .fill(Color(hex: "#DDB8BE").opacity(0.18))
                    .frame(width: geo.size.width * 0.72, height: 220)
                    .blur(radius: 55)
                    .position(x: geo.size.width * 0.28, y: 90)

                Ellipse()
                    .fill(Color(hex: "#DDBFC8").opacity(0.14))
                    .frame(width: geo.size.width * 0.52, height: 190)
                    .blur(radius: 45)
                    .position(x: geo.size.width * 0.80, y: geo.size.height * 0.38)

                Ellipse()
                    .fill(Color(hex: "#D8B7C0").opacity(0.15))
                    .frame(width: geo.size.width * 0.60, height: 170)
                    .blur(radius: 40)
                    .position(x: geo.size.width * 0.48, y: geo.size.height * 0.80)
            }
            .ignoresSafeArea()

            // 3. 底部花瓣剪影
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                LovePetalShape(curve: 0.28)
                    .fill(Color(hex: "#F0B8C8").opacity(0.20))
                    .frame(width: 110, height: 170)
                    .rotationEffect(.degrees(-20 + Double(swayPhase) * 0.8), anchor: .bottom)
                    .position(x: w * 0.10, y: h - 50)

                LovePetalShape(curve: 0.20)
                    .fill(Color(hex: "#F4C4D0").opacity(0.15))
                    .frame(width: 80, height: 130)
                    .rotationEffect(.degrees(-32 + Double(swayPhase) * 0.6), anchor: .bottom)
                    .position(x: w * 0.04, y: h - 30)

                LovePetalShape(curve: -0.28)
                    .fill(Color(hex: "#F0B8C8").opacity(0.18))
                    .frame(width: 105, height: 160)
                    .rotationEffect(.degrees(22 - Double(swayPhase) * 0.7), anchor: .bottom)
                    .position(x: w * 0.90, y: h - 45)

                LovePetalShape(curve: -0.20)
                    .fill(Color(hex: "#F4C4D0").opacity(0.14))
                    .frame(width: 75, height: 120)
                    .rotationEffect(.degrees(34 - Double(swayPhase) * 0.5), anchor: .bottom)
                    .position(x: w * 0.97, y: h - 25)

                LovePetalShape(curve: 0.12)
                    .fill(Color(hex: "#EFB4C4").opacity(0.16))
                    .frame(width: 70, height: 110)
                    .rotationEffect(.degrees(-10 + Double(swayPhase) * 1.0), anchor: .bottom)
                    .position(x: w * 0.40, y: h - 5)

                LovePetalShape(curve: -0.12)
                    .fill(Color(hex: "#EFB4C4").opacity(0.15))
                    .frame(width: 65, height: 100)
                    .rotationEffect(.degrees(12 - Double(swayPhase) * 0.9), anchor: .bottom)
                    .position(x: w * 0.62, y: h)
            }
            .ignoresSafeArea()

            // 4. 漂浮粉色泡泡（核心动效）
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ForEach(0..<6, id: \.self) { i in
                    let xFrac = CGFloat((i * 47 + 9) % 97) / 97.0
                    let x = xFrac * w
                    let baseY = h * 0.7 > 0 ? h - CGFloat((i * 67 + 21) % Int(h * 0.7)) : h
                    let size = CGFloat(16 + (i % 5) * 8)
                    let opacity = 0.38 + Double(i % 4) * 0.08
                    let speed = 14.0 + Double(i % 5) * 1.6
                    let stagger = Double(i) * (speed / 14.0)
                    let sway = Double(swayPhase) * (i % 2 == 0 ? 8.0 : -7.0)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.50),
                                    Color(hex: "#F8D0DC").opacity(0.55),
                                    Color(hex: "#F090A8").opacity(0.22),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.35, y: 0.30),
                                startRadius: 0,
                                endRadius: size * 0.6
                            )
                        )
                        .frame(width: size, height: size)
                        .blur(radius: size * 0.14)
                        .opacity(opacity)
                        .position(x: x + CGFloat(sway), y: baseY)
                        .offset(y: bubbleOffset - CGFloat(i % 4) * 50)
                        .animation(
                            .linear(duration: speed)
                            .repeatForever(autoreverses: false)
                            .delay(stagger),
                            value: bubbleOffset
                        )
                }
            }
            .ignoresSafeArea()

            // 6. 飘落花粉粒子（缓慢下落）
            GeometryReader { geo in
                let w = geo.size.width
                ForEach(0..<12, id: \.self) { i in
                    let xFrac = CGFloat((i * 29 + 13) % 89) / 89.0
                    let x = xFrac * w
                    let size = CGFloat(2 + (i % 3))
                    let opacity = 0.05 + Double(i % 3) * 0.025
                    let speed = 8.0 + Double(i % 4) * 1.0
                    let stagger = Double(i) * (speed / 12.0)

                    Circle()
                        .fill(Color(hex: "#F8C0CC").opacity(opacity))
                        .frame(width: size, height: size)
                        .position(x: x, y: -20 + petalOffset + CGFloat(i % 5) * 60)
                        .animation(
                            .linear(duration: speed)
                            .repeatForever(autoreverses: false)
                            .delay(stagger),
                            value: petalOffset
                        )
                }
            }
            .ignoresSafeArea()

            // 7. 顶部白雾渐变
            LinearGradient(
                colors: [Color.white.opacity(0.35), Color.clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.28)
            )
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(
                .linear(duration: 17.0)
                .repeatForever(autoreverses: false)
            ) {
                bubbleOffset = -800
            }
            withAnimation(
                .easeInOut(duration: 4.0)
                .repeatForever(autoreverses: true)
            ) {
                swayPhase = 1.0
            }
            withAnimation(
                .linear(duration: 9.0)
                .repeatForever(autoreverses: false)
            ) {
                petalOffset = 900
            }
        }
    }
}

/// 爱心形状（标准心形，由两段贝塞尔曲线构成）
private struct LoveHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // 底部尖端
        let tip    = CGPoint(x: w * 0.50, y: h)
        // 顶部中央凹点
        let notch  = CGPoint(x: w * 0.50, y: h * 0.28)
        // 左鼓包顶
        let lTop   = CGPoint(x: w * 0.22, y: 0)
        // 右鼓包顶
        let rTop   = CGPoint(x: w * 0.78, y: 0)

        path.move(to: tip)
        // 左半心
        path.addCurve(to: lTop,
            control1: CGPoint(x: w * 0.00, y: h * 0.82),
            control2: CGPoint(x: w * 0.00, y: h * 0.10))
        path.addCurve(to: notch,
            control1: CGPoint(x: w * 0.44, y: h * 0.00),
            control2: CGPoint(x: w * 0.50, y: h * 0.12))
        // 右半心
        path.addCurve(to: rTop,
            control1: CGPoint(x: w * 0.50, y: h * 0.12),
            control2: CGPoint(x: w * 0.56, y: h * 0.00))
        path.addCurve(to: tip,
            control1: CGPoint(x: w * 1.00, y: h * 0.10),
            control2: CGPoint(x: w * 1.00, y: h * 0.82))
        path.closeSubpath()
        return path
    }
}

/// 花瓣形状（非对称椭圆叶形，curve 控制偏转方向）
private struct LovePetalShape: Shape {
    var curve: CGFloat = 0.22

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let base = CGPoint(x: w * 0.5, y: h)
        let tip  = CGPoint(x: w * (0.5 + curve * 0.45), y: 0)
        let midX = w * (0.5 + curve * 0.30)
        let midY = h * 0.42

        // 左侧叶缘（外鼓）
        let lOut = CGPoint(x: midX - w * 0.52, y: midY)
        path.move(to: base)
        path.addCurve(
            to: tip,
            control1: CGPoint(x: lOut.x, y: h * 0.70),
            control2: CGPoint(x: lOut.x + w * 0.08, y: midY * 0.40)
        )

        // 右侧叶缘（内收）
        let rOut = CGPoint(x: midX + w * 0.32, y: midY)
        path.addCurve(
            to: base,
            control1: CGPoint(x: rOut.x, y: midY * 0.50),
            control2: CGPoint(x: rOut.x - w * 0.05, y: h * 0.66)
        )
        path.closeSubpath()
        return path
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
