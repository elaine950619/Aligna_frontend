import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct AlignaEntry: TimelineEntry {
    let date: Date
    let snapshot: AlignaWidgetSnapshot
}

// MARK: - Provider
struct AlignaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlignaEntry {
        AlignaEntry(
            date: Date(),
            snapshot: AlignaWidgetSnapshot(
                mantra: "Embrace the flow of change.",
                colorTitle: "Vitality Pink",
                placeTitle: "Window seat at a café",
                gemstoneTitle: "Rose Quartz",
                scentTitle: "Rose Breeze"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AlignaEntry) -> Void) {
        let snap = AlignaWidgetStore.load() ?? placeholder(in: context).snapshot
        completion(AlignaEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlignaEntry>) -> Void) {
        let snap = AlignaWidgetStore.load() ?? placeholder(in: context).snapshot
        // 每天凌晨 00:05 之后刷新一次（也可更短）
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) + 1
        let next = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(3600*24)
        let refresh = Calendar.current.date(byAdding: .minute, value: 5, to: next) ?? next

        let entry = AlignaEntry(date: Date(), snapshot: snap)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - UI
struct AlignaWidgetEntryView: View {
    var entry: AlignaProvider.Entry

    var body: some View {
        ZStack {
            // 简洁的夜色背景（与 App 调性一致）
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.black.opacity(0.75)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {

                // 顶部行：左-ALIGNA / 右-月相
                HStack(alignment: .firstTextBaseline) {
                    Text("ALIGNA")
                        .font(.caption2.weight(.semibold))
                        .kerning(1.0)
                        .foregroundColor(Color(hex: "#E6D9BD").opacity(0.95))

                    Spacer()

                    Text(moonPhaseLabel(for: Date()))
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#E6D9BD").opacity(0.9))
                }

                // 中部 Daily Mantra（最多 3 行）
                Text("“\(entry.snapshot.mantra)”")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundColor(Color(hex: "#E6D9BD"))
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .padding(.top, 2)
                    .padding(.bottom, 2)

                Spacer(minLength: 2)

                // 底部四项：Color / Place / Gemstone / Scent
                HStack(spacing: 10) {
                    Item(icon: "paintpalette", text: entry.snapshot.colorTitle)
                    Item(icon: "mappin.and.ellipse", text: entry.snapshot.placeTitle)
                }
                HStack(spacing: 10) {
                    Item(icon: "diamond", text: entry.snapshot.gemstoneTitle)
                    Item(icon: "wind", text: entry.snapshot.scentTitle)
                }
            }
            .padding(14)
        }
        // 点击整个 widget 打开 App（可加深链到某页）
        .widgetURL(URL(string: "aligna://open"))
    }

    // 小条目
    @ViewBuilder
    private func Item(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color(hex: "#D4A574"))
            Text(text)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(Color(hex: "#E6D9BD").opacity(0.9))
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 入口
@main
struct AlignaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlignaWidget", provider: AlignaProvider()) { entry in
            AlignaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Aligna Daily")
        .description("Daily mantra with color, place, gemstone and scent.")
        .supportedFamilies([.systemMedium]) // 你这版要“长方形”，即中号
    }
}
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
}
