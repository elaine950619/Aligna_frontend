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
                mantra: "Embrace the flow of change.",
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
        let backgroundColor = Color(hex: resolvedBackgroundHex)
        let primaryTextColor = contrastTextColor(for: resolvedBackgroundHex)
        let secondaryTextColor = primaryTextColor.opacity(0.9)
        let iconColor = primaryTextColor.opacity(0.88)

        return ZStack {
            VStack(alignment: .leading, spacing: 8) {

                // 顶部行：左-ALYNNA / 右-月相
                HStack(alignment: .firstTextBaseline) {
                    Text("ALYNNA")
                        .font(.caption2.weight(.semibold))
                        .kerning(1.0)
                        .foregroundColor(secondaryTextColor)

                    Spacer()

                    Text(moonPhaseLabel(for: entry.date))
                        .font(.caption2)
                        .foregroundColor(secondaryTextColor)
                }

                // 中部 Daily Mantra（最多 3 行）
                Text("“\(entry.snapshot.mantra)”")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundColor(primaryTextColor)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 2)
                    .padding(.bottom, 2)

                Spacer(minLength: 2)

                // 底部四项：Color / Place / Gemstone / Scent
                HStack(spacing: 10) {
                    Item(icon: "paintpalette", text: entry.snapshot.colorTitle, iconColor: iconColor, textColor: secondaryTextColor)
                    Item(icon: "mappin.and.ellipse", text: entry.snapshot.placeTitle, iconColor: iconColor, textColor: secondaryTextColor)
                }
                HStack(spacing: 10) {
                    Item(icon: "diamond", text: entry.snapshot.gemstoneTitle, iconColor: iconColor, textColor: secondaryTextColor)
                    Item(icon: "wind", text: entry.snapshot.scentTitle, iconColor: iconColor, textColor: secondaryTextColor)
                }
            }
            .padding(14)
        }
        .containerBackground(for: .widget) {
            backgroundColor
        }
        // 点击整个 widget 打开 App（可加深链到某页）
        .widgetURL(URL(string: "Alynna://open"))
    }

    // 小条目
    @ViewBuilder
    private func Item(icon: String, text: String, iconColor: Color, textColor: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(iconColor)
            Text(text)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(textColor)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func contrastTextColor(for hex: String) -> Color {
    return Color.isLightHex(hex) ? .black : .white
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
        .supportedFamilies([.systemMedium]) // 你这版要“长方形”，即中号
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
}
