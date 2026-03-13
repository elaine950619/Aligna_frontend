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
                    .renderingMode(.original)
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
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: size, height: size))
            label.backgroundColor = .clear
            label.textAlignment = .center
            label.text = emoji
            label.font = emojiUIFont(for: size * 0.92)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8

            label.drawHierarchy(in: label.bounds, afterScreenUpdates: true)
        }

        EmojiImageCache.shared.setObject(image, forKey: cacheKey)
        return image
    }

    private static func emojiUIFont(for size: CGFloat) -> UIFont {
        UIFont(name: "AppleColorEmoji", size: size)
            ?? UIFont(name: "Apple Color Emoji", size: size)
            ?? UIFont.systemFont(ofSize: size)
    }
}

private final class EmojiImageCache {
    static let shared = NSCache<NSString, UIImage>()
}
