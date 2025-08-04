import SwiftUI

struct DecorativeRings: View {
    @State private var outerAngle: Double = 0
    @State private var middleAngle: Double = 0
    @State private var innerAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color(hex: "#D4A574").opacity(0.15), lineWidth: 1)
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(outerAngle))
                .onAppear {
                    withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                        outerAngle = 360
                    }
                }
            
            // Middle ring
            Circle()
                .stroke(Color(hex: "#D4A574").opacity(0.10), lineWidth: 1)
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(middleAngle))
                .onAppear {
                    withAnimation(.linear(duration: 45).repeatForever(autoreverses: false)) {
                        middleAngle = -360
                    }
                }
            
            // Inner ring
            Circle()
                .stroke(Color(hex: "#D4A574").opacity(0.08), lineWidth: 1)
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(innerAngle))
                .onAppear {
                    withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                        innerAngle = 360
                    }
                }
        }
    }
}

struct AppBackgroundView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @State private var visible = false  // ✅ 控制本地动画状态
    
    private var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return /*hour < 7 || hour >= 22*/ true
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isNight {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "#1a1a2e"), location: 0.00),
                            .init(color: Color(hex: "#16213e"), location: 0.50),
                            .init(color: Color(hex: "#0f3460"), location: 1.00),
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                } else {
                    Color(hex: "#E6D9BD")
                        .ignoresSafeArea()
                }
                
                if !isNight{
                    Image("dayBackground") // 替换为你的图片名（不要带 .png）
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }
                
                if isNight {
                    Color.clear.task {
                        // 只在第一次布局完成时生成星星
                        if starManager.stars.isEmpty {
                            starManager.generateStars(in: geo.size)
                        }
                        
                        // ✅ 启动闪烁动画
                        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                            visible = true
                        }
                    }
                    
                    ForEach(0..<starManager.stars.count, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(visible ? 1 : 0.2))  // ✅ 本地动画控制
                            .frame(width: starManager.stars[index].size,
                                   height: starManager.stars[index].size)
                            .position(starManager.stars[index].position)
                    }
                    
                    DecorativeRings()
                        .position(x: geo.size.width/2,
                                  y: geo.size.height * 0.3)
                }
            }
        }
    }
}
