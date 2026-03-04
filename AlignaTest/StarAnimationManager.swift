import SwiftUI
import Combine

@MainActor
final class StarAnimationManager: ObservableObject {
    @Published var animateStar: Bool = false
    @Published private(set) var stars: [(position: CGPoint, size: CGFloat)] = []
    private var canvasSize: CGSize = .zero
    private var twinkleCancellable: AnyCancellable?
    private var isTwinkleAutoEnabled: Bool = true

    init() {
        startTwinkleIfNeeded()
    }

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

    func generateStars(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        if stars.isEmpty {
            canvasSize = size
            stars = makeStars(in: size)
            return
        }

        guard canvasSize.width > 0, canvasSize.height > 0 else {
            canvasSize = size
            stars = makeStars(in: size)
            return
        }

        let widthChanged = abs(canvasSize.width - size.width) > 1
        let heightChanged = abs(canvasSize.height - size.height) > 1

        guard widthChanged || heightChanged else { return }

        let widthScale = size.width / canvasSize.width
        let heightScale = size.height / canvasSize.height

        stars = stars.map { star in
            let newX = min(max(star.position.x * widthScale, 0), size.width)
            let newY = min(max(star.position.y * heightScale, 0), size.height)
            return (position: CGPoint(x: newX, y: newY), size: star.size)
        }
        canvasSize = size
    }

    private func makeStars(in size: CGSize) -> [(position: CGPoint, size: CGFloat)] {
        let count = 15
        let padding: CGFloat = 16
        let bounds = CGRect(
            x: padding,
            y: padding,
            width: max(1, size.width - padding * 2),
            height: max(1, size.height - padding * 2)
        )

        let area = bounds.width * bounds.height
        let autoMin = sqrt(area / CGFloat(count)) * 0.55
        let minDistance = max(18, autoMin)

        var points = poissonDiscSamples(in: bounds, minDistance: minDistance, desiredCount: count)
        if points.count < count {
            points = poissonDiscSamples(in: bounds, minDistance: minDistance * 0.85, desiredCount: count)
        }

        return Array(points.prefix(count)).map { point in
            (
                position: point,
                size: CGFloat.random(in: 2...6)
            )
        }
    }

    func regenerateStars(in size: CGSize) {
        canvasSize = .zero
        stars.removeAll()
        generateStars(in: size)
    }

    private func poissonDiscSamples(in rect: CGRect, minDistance r: CGFloat, desiredCount: Int) -> [CGPoint] {
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

        insert(randomPointInRect())

        let k = 30
        while !active.isEmpty && samples.count < desiredCount {
            let i = Int.random(in: 0..<active.count)
            let center = active[i]
            var found = false

            for _ in 0..<k {
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
