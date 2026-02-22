import SwiftUI
import Combine

@MainActor
final class StarAnimationManager: ObservableObject {
    @Published var animateStar: Bool = false
    @Published private(set) var stars: [(position: CGPoint, size: CGFloat)] = []

    // 你现在的主代码不用改：仍然调用 generateStars(in:)
    // 仍然用 stars 来画，仍然用 animateStar 来做 opacity/scale 动画

    // MARK: - Twinkle driver (auto “breathing”)
    private var twinkleCancellable: AnyCancellable?
    private var isTwinkleAutoEnabled: Bool = true

    init() {
        // 自动原地呼吸闪烁：不需要你在外面写 timer 或手动 toggle
        startTwinkleIfNeeded()
    }

    /// 如果你不想 manager 自动驱动闪烁（比如你外部已经有 toggle），可以在任何地方调用它关闭：
    /// starManager.setTwinkleAutoEnabled(false)
    func setTwinkleAutoEnabled(_ enabled: Bool) {
        isTwinkleAutoEnabled = enabled
        if enabled {
            startTwinkleIfNeeded()
        } else {
            stopTwinkle()
        }
    }

    private func startTwinkleIfNeeded() {
        guard isTwinkleAutoEnabled, twinkleCancellable == nil else { return }

        // 用随机区间的“呼吸节奏”更自然：每次 tick 用一个轻微随机的动画时长
        twinkleCancellable = Timer
            .publish(every: 1.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let dur = Double.random(in: 1.0...1.8)
                withAnimation(.easeInOut(duration: dur)) {
                    self.animateStar.toggle()
                }
            }
    }

    private func stopTwinkle() {
        twinkleCancellable?.cancel()
        twinkleCancellable = nil
    }

    // MARK: - Star generation (random but evenly spread)

    func generateStars(in size: CGSize) {
        // 只生成一次（保持你原来的行为）
        guard stars.isEmpty else { return }
        guard size.width > 0, size.height > 0 else { return }

        let count = 15
        let padding: CGFloat = 16

        let bounds = CGRect(
            x: padding,
            y: padding,
            width: max(1, size.width - padding * 2),
            height: max(1, size.height - padding * 2)
        )

        // 自动估算“最小间距”：屏幕越大间距越大，星星越不容易挤堆
        let area = bounds.width * bounds.height
        let autoMin = sqrt(area / CGFloat(count)) * 0.55
        let minDistance = max(18, autoMin)

        // 用 Poisson-disc 采样（最小间距随机点），保证随机又不会扎堆
        var points = poissonDiscSamples(in: bounds, minDistance: minDistance, desiredCount: count)

        // 如果点数不足（小屏幕 or 间距过大），放松一点再生成，保证能达到 count
        if points.count < count {
            points = poissonDiscSamples(in: bounds, minDistance: minDistance * 0.85, desiredCount: count)
        }

        // 最终填充 stars（保持你原本的 tuple 类型，不影响你主代码）
        stars = Array(points.prefix(count)).map { p in
            (
                position: p,
                size: CGFloat.random(in: 2...6)
            )
        }
    }

    /// 如果你有横竖屏/尺寸变化，且希望重生成星星（可选，不需要改主代码）
    func regenerateStars(in size: CGSize) {
        stars.removeAll()
        generateStars(in: size)
    }

    // MARK: - Poisson-disc sampling (Bridson)

    private func poissonDiscSamples(in rect: CGRect, minDistance r: CGFloat, desiredCount: Int) -> [CGPoint] {
        // 网格加速：cellSize = r / √2
        let cellSize = r / sqrt(2)
        let gridWidth = Int(ceil(rect.width / cellSize))
        let gridHeight = Int(ceil(rect.height / cellSize))

        func gridIndex(for p: CGPoint) -> (x: Int, y: Int) {
            let gx = Int((p.x - rect.minX) / cellSize)
            let gy = Int((p.y - rect.minY) / cellSize)
            return (gx, gy)
        }

        var grid = Array(repeating: Array(repeating: CGPoint?.none, count: gridHeight), count: gridWidth)
        var samples: [CGPoint] = []
        var active: [CGPoint] = []

        func insert(_ p: CGPoint) {
            samples.append(p)
            active.append(p)
            let idx = gridIndex(for: p)
            if idx.x >= 0, idx.x < gridWidth, idx.y >= 0, idx.y < gridHeight {
                grid[idx.x][idx.y] = p
            }
        }

        func isFarEnough(_ p: CGPoint) -> Bool {
            let idx = gridIndex(for: p)
            let startX = max(idx.x - 2, 0)
            let endX = min(idx.x + 2, gridWidth - 1)
            let startY = max(idx.y - 2, 0)
            let endY = min(idx.y + 2, gridHeight - 1)

            for x in startX...endX {
                for y in startY...endY {
                    if let q = grid[x][y] {
                        let dx = p.x - q.x
                        let dy = p.y - q.y
                        if (dx * dx + dy * dy) < (r * r) { return false }
                    }
                }
            }
            return true
        }

        func randomPointInRect() -> CGPoint {
            CGPoint(
                x: CGFloat.random(in: rect.minX...rect.maxX),
                y: CGFloat.random(in: rect.minY...rect.maxY)
            )
        }

        // 起点
        insert(randomPointInRect())

        let k = 30 // 每个 active 点尝试 k 次
        while !active.isEmpty && samples.count < desiredCount {
            let i = Int.random(in: 0..<active.count)
            let center = active[i]
            var found = false

            for _ in 0..<k {
                // 在 [r, 2r] 的环带里取随机点
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let radius = CGFloat.random(in: r...(2 * r))
                let p = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )

                guard rect.contains(p) else { continue }
                guard isFarEnough(p) else { continue }

                insert(p)
                found = true
                break
            }

            if !found {
                active.remove(at: i)
            }
        }

        return samples
    }
}
