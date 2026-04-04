import Foundation
import WidgetKit
#if DEBUG
import SwiftUI
#endif

// 1) 你的 App Group ID（务必改成自己的）
public enum AlynnaAppGroup {
    public static let id = "group.martinyuan.AlynnaTest"
}

// 2) Widget 需要的最小数据
public struct AlynnaWidgetSnapshot: Codable, Hashable {
    public var savedAt: Date
    public var mantra: String

    // 四个底部条目（仅标题文字即可；图标在 Widget 侧用 SF Symbols 或同名 Asset）
    public var colorTitle: String
    public var colorHex: String?
    public var placeTitle: String
    public var gemstoneTitle: String
    public var scentTitle: String

    public init(mantra: String,
                colorTitle: String,
                colorHex: String? = nil,
                placeTitle: String,
                gemstoneTitle: String,
                scentTitle: String,
                savedAt: Date = Date()) {
        self.savedAt = savedAt
        self.mantra = mantra
        self.colorTitle = colorTitle
        self.colorHex = colorHex
        self.placeTitle = placeTitle
        self.gemstoneTitle = gemstoneTitle
        self.scentTitle = scentTitle
    }
}

// 3) 读写工具
private let kSnapshotKey = "alynna.widget.snapshot"

public enum AlynnaWidgetStore {
    public static func save(_ snap: AlynnaWidgetSnapshot) {
        guard let ud = UserDefaults(suiteName: AlynnaAppGroup.id) else { return }
        if let data = try? JSONEncoder().encode(snap) {
            ud.set(data, forKey: kSnapshotKey)
            ud.synchronize()
        }
        // 通知所有 Alynna 的 widget 刷新
        WidgetCenter.shared.reloadAllTimelines()
    }

    public static func load() -> AlynnaWidgetSnapshot? {
        guard let ud = UserDefaults(suiteName: AlynnaAppGroup.id),
              let data = ud.data(forKey: kSnapshotKey),
              let snap = try? JSONDecoder().decode(AlynnaWidgetSnapshot.self, from: data) else {
            return nil
        }
        return snap
    }
}

// 4) 月相（与首页同逻辑）
public func moonPhaseLabel(for date: Date = Date()) -> String {
    let synodic: Double = 29.53058867
    var comps = DateComponents()
    comps.calendar = Calendar(identifier: .gregorian)
    comps.timeZone = TimeZone(secondsFromGMT: 0)
    comps.year = 2000; comps.month = 1; comps.day = 6; comps.hour = 18; comps.minute = 14
    let anchor = comps.date!

    let days = date.timeIntervalSince(anchor) / 86400
    let phase = days - floor(days / synodic) * synodic
    switch phase {
    case 0..<1.84566:        return "New Moon"
    case 1.84566..<5.53699:  return "Waxing Crescent"
    case 5.53699..<9.22831:  return "First Quarter"
    case 9.22831..<12.91963: return "Waxing Gibbous"
    case 12.91963..<16.61096:return "Full Moon"
    case 16.61096..<20.30228:return "Waning Gibbous"
    case 20.30228..<23.99361:return "Third Quarter"
    case 23.99361..<27.68493:return "Waning Crescent"
    default:                 return "New Moon"
    }
}
#if DEBUG
private struct AlynnaWidgetSharedPreviewCard: View {
    let snapshot = AlynnaWidgetSnapshot(
        mantra: "Breathe. Align. Begin again.",
        colorTitle: "Amber",
        colorHex: "#FFBF00",
        placeTitle: "Botanical Garden",
        gemstoneTitle: "Amethyst",
        scentTitle: "Bergamot"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Widget Snapshot")
                .font(.headline)

            Text(snapshot.mantra)
                .font(.title3)
                .italic()

            Text(moonPhaseLabel(for: snapshot.savedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Color: \(snapshot.colorTitle)")
                Text("Place: \(snapshot.placeTitle)")
                Text("Gemstone: \(snapshot.gemstoneTitle)")
                Text("Scent: \(snapshot.scentTitle)")
            }
            .font(.body)

            Text("App Group: \(AlynnaAppGroup.id)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding()
    }
}

#Preview("Widget Shared") {
    AlynnaWidgetSharedPreviewCard()
}
#endif

