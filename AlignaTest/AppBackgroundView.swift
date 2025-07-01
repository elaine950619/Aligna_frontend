import SwiftUI

struct AppBackgroundView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @State private var visible = false  // ✅ 控制本地动画状态

    private var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 7 || hour >= 22
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: isNight ? "#0D0D0D" : "#E6D9BD")
                    .ignoresSafeArea()
                
                if !isNight{
                    Image("dayBackground") // 替换为你的图片名（不要带 .png）
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }

                if isNight {
                    Color.clear
                        .task {
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
                }
            }
        }
    }
}
