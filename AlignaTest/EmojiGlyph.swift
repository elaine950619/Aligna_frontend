import SwiftUI
import UIKit

struct EmojiGlyph: View {
    let emoji: String
    let size: CGFloat

    var body: some View {
        Group {
            if let image = Self.renderedImage(for: emoji, size: size) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(emoji)
                    .font(.system(size: size))
            }
        }
        .frame(width: size, height: size)
    }

    private static func renderedImage(for emoji: String, size: CGFloat) -> UIImage? {
        let cacheKey = "\(emoji)-\(Int(size.rounded()))" as NSString
        if let cached = EmojiImageCache.shared.object(forKey: cacheKey) {
            return cached
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        let image = renderer.image { _ in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "AppleColorEmoji", size: size * 0.92) ?? UIFont.systemFont(ofSize: size),
                .paragraphStyle: paragraph
            ]

            let text = NSAttributedString(string: emoji, attributes: attributes)
            text.draw(in: CGRect(x: 0, y: max(0, size * 0.02), width: size, height: size))
        }

        EmojiImageCache.shared.setObject(image, forKey: cacheKey)
        return image
    }
}

private final class EmojiImageCache {
    static let shared = NSCache<NSString, UIImage>()
}
