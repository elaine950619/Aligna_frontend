import Foundation

struct RecommendationItem: Codable {
    var name: String
    var title: String
    var description: String
    var explanation: String
    let about: String?
    let notice: String?
    let anchor: String?
    let link: String?
    let stone: String?
    let candle: String?
}
