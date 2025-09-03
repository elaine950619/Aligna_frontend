import SwiftUI

struct DecorativeRings: View {
    @State private var outerAngle: Double = 0
    @State private var middleAngle: Double = 0
    @State private var innerAngle: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#D4A574").opacity(0.15), lineWidth: 1)
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(outerAngle))
                .animation(.linear(duration: 60).repeatForever(autoreverses: false), value: outerAngle)
                .onAppear { outerAngle = 360 }                // ✅ 直接赋值

            Circle()
                .stroke(Color(hex: "#D4A574").opacity(0.10), lineWidth: 1)
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(middleAngle))
                .animation(.linear(duration: 45).repeatForever(autoreverses: false), value: middleAngle)
                .onAppear { middleAngle = -360 }              // ✅

            Circle()
                .stroke(Color(hex: "#D4A574").opacity(0.08), lineWidth: 1)
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(innerAngle))
                .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: innerAngle)
                .onAppear { innerAngle = 360 }                // ✅
        }
    }
}


struct AppBackgroundView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @State private var visible = false

    // 外部可强制夜间
    var alwaysNight: Bool = false

    // 使用 resolvedNight
    private var resolvedNight: Bool {
        if alwaysNight { return true }
        let hour = Calendar.current.component(.hour, from: Date())
        return /*hour < 7 || hour >= 22*/true
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景底色/渐变
                if resolvedNight {
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

                // 日间贴图（如果有）
                if !resolvedNight {
                    Image("dayBackground")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }

                // 夜间星空 + 同心环
                if resolvedNight {
                    Color.clear.task {
                        if starManager.stars.isEmpty { starManager.generateStars(in: geo.size) }
                        visible = true                                  // ✅ 只赋值
                    }

                    ForEach(0..<starManager.stars.count, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(visible ? 1 : 0.2))
                            .frame(width: starManager.stars[index].size,
                                   height: starManager.stars[index].size)
                            .position(starManager.stars[index].position)
                            .animation(.easeInOut(duration: 2.5)
                                        .repeatForever(autoreverses: true),
                                       value: visible)                   // ✅ 只对 opacity 绑定动画
                    }


                    DecorativeRings()
                        .position(x: geo.size.width/2, y: geo.size.height * 0.3)
                }
            }
        }
    }
}
