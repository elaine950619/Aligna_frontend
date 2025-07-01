import SwiftUI

class StarAnimationManager: ObservableObject {
    @Published var animateStar = false
    @Published private(set) var stars: [(position: CGPoint, size: CGFloat)] = []

    func generateStars(in size: CGSize) {
        // 只生成一次
        guard stars.isEmpty else { return }

        stars = (0..<15).map { _ in
            (
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 2...6)
                
            )
        }
    }
}
