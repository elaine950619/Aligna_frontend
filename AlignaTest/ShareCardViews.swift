import SwiftUI
import UIKit

// MARK: - WallpaperBackground (shared widget-style background)

struct WallpaperBackground: View {
    let hex: String

    var body: some View {
        GeometryReader { geo in
            let top    = Self.adjusted(hex, darken: 0.10, desaturate: 0.10)
            let bottom = Self.adjusted(hex, darken: 0.28, desaturate: 0.18)
            let base   = Self.adjusted(hex, darken: 0.18, desaturate: 0.14)
            let minDim = min(geo.size.width, geo.size.height)

            ZStack {
                base
                LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.08), Color.clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: minDim * 1.1
                )
                RadialGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.28)]),
                    center: .center,
                    startRadius: minDim * 0.3,
                    endRadius: max(geo.size.width, geo.size.height) * 0.95
                )
                Canvas { ctx, canvasSize in
                    for i in 0..<160 {
                        let x = Self.unit(Double(i) * 12.9898) * canvasSize.width
                        let y = Self.unit(Double(i) * 78.233) * canvasSize.height
                        let r = 0.4 + Self.unit(Double(i) * 45.164) * 0.9
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                 with: .color(Color.white.opacity(0.07)))
                    }
                }
                .blendMode(.softLight)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private static func adjusted(_ hex: String, darken: Double, desaturate: Double) -> Color {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        guard h.count == 6 else { return Color(hex: hex) }
        let r = Double(int >> 16) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        let avg = (r + g + b) / 3.0
        let dr = (r * (1 - desaturate) + avg * desaturate) * max(0, 1 - darken)
        let dg = (g * (1 - desaturate) + avg * desaturate) * max(0, 1 - darken)
        let db = (b * (1 - desaturate) + avg * desaturate) * max(0, 1 - darken)
        return Color(.sRGB, red: min(dr, 1), green: min(dg, 1), blue: min(db, 1), opacity: 1)
    }

    private static func unit(_ seed: Double) -> Double {
        let v = abs(sin(seed) * 43758.5453)
        return v - floor(v)
    }
}

// MARK: - WallpaperRenderView (off-screen render target, no safe area)

struct WallpaperRenderView: View {
    let mantra: String
    let colorHex: String
    let size: CGSize
    var selectedFont: Font = AlignaType.wallpaperMantraFont()
    var isItalic: Bool = (currentRecommendationLanguageCode() != "zh-Hans")

    private let textColor = Color(hex: "#F7F3EC")

    var body: some View {
        ZStack(alignment: .bottom) {
            WallpaperBackground(hex: colorHex)
                .frame(width: size.width, height: size.height)

            VStack(spacing: 0) {
                Spacer(minLength: size.height * 0.52)
                Text(mantra)
                    .font(selectedFont)
                    .italic(isItalic)
                    .lineSpacing(9)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(textColor)
                    .padding(.leading, size.width * 0.10)
                    .padding(.trailing, size.width * 0.18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .frame(width: size.width, height: size.height)

            HStack(spacing: 6) {
                if UIImage(named: "alignaSymbol") != nil {
                    Image("alignaSymbol")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(textColor.opacity(0.65))
                }
                Text("Alynna")
                    .font(.custom("Merriweather-Regular", size: 12))
                    .tracking(1.8)
                    .foregroundColor(textColor.opacity(0.65))
            }
            .padding(.bottom, 40)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - ShareCardPreviewWrapper
// 分享卡预览容器：居中展示卡片 + 底部分享按钮

struct ShareCardPreviewWrapper: View {
    let snapshot: MantraSnapshot
    let onDismiss: () -> Void

    @State private var shareMessage: String = ""
    @State private var showShareMessage = false

    private let textColor = Color(hex: "#F7F3EC")
    private let cardWidth:  CGFloat = 390
    private let cardHeight: CGFloat = 693

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.78).ignoresSafeArea()

                VStack(spacing: 20) {
                    let scale = min((geo.size.width - 48) / cardWidth,
                                    (geo.size.height * 0.74) / cardHeight)
                    ShareCardRenderView(snapshot: snapshot)
                        .frame(width: cardWidth, height: cardHeight)
                        .scaleEffect(scale)
                        .frame(width: cardWidth * scale, height: cardHeight * scale)
                        .clipShape(RoundedRectangle(cornerRadius: 24 / scale, style: .continuous))
                        .shadow(color: Color.black.opacity(0.50), radius: 28, x: 0, y: 14)

                    HStack(spacing: 16) {
                        Button { onDismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(textColor.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        Button { shareCard() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .medium))
                                Text(String(localized: "main.share"))
                                    .font(.custom("Merriweather-Regular", size: 15))
                            }
                            .foregroundColor(textColor)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                        }
                    }

                    if showShareMessage {
                        Text(shareMessage)
                            .font(.system(size: 13))
                            .foregroundColor(textColor.opacity(0.80))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, geo.safeAreaInsets.bottom + 8)
            }
        }
        .ignoresSafeArea()
    }

    private func shareCard() {
        FontRegistrar.registerAllFonts()
        let renderSize = CGSize(width: cardWidth, height: cardHeight)
        let renderView = ShareCardRenderView(snapshot: snapshot)
        let controller = UIHostingController(rootView: renderView)
        controller.safeAreaRegions = []
        controller.view.bounds = CGRect(origin: .zero, size: renderSize)
        controller.view.frame  = CGRect(origin: .zero, size: renderSize)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        var presenter: UIViewController = root
        while let next = presenter.presentedViewController { presenter = next }

        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                       y: presenter.view.bounds.maxY,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
    }
}

// MARK: - ShareCardRenderView
// 离屏渲染目标：390x693 (9:16) 分享卡，居中构图，底部品牌块

struct ShareCardRenderView: View {
    let snapshot: MantraSnapshot

