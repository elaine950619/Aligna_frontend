import Foundation
import WidgetKit

enum AlynnaAppGroup {
    static let id = "group.martinyuan.AlynnaTest"
}

struct AlynnaWidgetSnapshot: Codable, Hashable {
    var savedAt: Date
    var mantra: String
    var colorTitle: String
    var colorHex: String?
    var placeTitle: String
    var gemstoneTitle: String
    var scentTitle: String

    init(
        mantra: String,
        colorTitle: String,
        colorHex: String? = nil,
        placeTitle: String,
        gemstoneTitle: String,
        scentTitle: String,
        savedAt: Date = Date()
    ) {
        self.savedAt = savedAt
        self.mantra = mantra
        self.colorTitle = colorTitle
        self.colorHex = colorHex
        self.placeTitle = placeTitle
        self.gemstoneTitle = gemstoneTitle
        self.scentTitle = scentTitle
    }
}

private let widgetSnapshotKey = "alynna.widget.snapshot"

enum AlynnaWidgetStore {
    static func save(_ snapshot: AlynnaWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: AlynnaAppGroup.id) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        defaults.set(data, forKey: widgetSnapshotKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> AlynnaWidgetSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: AlynnaAppGroup.id),
            let data = defaults.data(forKey: widgetSnapshotKey),
            let snapshot = try? JSONDecoder().decode(AlynnaWidgetSnapshot.self, from: data)
        else {
            return nil
        }

        return snapshot
    }
}

func moonPhaseLabel(for date: Date = Date()) -> String {
    let synodicMonth = 29.53058867
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = 2000
    components.month = 1
    components.day = 6
    components.hour = 18
    components.minute = 14

    guard let anchorDate = components.date else {
        return "New Moon"
    }

    let days = date.timeIntervalSince(anchorDate) / 86400
    let phase = days - floor(days / synodicMonth) * synodicMonth

    switch phase {
    case 0..<1.84566:
        return "New Moon"
    case 1.84566..<5.53699:
        return "Waxing Crescent"
    case 5.53699..<9.22831:
        return "First Quarter"
    case 9.22831..<12.91963:
        return "Waxing Gibbous"
    case 12.91963..<16.61096:
        return "Full Moon"
    case 16.61096..<20.30228:
        return "Waning Gibbous"
    case 20.30228..<23.99361:
        return "Third Quarter"
    case 23.99361..<27.68493:
        return "Waning Crescent"
    default:
        return "New Moon"
    }
}
