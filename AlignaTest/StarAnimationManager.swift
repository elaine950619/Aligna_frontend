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
        let count = 18
        let padding: CGFloat = 18
        let bounds = CGRect(
            x: padding,
            y: padding,
            width: max(1, size.width - padding * 2),
            height: max(1, size.height - padding * 2)
        )

        let columns = 3
        let rows = 6
        let cellWidth = bounds.width / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)
        let horizontalInset = cellWidth * 0.2
        let verticalInset = cellHeight * 0.22

        var generated: [(position: CGPoint, size: CGFloat)] = []

        for row in 0..<rows {
            for column in 0..<columns {
                guard generated.count < count else { break }

                let cellMinX = bounds.minX + CGFloat(column) * cellWidth
                let cellMinY = bounds.minY + CGFloat(row) * cellHeight
                let cellMaxX = cellMinX + cellWidth
                let cellMaxY = cellMinY + cellHeight

                let point = CGPoint(
                    x: CGFloat.random(in: (cellMinX + horizontalInset)...(cellMaxX - horizontalInset)),
                    y: CGFloat.random(in: (cellMinY + verticalInset)...(cellMaxY - verticalInset))
                )

                generated.append(
                    (
                        position: point,
                        size: CGFloat.random(in: 1.8...4.6)
                    )
                )
            }
        }

        return generated.shuffled()
    }

    func regenerateStars(in size: CGSize) {
        canvasSize = .zero
        stars.removeAll()
        generateStars(in: size)
    }

}
