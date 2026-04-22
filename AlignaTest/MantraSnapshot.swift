import Foundation

struct MantraSnapshot: Codable, Equatable {
    let mantra: String
    let colorHex: String
    let score: Int
    let keywords: [String]
    let focusId: String?
    let focusName: String
    let locationName: String
    let weatherCondition: String
    let environmentSummary: String
    let sunSign: String
    let moonSign: String
    let risingSign: String
    let date: Date
    let localeCode: String

    var isChinese: Bool { localeCode == "zh-Hans" }
}
