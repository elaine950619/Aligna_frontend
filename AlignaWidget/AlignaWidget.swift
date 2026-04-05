import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct AlynnaEntry: TimelineEntry {
    let date: Date
    let snapshot: AlynnaWidgetSnapshot
}

// MARK: - Provider
struct AlynnaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlynnaEntry {
        AlynnaEntry(
            date: Date(),
            snapshot: AlynnaWidgetSnapshot(
                mantra: "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care",
                colorTitle: "Vitality Pink",
                colorHex: "#FF66CC",
                placeTitle: "Window seat at a café",
                gemstoneTitle: "Rose Quartz",
                scentTitle: "Rose Breeze"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AlynnaEntry) -> Void) {
        let snap = AlynnaWidgetStore.load() ?? placeholder(in: context).snapshot
        completion(AlynnaEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlynnaEntry>) -> Void) {
        let snap = AlynnaWidgetStore.load() ?? placeholder(in: context).snapshot
        // 每天凌晨 00:05 之后刷新一次（也可更短）
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) + 1
        let next = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(3600*24)
        let refresh = Calendar.current.date(byAdding: .minute, value: 5, to: next) ?? next

        let entry = AlynnaEntry(date: Date(), snapshot: snap)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - UI
struct AlynnaWidgetEntryView: View {
    var entry: AlynnaProvider.Entry

    var body: some View {
        let backgroundHex = entry.snapshot.colorHex?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBackgroundHex = (backgroundHex?.isEmpty == false) ? backgroundHex! : "#151515"
        let textColor = Color(hex: "#F7F3EC")
        let trimmedMantra = entry.snapshot.mantra.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayMantra = trimmedMantra.isEmpty
            ? "Today is not about perfection. It is about noticing small moments."
            : trimmedMantra

        return GeometryReader { geometry in
            VStack {
                ViewThatFits(in: .vertical) {
                    mantraText(displayMantra, size: min(geometry.size.width, geometry.size.height) * 0.15)
                    mantraText(displayMantra, size: min(geometry.size.width, geometry.size.height) * 0.135)
                    mantraText(displayMantra, size: min(geometry.size.width, geometry.size.height) * 0.12)
                }
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.6)
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: geometry.size.height * 0.66,
                    alignment: .center
                )
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

                Spacer(minLength: geometry.size.height * 0.34)
            }
            .padding(16)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .containerBackground(for: .widget) {
            WidgetBackground(hex: resolvedBackgroundHex)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "Alynna://open"))
    }
}

private func mantraText(_ text: String, size: CGFloat) -> some View {
    Text(text)
        .font(.system(size: size, weight: .semibold, design: .serif))
}

private struct WidgetBackground: View {
    let hex: String

    var body: some View {
        GeometryReader { geometry in
            let top = Color.adjusted(from: hex, darken: 0.12, desaturate: 0.12) ?? Color(hex: hex)
            let bottom = Color.adjusted(from: hex, darken: 0.22, desaturate: 0.16) ?? Color(hex: hex)
            let base = Color.adjusted(from: hex, darken: 0.18, desaturate: 0.14) ?? Color(hex: hex)

            ZStack {
                base
                LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.06), Color.clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: min(geometry.size.width, geometry.size.height) * 0.8
                )
                RadialGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.22)]),
                    center: .center,
                    startRadius: min(geometry.size.width, geometry.size.height) * 0.25,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.9
                )

                WidgetGrainLayer(size: geometry.size)
                    .blendMode(.softLight)
                    .opacity(0.05)
            }
            .ignoresSafeArea()
        }
    }
}

private struct WidgetGrainLayer: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let count = 120
            for index in 0..<count {
                let x = unit(Double(index) * 12.9898) * canvasSize.width
                let y = unit(Double(index) * 78.233) * canvasSize.height
                let r = 0.5 + unit(Double(index) * 45.164) * 0.8
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(0.09))
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func unit(_ seed: Double) -> Double {
        let value = abs(sin(seed) * 43758.5453)
        return value - floor(value)
    }
}

// MARK: - 入口
@main
struct AlynnaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlynnaWidget", provider: AlynnaProvider()) { entry in
            AlynnaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Alynna Daily")
        .description("Daily mantra with color, place, gemstone and scent.")
        .supportedFamilies([.systemMedium])
    }
}

#if DEBUG
struct AlynnaWidget_Previews: PreviewProvider {
    static var previews: some View {
        AlynnaWidgetEntryView(
            entry: AlynnaEntry(
                date: Date(),
                snapshot: AlynnaWidgetSnapshot(
                    mantra: "Embrace the flow of change.",
                    colorTitle: "Vitality Pink",
                    colorHex: "#FF66CC",
                    placeTitle: "Window seat at a café",
                    gemstoneTitle: "Rose Quartz",
                    scentTitle: "Rose Breeze"
                )
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
#endif

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    static func isLightHex(_ hex: String) -> Bool {
        guard let rgb = rgbComponents(from: hex) else { return false }
        let r = linearized(rgb.r)
        let g = linearized(rgb.g)
        let b = linearized(rgb.b)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.6
    }

    static func adjusted(from hex: String, darken: Double, desaturate: Double) -> Color? {
        guard let rgb = rgbComponents(from: hex) else { return nil }
        let avg = (rgb.r + rgb.g + rgb.b) / 3.0

        let desatR = rgb.r * (1 - desaturate) + avg * desaturate
        let desatG = rgb.g * (1 - desaturate) + avg * desaturate
        let desatB = rgb.b * (1 - desaturate) + avg * desaturate

        let darkenFactor = max(0.0, min(1.0, 1.0 - darken))
        let r = clamp(desatR * darkenFactor)
        let g = clamp(desatG * darkenFactor)
        let b = clamp(desatB * darkenFactor)

        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }

    private static func rgbComponents(from hex: String) -> (r: Double, g: Double, b: Double)? {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }

        let r, g, b: UInt64
        switch hex.count {
        case 3:
            r = (int >> 8) * 17
            g = (int >> 4 & 0xF) * 17
            b = (int & 0xF) * 17
        case 6:
            r = int >> 16
            g = int >> 8 & 0xFF
            b = int & 0xFF
        case 8:
            r = int >> 16 & 0xFF
            g = int >> 8 & 0xFF
            b = int & 0xFF
        default:
            return nil
        }

        return (Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }

    private static func linearized(_ c: Double) -> Double {
        return (c <= 0.03928) ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
