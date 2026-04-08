import Foundation
import WidgetKit

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
private let widgetAppGroupID = "group.martinyuan.AlynnaTest"

enum AlynnaWidgetStore {
    static func load() -> AlynnaWidgetSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: widgetAppGroupID),
            let data = defaults.data(forKey: widgetSnapshotKey),
            let snapshot = try? JSONDecoder().decode(AlynnaWidgetSnapshot.self, from: data)
        else {
            return nil
        }

        return snapshot
    }
}