    private let cardWidth:  CGFloat = 390
    private let cardHeight: CGFloat = 693
    private let textColor = Color(hex: "#F7F3EC")

    private var isChinese: Bool { snapshot.isChinese }

    private var mantraFont: Font {
        isChinese
            ? .custom("LXGWWenKaiTC-Regular", size: 21)
            : .custom("Merriweather-Bold", size: 18).italic()
    }
    private var mantraLineSpacing: CGFloat { isChinese ? 13 : 10 }

    private var focusFont: Font {
        isChinese
            ? .custom("SourceHanSansSCVF-Light", size: 12)
            : .custom("Merriweather-Regular", size: 11)
    }
    private var focusTracking: CGFloat { isChinese ? 1.2 : 2.0 }

    private var keywordFont: Font {
        isChinese
            ? .custom("LXGWWenKaiTC-Light", size: 10)
            : .custom("Merriweather-Light", size: 10)
    }

    private var filledStarCount: Int {
        min(5, max(0, Int((Double(snapshot.score) / 20.0).rounded())))
    }

    private var keywordLine: String {
        snapshot.keywords.prefix(3).joined(separator: "  ·  ")
    }

    private var dateLine: String {
        let df = DateFormatter()
        // Use saved locale so a zh-Hans snapshot keeps Chinese date formatting
        // even if the viewer has since switched languages.
        df.locale = Locale(identifier: snapshot.localeCode)
        df.setLocalizedDateFormatFromTemplate("MMMd")
        return df.string(from: snapshot.date)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            WallpaperBackground(hex: snapshot.colorHex)
                .frame(width: cardWidth, height: cardHeight)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    if !snapshot.focusName.isEmpty {
                        Text(isChinese ? snapshot.focusName : snapshot.focusName.uppercased())
                            .font(focusFont)
                            .tracking(focusTracking)
                            .foregroundColor(textColor.opacity(0.36))
                            .padding(.bottom, 16)
                    }

                    Text(snapshot.mantra)
                        .font(mantraFont)
                        .lineSpacing(mantraLineSpacing)
                        .multilineTextAlignment(.center)
                        .foregroundColor(textColor.opacity(0.94))
                        .padding(.horizontal, 44)
                        .fixedSize(horizontal: false, vertical: true)

                    if snapshot.score > 0 {
                        VStack(spacing: 10) {
                            HStack(spacing: 5) {
                                ForEach(0..<5, id: \.self) { i in
                                    FourPointStarShape()
                                        .fill(i < filledStarCount
                                              ? textColor.opacity(0.84)
                                              : textColor.opacity(0.18))
                                        .frame(width: 9, height: 9)
                                }
                            }
                            if !keywordLine.isEmpty {
                                Text(keywordLine)
                                    .font(keywordFont)
                                    .tracking(0.6)
                                    .foregroundColor(textColor.opacity(0.50))
                            }
                        }
                        .padding(.top, 28)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text(dateLine)
                        if !snapshot.locationName.isEmpty {
                            Text("·")
                                .foregroundColor(textColor.opacity(0.18))
                            Text(snapshot.locationName)
                        }
                    }
                    .font(.custom("Merriweather-Light", size: 10))
                    .tracking(0.4)
                    .foregroundColor(textColor.opacity(0.30))

                    HStack(spacing: 5) {
                        if UIImage(named: "alignaSymbol") != nil {
                            Image("alignaSymbol")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundColor(textColor.opacity(0.46))
                        } else {
                            FourPointStarShape()
                                .fill(textColor.opacity(0.46))
                                .frame(width: 10, height: 10)
                        }
                        Text("Alynna")
                            .font(.custom("Merriweather-Regular", size: 11))
                            .tracking(2.0)
                            .foregroundColor(textColor.opacity(0.46))
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 46)
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
}
