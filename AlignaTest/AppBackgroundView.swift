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
            DayStarField()
                .allowsHitTesting(false)

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
        .frame(width: width, height: height, alignment: .center)
        .clipped()
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

struct FourPointStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r  = min(rect.width, rect.height) / 2

        // Outer + inner radii (tweak these to change “leafiness”)
        let outerR = r
        let innerR = r * 0.38

        func point(angleDeg: CGFloat, radius: CGFloat) -> CGPoint {
            let rad = angleDeg * .pi / 180
            // y is inverted in screen coords, so subtract sin
            return CGPoint(
                x: cx + cos(rad) * radius,
                y: cy - sin(rad) * radius
            )
        }

        var p = Path()

        // Start at top outer
        p.move(to: point(angleDeg: 90, radius: outerR))

        // Go around clockwise:
        // top → (top-right inner) → right → (bottom-right inner) → bottom → etc.
        p.addLine(to: point(angleDeg: 45, radius: innerR))
        p.addLine(to: point(angleDeg: 0,  radius: outerR))
        p.addLine(to: point(angleDeg: 315, radius: innerR))
        p.addLine(to: point(angleDeg: 270, radius: outerR))
        p.addLine(to: point(angleDeg: 225, radius: innerR))
        p.addLine(to: point(angleDeg: 180, radius: outerR))
        p.addLine(to: point(angleDeg: 135, radius: innerR))

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

struct AlignaDiamondStar: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r  = min(rect.width, rect.height) / 2

        // long vertical diamond, narrow sides (tweak 0.18 if you want thinner/thicker)
        let side = r * 0.18

        var p = Path()
        p.move(to: CGPoint(x: cx,        y: cy - r))     // top
        p.addLine(to: CGPoint(x: cx + side, y: cy))      // right
        p.addLine(to: CGPoint(x: cx,        y: cy + r))  // bottom
        p.addLine(to: CGPoint(x: cx - side, y: cy))      // left
        p.closeSubpath()
        return p
    }
}

// MARK: - Daytime decorative stars


struct DayStar: Identifiable {
    enum ShapeKind { case fourPoint, cross }
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

struct AnimatedDayStar: View {
    let star: DayStar

    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        let base: AnyView = {
            switch star.shape {
            case .fourPoint:
                return AnyView(
                    FourPointStarShape()
                        .fill(star.fillColor.opacity(0.75))
                        .overlay(
                            FourPointStarShape()
                                .stroke(star.fillColor.opacity(0.95), lineWidth: 1)
                        )
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
            .onAppear {
                if stars.isEmpty {
                    generateStars(in: geo.size)
                }
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

        // warm, sun-like palette
        let fills: [Color] = [
            Color(hex: "#FFF4B3").opacity(0.50),
            Color(hex: "#FFD700"),
            Color(hex: "#F4D69D").opacity(0.60)
        ]
        let strokes: [Color] = [
            Color(hex: "#D4A574").opacity(0.60),
            Color(hex: "#C8925F").opacity(0.60)
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

            stars.append(
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

        let starCount = 22
        for _ in 0..<starCount {
            makeRandomStar()
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
                        .frame(width: geo.size.width, height: geo.size.height)
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
            // let the whole background match the GeometryReader’s size
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .preferredColorScheme(themeManager.preferredColorScheme)
            .onAppear { themeManager.setSystemColorScheme(colorScheme) }
            .onChange(of: colorScheme) { _, new in themeManager.setSystemColorScheme(new) }
            .onChange(of: scenePhase) { _, new in if new == .active { themeManager.appBecameActive() } }
        }
    }
}
