import Foundation
import WidgetKit
import SwiftUI
import AppIntents
import UIKit

struct AlynnaWidgetSnapshot: Codable, Hashable {
    var savedAt: Date
    var mantra: String
    var locationName: String
    var sunSign: String
    var moonSign: String
    var risingSign: String
    var weatherSummary: String
    var weatherDetailSummary: String
    var environmentSummary: String
    var soundKey: String
    var soundTitle: String
    var colorKey: String
    var colorTitle: String
    var colorHex: String?
    var placeKey: String
    var placeTitle: String
    var gemstoneKey: String
    var gemstoneTitle: String
    var scentKey: String
    var scentTitle: String
    var activityKey: String
    var activityTitle: String
    var careerKey: String
    var careerTitle: String
    var relationshipKey: String
    var relationshipTitle: String
    var categoryReasoning: [String: String]
    var reasoningSummary: String

    init(
        mantra: String,
        locationName: String = "",
        sunSign: String = "",
        moonSign: String = "",
        risingSign: String = "",
        weatherSummary: String = "",
        weatherDetailSummary: String = "",
        environmentSummary: String = "",
        soundKey: String = "",
        soundTitle: String = "",
        colorKey: String = "",
        colorTitle: String,
        colorHex: String? = nil,
        placeKey: String = "",
        placeTitle: String,
        gemstoneKey: String = "",
        gemstoneTitle: String,
        scentKey: String = "",
        scentTitle: String,
        activityKey: String = "",
        activityTitle: String = "",
        careerKey: String = "",
        careerTitle: String = "",
        relationshipKey: String = "",
        relationshipTitle: String = "",
        categoryReasoning: [String: String] = [:],
        reasoningSummary: String = "",
        savedAt: Date = Date()
    ) {
        self.savedAt = savedAt
        self.mantra = mantra
        self.locationName = locationName
        self.sunSign = sunSign
        self.moonSign = moonSign
        self.risingSign = risingSign
        self.weatherSummary = weatherSummary
        self.weatherDetailSummary = weatherDetailSummary
        self.environmentSummary = environmentSummary
        self.soundKey = soundKey
        self.soundTitle = soundTitle
        self.colorKey = colorKey
        self.colorTitle = colorTitle
        self.colorHex = colorHex
        self.placeKey = placeKey
        self.placeTitle = placeTitle
        self.gemstoneKey = gemstoneKey
        self.gemstoneTitle = gemstoneTitle
        self.scentKey = scentKey
        self.scentTitle = scentTitle
        self.activityKey = activityKey
        self.activityTitle = activityTitle
        self.careerKey = careerKey
        self.careerTitle = careerTitle
        self.relationshipKey = relationshipKey
        self.relationshipTitle = relationshipTitle
        self.categoryReasoning = categoryReasoning
        self.reasoningSummary = reasoningSummary
    }
}

private struct WidgetAssetImage: View {
    let name: String

    var body: some View {
        if let uiImage = widgetThumbnailImage(named: name) {
            Image(uiImage: uiImage)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "questionmark.square.dashed")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(0.55)
        }
    }
}

private func widgetThumbnailImage(named name: String, maxPixelDimension: CGFloat = 640) -> UIImage? {
    guard let image = UIImage(named: name) else { return nil }

    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    let largestDimension = max(pixelWidth, pixelHeight)

    guard largestDimension > maxPixelDimension else { return image }

    let scaleRatio = maxPixelDimension / largestDimension
    let scaledSize = CGSize(
        width: max(1, floor(pixelWidth * scaleRatio)),
        height: max(1, floor(pixelHeight * scaleRatio))
    )

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = false

    return UIGraphicsImageRenderer(size: scaledSize, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: scaledSize))
    }
}

private let widgetSnapshotKey = "alynna.widget.snapshot"
private let widgetAppGroupID = "group.martinyuan.AlynnaTest"

// MARK: - Language helpers (widget-local, no dependency on main app target)

/// Returns true when the user has selected Chinese in the app or system language is Chinese.
private func widgetIsChinese() -> Bool {
    // First check the app-level language setting stored in the shared App Group defaults.
    if let defaults = UserDefaults(suiteName: widgetAppGroupID),
       let lang = defaults.string(forKey: "appLanguage"),
       !lang.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return lang.lowercased().hasPrefix("zh")
    }
    // Fall back to the system preferred language.
    let preferred = (Locale.preferredLanguages.first ?? "").lowercased()
    return preferred.hasPrefix("zh")
}

private func widgetCategoryLabel(_ english: String) -> String {
    guard widgetIsChinese() else { return english }
    switch english.lowercased() {
    case "place":        return "地点"
    case "gemstone":     return "宝石"
    case "color":        return "色彩"
    case "scent":        return "香气"
    case "activity":     return "活动"
    case "sound":        return "声音"
    case "career":       return "事业"
    case "relationship": return "关系"
    default:             return english
    }
}

private func widgetZodiacName(_ english: String) -> String {
    guard widgetIsChinese() else { return english }
    switch english.lowercased() {
    case "aries":       return "白羊"
    case "taurus":      return "金牛"
    case "gemini":      return "双子"
    case "cancer":      return "巨蟹"
    case "leo":         return "狮子"
    case "virgo":       return "处女"
    case "libra":       return "天秤"
    case "scorpio":     return "天蝎"
    case "sagittarius": return "射手"
    case "capricorn":   return "摩羯"
    case "aquarius":    return "水瓶"
    case "pisces":      return "双鱼"
    default:            return english
    }
}

private func widgetMoonPhaseName(_ english: String) -> String {
    guard widgetIsChinese() else { return english }
    switch english {
    case "New Moon":        return "新月"
    case "Waxing Crescent": return "娥眉月"
    case "First Quarter":   return "上弦月"
    case "Waxing Gibbous":  return "盈凸月"
    case "Full Moon":       return "满月"
    case "Waning Gibbous":  return "亏凸月"
    case "Third Quarter":   return "下弦月"
    case "Waning Crescent": return "残月"
    default:                return english
    }
}
private let widgetSmallCategoryOverrideKeyPrefix = "widgetSmallCategoryOverride."
private let widgetSmallShowsBackKeyPrefix = "widgetSmallShowsBack."
private let widgetMediumShowsBackKey = "widgetMediumShowsBack"

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

enum AlynnaSmallCategoryStore {
    static func load(baseCategory: WidgetRecommendationCategory) -> WidgetRecommendationCategory {
        guard
            let defaults = UserDefaults(suiteName: widgetAppGroupID),
            let rawValue = defaults.string(forKey: key(for: baseCategory)),
            let storedCategory = WidgetRecommendationCategory(rawValue: rawValue)
        else {
            return baseCategory
        }

        return storedCategory
    }

    static func save(_ category: WidgetRecommendationCategory, baseCategory: WidgetRecommendationCategory) {
        guard let defaults = UserDefaults(suiteName: widgetAppGroupID) else { return }
        defaults.set(category.rawValue, forKey: key(for: baseCategory))
    }

    private static func key(for baseCategory: WidgetRecommendationCategory) -> String {
        widgetSmallCategoryOverrideKeyPrefix + baseCategory.storageKeySuffix
    }
}

enum AlynnaSmallFaceStore {
    static func load(baseCategory: WidgetRecommendationCategory) -> Bool {
        guard let defaults = UserDefaults(suiteName: widgetAppGroupID) else { return false }
        return defaults.bool(forKey: key(for: baseCategory))
    }

    static func save(_ showsBack: Bool, baseCategory: WidgetRecommendationCategory) {
        guard let defaults = UserDefaults(suiteName: widgetAppGroupID) else { return }
        defaults.set(showsBack, forKey: key(for: baseCategory))
    }

    static func toggle(baseCategory: WidgetRecommendationCategory) {
        save(!load(baseCategory: baseCategory), baseCategory: baseCategory)
    }

    private static func key(for baseCategory: WidgetRecommendationCategory) -> String {
        widgetSmallShowsBackKeyPrefix + baseCategory.storageKeySuffix
    }
}

enum AlynnaMediumFaceStore {
    static func load() -> Bool {
        guard let defaults = UserDefaults(suiteName: widgetAppGroupID) else { return false }
        return defaults.bool(forKey: widgetMediumShowsBackKey)
    }

    static func toggle() {
        guard let defaults = UserDefaults(suiteName: widgetAppGroupID) else { return }
        defaults.set(!defaults.bool(forKey: widgetMediumShowsBackKey), forKey: widgetMediumShowsBackKey)
    }
}

// MARK: - Timeline Entry
struct AlynnaEntry: TimelineEntry {
    let date: Date
    let snapshot: AlynnaWidgetSnapshot
    let showsBack: Bool
}

enum WidgetRecommendationCategory: String, AppEnum, CaseIterable {
    case place = "Place"
    case gemstone = "Gemstone"
    case color = "Color"
    case scent = "Scent"
    case activity = "Activity"
    case sound = "Sound"
    case career = "Career"
    case relationship = "Relationship"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "推荐类别"

    static var caseDisplayRepresentations: [WidgetRecommendationCategory: DisplayRepresentation] = [
        .place: "地点",
        .gemstone: "宝石",
        .color: "色彩",
        .scent: "香气",
        .activity: "活动",
        .sound: "声音",
        .career: "事业",
        .relationship: "关系"
    ]

    var storageKeySuffix: String {
        rawValue.lowercased()
    }
}

struct SelectRecommendationCategoryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Recommendation"
    static var description = IntentDescription("Select which daily recommendation category appears in the square widget.")

    @Parameter(title: "Category", default: .gemstone)
    var category: WidgetRecommendationCategory

    init() { }

    init(category: WidgetRecommendationCategory) {
        self.category = category
    }
}

struct CycleSmallRecommendationCategoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Recommendation Category"

    @Parameter(title: "Current Category")
    var currentCategory: WidgetRecommendationCategory

    @Parameter(title: "Base Category")
    var baseCategory: WidgetRecommendationCategory

    init() { }

    init(currentCategory: WidgetRecommendationCategory, baseCategory: WidgetRecommendationCategory) {
        self.currentCategory = currentCategory
        self.baseCategory = baseCategory
    }

    func perform() async throws -> some IntentResult {
        let allCategories = WidgetRecommendationCategory.allCases
        guard let currentIndex = allCategories.firstIndex(of: currentCategory) else {
            AlynnaSmallCategoryStore.save(baseCategory, baseCategory: baseCategory)
            AlynnaSmallFaceStore.save(false, baseCategory: baseCategory)
            WidgetCenter.shared.reloadTimelines(ofKind: "AlynnaRecommendationWidget")
            return .result()
        }

        let nextIndex = allCategories.index(after: currentIndex)
        let nextCategory = nextIndex == allCategories.endIndex ? allCategories[allCategories.startIndex] : allCategories[nextIndex]
        AlynnaSmallCategoryStore.save(nextCategory, baseCategory: baseCategory)
        AlynnaSmallFaceStore.save(false, baseCategory: baseCategory)
        WidgetCenter.shared.reloadTimelines(ofKind: "AlynnaRecommendationWidget")
        return .result()
    }
}

struct ToggleSmallRecommendationFaceIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Recommendation Details"

    @Parameter(title: "Base Category")
    var baseCategory: WidgetRecommendationCategory

    init() { }

    init(baseCategory: WidgetRecommendationCategory) {
        self.baseCategory = baseCategory
    }

    func perform() async throws -> some IntentResult {
        AlynnaSmallFaceStore.toggle(baseCategory: baseCategory)
        WidgetCenter.shared.reloadTimelines(ofKind: "AlynnaRecommendationWidget")
        return .result()
    }
}

struct ToggleMediumRecommendationFaceIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Daily Insight"

    init() { }

    func perform() async throws -> some IntentResult {
        AlynnaMediumFaceStore.toggle()
        WidgetCenter.shared.reloadTimelines(ofKind: "AlynnaMediumWidget")
        return .result()
    }
}

// MARK: - Provider
struct AlynnaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlynnaEntry {
        AlynnaEntry(
            date: Date(),
            snapshot: AlynnaWidgetSnapshot(
                mantra: "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care",
                locationName: "Brooklyn",
                sunSign: "Virgo",
                moonSign: "Pisces",
                risingSign: "Libra",
                weatherSummary: "Cool, rainy",
                weatherDetailSummary: "Wind 8 Mph · Humidity 63%",
                environmentSummary: "Mostly green with quiet urban edges",
                soundKey: "ocean_waves",
                soundTitle: "Ocean Waves",
                colorKey: "vitality_pink",
                colorTitle: "Vitality Pink",
                colorHex: "#FF66CC",
                placeKey: "window_seat_at_a_cafe",
                placeTitle: "Window seat at a café",
                gemstoneKey: "rose_quartz",
                gemstoneTitle: "Rose Quartz",
                scentKey: "rose_breeze",
                scentTitle: "Rose Breeze",
                activityKey: "clean_mirror",
                activityTitle: "Clean Mirror",
                careerKey: "clear_channel",
                careerTitle: "Clear Channel",
                relationshipKey: "breathe_sync",
                relationshipTitle: "Breathe Sync",
                reasoningSummary: "Today asks for steadiness over perfection. Your recommendations point toward quieter rituals, clearer pacing, and choices that keep your nervous system supported."
            ),
            showsBack: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AlynnaEntry) -> Void) {
        let snap = AlynnaWidgetStore.load() ?? placeholder(in: context).snapshot
        completion(AlynnaEntry(date: Date(), snapshot: snap, showsBack: AlynnaMediumFaceStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlynnaEntry>) -> Void) {
        let snap = AlynnaWidgetStore.load() ?? placeholder(in: context).snapshot
        // 每天凌晨 00:05 之后刷新一次（也可更短）
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) + 1
        let next = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(3600*24)
        let refresh = Calendar.current.date(byAdding: .minute, value: 5, to: next) ?? next

        let entry = AlynnaEntry(date: Date(), snapshot: snap, showsBack: AlynnaMediumFaceStore.load())
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct AlynnaSmallEntry: TimelineEntry {
    let date: Date
    let snapshot: AlynnaWidgetSnapshot
    let baseCategory: WidgetRecommendationCategory
    let category: WidgetRecommendationCategory
    let showsBack: Bool
}

struct AlynnaSmallProvider: AppIntentTimelineProvider {
    typealias Intent = SelectRecommendationCategoryIntent

    func placeholder(in context: Context) -> AlynnaSmallEntry {
        AlynnaSmallEntry(
            date: Date(),
            snapshot: AlynnaProvider().placeholder(in: context).snapshot,
            baseCategory: .gemstone,
            category: .gemstone,
            showsBack: false
        )
    }

    func snapshot(for configuration: SelectRecommendationCategoryIntent, in context: Context) async -> AlynnaSmallEntry {
        let resolvedCategory = AlynnaSmallCategoryStore.load(baseCategory: configuration.category)
        return AlynnaSmallEntry(
            date: Date(),
            snapshot: AlynnaWidgetStore.load() ?? AlynnaProvider().placeholder(in: context).snapshot,
            baseCategory: configuration.category,
            category: resolvedCategory,
            showsBack: AlynnaSmallFaceStore.load(baseCategory: configuration.category)
        )
    }

    func timeline(for configuration: SelectRecommendationCategoryIntent, in context: Context) async -> Timeline<AlynnaSmallEntry> {
        let snapshot = AlynnaWidgetStore.load() ?? AlynnaProvider().placeholder(in: context).snapshot
        let resolvedCategory = AlynnaSmallCategoryStore.load(baseCategory: configuration.category)
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) + 1
        let next = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(3600 * 24)
        let refresh = Calendar.current.date(byAdding: .minute, value: 5, to: next) ?? next
        let entry = AlynnaSmallEntry(
            date: Date(),
            snapshot: snapshot,
            baseCategory: configuration.category,
            category: resolvedCategory,
            showsBack: AlynnaSmallFaceStore.load(baseCategory: configuration.category)
        )
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

struct ToggleWidgetSoundIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Toggle Widget Sound"

    @Parameter(title: "Sound Key")
    var soundKey: String

    init() { }

    init(soundKey: String) {
        self.soundKey = soundKey
    }

    func perform() async throws -> some IntentResult {
        let trimmedKey = soundKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedKey.isEmpty,
            let defaults = UserDefaults(suiteName: widgetAppGroupID)
        else {
            return .result()
        }

        let currentSoundKey = defaults.string(forKey: "widgetCurrentSoundKey") ?? ""
        let isPlaying = defaults.bool(forKey: "widgetCurrentSoundIsPlaying")
        let nextIsPlaying: Bool

        if currentSoundKey == trimmedKey, isPlaying {
            nextIsPlaying = false
        } else {
            nextIsPlaying = true
        }

        defaults.set(trimmedKey, forKey: "widgetCurrentSoundKey")
        defaults.set(nextIsPlaying, forKey: "widgetCurrentSoundIsPlaying")
        defaults.synchronize()

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - UI
struct AlynnaWidgetEntryView: View {
    var entry: AlynnaProvider.Entry

    var body: some View {
        let backgroundHex = entry.snapshot.colorHex?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBackgroundHex = (backgroundHex?.isEmpty == false) ? backgroundHex! : "#151515"
        let textColor = Color(hex: "#F7F3EC")
        let secondaryTextColor = textColor.opacity(0.74)
        let displayMantra = widgetMantra(entry.snapshot.mantra)
        let topLine = widgetHeaderLine(date: entry.snapshot.savedAt, location: entry.snapshot.locationName)
        let phaseText = widgetMoonPhaseName(moonPhaseLabel(for: entry.snapshot.savedAt))
        let airQualityText = widgetAirQualityText()
        let footerItems = widgetFooterItems(
            weather: entry.snapshot.weatherSummary,
            weatherDetail: entry.snapshot.weatherDetailSummary,
            environment: entry.snapshot.environmentSummary,
            airQuality: airQualityText
        )
        let audioState = WidgetAudioState.load()
        let isSoundPlaying = audioState.isPlaying && audioState.currentSoundKey == entry.snapshot.soundKey
        let soundSymbol = soundSymbolName(for: entry.snapshot.soundKey, title: entry.snapshot.soundTitle)
        let soundArtworkName = soundArtworkAssetName(for: entry.snapshot.soundKey, title: entry.snapshot.soundTitle)
        let reasoningFallback = widgetIsChinese()
            ? "今天需要的是稳定，而非完美。让这些推荐支持你放慢节奏、做出清晰的选择，保持平静的状态。"
            : "Today asks for steadiness over perfection. Let the recommendations support slower pacing, clearer choices, and a calmer nervous system."
        let reasoningSummary = entry.snapshot.reasoningSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? reasoningFallback
            : entry.snapshot.reasoningSummary.trimmingCharacters(in: .whitespacesAndNewlines)

        return GeometryReader { geometry in
            let minSide = min(geometry.size.width, geometry.size.height)

            VStack(alignment: .leading, spacing: minSide * 0.02) {
                HStack(alignment: .firstTextBaseline, spacing: minSide * 0.024) {
                    Text(topLine)
                        .font(.custom("Merriweather-Bold", size: minSide * 0.076))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: minSide * 0.014)

                    zodiacHeader(
                        sun: widgetZodiacName(entry.snapshot.sunSign),
                        moon: widgetZodiacName(entry.snapshot.moonSign),
                        rising: widgetZodiacName(entry.snapshot.risingSign),
                        phase: phaseText,
                        color: secondaryTextColor,
                        size: minSide
                    )
                }

                Spacer(minLength: minSide * 0.002)

                if entry.showsBack {
                    Button(intent: ToggleMediumRecommendationFaceIntent()) {
                        VStack(alignment: .leading, spacing: minSide * 0.03) {
                            Spacer(minLength: minSide * 0.02)

                            (
                                Text(widgetIsChinese() ? "为什么今天适合？" : "Why this fits today? ")
                                    .font(.custom("Merriweather-Bold", size: minSide * 0.088))
                                +
                                Text(reasoningSummary)
                                    .font(.custom("Merriweather-Regular", size: minSide * 0.088))
                            )
                                .foregroundStyle(textColor)
                                .multilineTextAlignment(.leading)
                                .lineLimit(6)
                                .minimumScaleFactor(0.82)
                                .lineSpacing(minSide * 0.02)

                            Spacer(minLength: minSide * 0.018)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(alignment: .center, spacing: minSide * 0.034) {
                        soundOrbControl(
                            size: minSide * 0.52,
                            soundKey: entry.snapshot.soundKey,
                            soundTitle: entry.snapshot.soundTitle,
                            artworkName: soundArtworkName,
                            symbolName: soundSymbol,
                            isPlaying: isSoundPlaying
                        )

                        Button(intent: ToggleMediumRecommendationFaceIntent()) {
                            ViewThatFits(in: .vertical) {
                                mantraText(displayMantra, size: minSide * 0.128, isChinese: widgetIsChinese())
                                mantraText(displayMantra, size: minSide * 0.12, isChinese: widgetIsChinese())
                                mantraText(displayMantra, size: minSide * 0.112, isChinese: widgetIsChinese())
                                mantraText(displayMantra, size: minSide * 0.104, isChinese: widgetIsChinese())
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                    .foregroundColor(textColor)
                    .layoutPriority(1)
                    .background {
                        WidgetContentGlow()
                            .padding(.horizontal, -minSide * 0.03)
                            .padding(.vertical, -minSide * 0.02)
                    }

                    Spacer(minLength: minSide * 0.006)

                    if !footerItems.isEmpty {
                        let lineColor = secondaryTextColor
                        let topFooterItems = footerItems.filter { ["Environment", "Weather"].contains($0.label) }
                        let bottomFooterItems = footerItems.filter { ["Air", "Wind", "Humidity", "Pressure"].contains($0.label) }

                        VStack(alignment: .leading, spacing: minSide * 0.01) {
                            if !topFooterItems.isEmpty {
                                ViewThatFits(in: .horizontal) {
                                    footerSegments(topFooterItems, color: lineColor, size: minSide, scale: 0.92)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    footerSegments(topFooterItems, color: lineColor, size: minSide, scale: 0.84)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    footerSegments(Array(topFooterItems.prefix(1)), color: lineColor, size: minSide, scale: 1.0)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            if !bottomFooterItems.isEmpty {
                                ViewThatFits(in: .horizontal) {
                                    footerSegments(bottomFooterItems, color: lineColor, size: minSide, scale: 0.9)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    footerSegments(bottomFooterItems, color: lineColor, size: minSide, scale: 0.82)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    footerSegments(Array(bottomFooterItems.prefix(3)), color: lineColor, size: minSide, scale: 0.9)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    footerSegments(Array(bottomFooterItems.prefix(2)), color: lineColor, size: minSide, scale: 1.0)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.top, minSide * 0.004)
                    }
                }
            }
            .padding(.horizontal, minSide * 0.076)
            .padding(.vertical, minSide * 0.058)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .containerBackground(for: .widget) {
            WidgetBackground(hex: resolvedBackgroundHex)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SmallRecommendationContent {
    let categoryLabel: String
    let title: String
    let imageName: String?
    let symbolName: String?
    let usesColorSwatch: Bool
}

private func smallRecommendationExplanation(
    category: WidgetRecommendationCategory,
    snapshot: AlynnaWidgetSnapshot
) -> String {
    let explanation = snapshot.categoryReasoning[category.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !explanation.isEmpty {
        return explanation
    }

    let zh = widgetIsChinese()
    switch category {
    case .place:
        return zh ? "今天推荐这个地方，帮助你感到脚踏实地。" : "This place was chosen to help you feel grounded and calm today."
    case .color:
        return zh ? "这个色彩支持今天的平衡与清晰感。" : "This color supports balance and clarity based on your current day's tone."
    case .gemstone:
        return zh ? "这块宝石有助于增强直觉和情绪稳定。" : "This gemstone was selected to encourage intuition and emotional steadiness."
    case .scent:
        return zh ? "这种香气有助于放松神经系统，减少过度刺激。" : "This scent aims to relax your nervous system and reduce overstimulation."
    case .sound:
        return zh ? "这个声音为专注或休息创造稳定的背景氛围。" : "This sound is meant to create a steady background for focus or rest."
    case .activity:
        return zh ? "这个活动支持温和的内省与精神重置。" : "This activity supports gentle reflection and mental reset."
    case .career:
        return zh ? "这个提示强调深思熟虑，而非冲动行动。" : "This career cue emphasizes thoughtful decisions over impulsive action."
    case .relationship:
        return zh ? "这个提示鼓励更温柔的沟通与连结。" : "This relationship cue encourages softer communication and connection."
    }
}

private func smallRecommendationContent(
    category: WidgetRecommendationCategory,
    snapshot: AlynnaWidgetSnapshot
) -> SmallRecommendationContent {
    switch category {
    case .place:
        return SmallRecommendationContent(categoryLabel: widgetCategoryLabel("Place"), title: snapshot.placeTitle, imageName: snapshot.placeKey, symbolName: "mappin.and.ellipse", usesColorSwatch: false)
    case .gemstone:
        return SmallRecommendationContent(categoryLabel: widgetCategoryLabel("Gemstone"), title: snapshot.gemstoneTitle, imageName: snapshot.gemstoneKey, symbolName: "sparkles", usesColorSwatch: false)
    case .color:
        return SmallRecommendationContent(categoryLabel: widgetCategoryLabel("Color"), title: snapshot.colorTitle, imageName: nil, symbolName: "circle.lefthalf.filled", usesColorSwatch: true)
    case .scent:
        return SmallRecommendationContent(categoryLabel: widgetCategoryLabel("Scent"), title: snapshot.scentTitle, imageName: snapshot.scentKey, symbolName: "drop.fill", usesColorSwatch: false)
    case .activity:
        return SmallRecommendationContent(categoryLabel: widgetCategoryLabel("Activity"), title: snapshot.activityTitle, imageName: snapshot.activityKey, symbolName: "figure.walk", usesColorSwatch: false)
    case .sound:
        let artworkName = soundArtworkAssetName(for: snapshot.soundKey, title: snapshot.soundTitle)
        return SmallRecommendationContent(categoryLabel: widgetCategoryLabel("Sound"), title: snapshot.soundTitle, imageName: artworkName ?? snapshot.soundKey, symbolName: soundSymbolName(for: snapshot.soundKey, title: snapshot.soundTitle), usesColorSwatch: false)
    case .career:
        return SmallRecommendationContent(categoryLabel: widgetCategoryLabel("Career"), title: snapshot.careerTitle, imageName: snapshot.careerKey, symbolName: "briefcase.fill", usesColorSwatch: false)
    case .relationship:
        return SmallRecommendationContent(categoryLabel: widgetCategoryLabel("Relationship"), title: snapshot.relationshipTitle, imageName: snapshot.relationshipKey, symbolName: "heart.fill", usesColorSwatch: false)
    }
}

struct AlynnaSmallWidgetEntryView: View {
    let entry: AlynnaSmallProvider.Entry

    var body: some View {
        let backgroundHex = entry.snapshot.colorHex?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBackgroundHex = (backgroundHex?.isEmpty == false) ? backgroundHex! : "#151515"
        let content = smallRecommendationContent(category: entry.category, snapshot: entry.snapshot)
        let usesDarkText = Color.isLightHex(resolvedBackgroundHex)
        let primaryText = usesDarkText ? Color.black.opacity(0.82) : Color(hex: "#F7F3EC")
        let topLabelText = usesDarkText ? Color.black.opacity(0.58) : Color(hex: "#F7F3EC").opacity(0.7)
        let bottomTitleText = usesDarkText ? Color.black.opacity(0.92) : Color(hex: "#F7F3EC").opacity(0.98)
        let title = content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? content.categoryLabel : content.title
        let explanation = smallRecommendationExplanation(category: entry.category, snapshot: entry.snapshot)
        let activeDotIndex = min(WidgetRecommendationCategory.allCases.firstIndex(of: entry.category) ?? 0, 7) / 2

        GeometryReader { geometry in
            let minSide = min(geometry.size.width, geometry.size.height)

            VStack(spacing: 0) {
                if entry.showsBack {
                    Button(intent: ToggleSmallRecommendationFaceIntent(baseCategory: entry.baseCategory)) {
                        VStack(spacing: minSide * 0.05) {
                            Spacer(minLength: minSide * 0.1)

                            Text(title)
                                .font(.custom("Merriweather-Black", size: minSide * 0.092))
                                .foregroundStyle(primaryText.opacity(0.92))
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, minSide * 0.08)

                            Text(explanation)
                                .font(.custom("Merriweather-Regular", size: minSide * 0.078))
                                .foregroundStyle(bottomTitleText)
                                .multilineTextAlignment(.center)
                                .lineLimit(6)
                                .minimumScaleFactor(0.82)
                                .lineSpacing(minSide * 0.018)
                                .padding(.horizontal, minSide * 0.08)

                            Spacer(minLength: minSide * 0.12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    let topInset = minSide * 0.075
                    let titleTopGap = minSide * 0.014
                    let dotsTopGap = minSide * 0.008
                    let dotsBottomInset = minSide * 0.02
                    let visualScale = minSide * 0.98

                    VStack(spacing: 0) {
                        Text(widgetIsChinese() ? "今日\(content.categoryLabel)" : "Today's \(content.categoryLabel)")
                            .font(.custom("Merriweather-Bold", size: minSide * 0.072))
                            .foregroundStyle(topLabelText)
                            .lineLimit(1)
                            .padding(.top, topInset)
                            .padding(.horizontal, minSide * 0.06)

                        Spacer(minLength: minSide * 0.008)

                        Button(intent: ToggleSmallRecommendationFaceIntent(baseCategory: entry.baseCategory)) {
                            ZStack {
                                if content.usesColorSwatch {
                                    Circle()
                                        .fill(Color(hex: resolvedBackgroundHex))
                                        .padding(minSide * 0.025)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.42), lineWidth: 1)
                                                .padding(minSide * 0.025)
                                        )
                                } else if let imageName = content.imageName, !imageName.isEmpty {
                                    WidgetAssetImage(name: imageName)
                                        .foregroundColor(primaryText)
                                        .padding(minSide * 0.02)
                                } else if let symbolName = content.symbolName {
                                    Image(systemName: symbolName)
                                        .font(.system(size: visualScale, weight: .semibold))
                                        .foregroundStyle(primaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, minSide * 0.01)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Button(intent: CycleSmallRecommendationCategoryIntent(currentCategory: entry.category, baseCategory: entry.baseCategory)) {
                            VStack(spacing: 0) {
                                Text(title)
                                    .font(.custom("Merriweather-Black", size: minSide * 0.096))
                                    .foregroundStyle(bottomTitleText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .shadow(color: Color.black.opacity(usesDarkText ? 0.08 : 0.22), radius: 2, x: 0, y: 1)

                                HStack(spacing: minSide * 0.018) {
                                    ForEach(0..<4, id: \.self) { index in
                                        Circle()
                                            .fill(index == activeDotIndex ? bottomTitleText : topLabelText.opacity(0.38))
                                            .frame(width: minSide * 0.03, height: minSide * 0.03)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, dotsTopGap)
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                            .padding(.horizontal, minSide * 0.05)
                            .padding(.top, titleTopGap)
                            .padding(.bottom, dotsBottomInset)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .containerBackground(for: .widget) {
            WidgetBackground(hex: resolvedBackgroundHex)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct WidgetFooterItem: Hashable {
    let label: String
    let text: String
}

private func mantraText(_ text: String, size: CGFloat, isChinese: Bool = false) -> some View {
    Text(text)
        .font(.custom(isChinese ? "LXGWWenKaiTC-Bold" : "CormorantGaramond-SemiBold", size: size))
        .multilineTextAlignment(.leading)
        .lineLimit(4)
        .minimumScaleFactor(0.72)
        .lineSpacing(size * 0.06)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
}

private func widgetAirQualityText() -> String {
    let defaults = UserDefaults(suiteName: widgetAppGroupID)
    return defaults?.string(forKey: "widgetAirQualityText") ?? ""
}

private func widgetDeepLink(for category: WidgetRecommendationCategory) -> URL? {
    let encodedCategory = category.rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category.rawValue
    return URL(string: "Alynna://open?category=\(encodedCategory)")
}

private struct WidgetAudioState {
    let currentSoundKey: String
    let isPlaying: Bool

    static func load() -> WidgetAudioState {
        let defaults = UserDefaults(suiteName: widgetAppGroupID)
        return WidgetAudioState(
            currentSoundKey: defaults?.string(forKey: "widgetCurrentSoundKey") ?? "",
            isPlaying: defaults?.bool(forKey: "widgetCurrentSoundIsPlaying") ?? false
        )
    }
}

@ViewBuilder
private func soundOrbControl(
    size: CGFloat,
    soundKey: String,
    soundTitle: String,
    artworkName: String?,
    symbolName: String,
    isPlaying: Bool
) -> some View {
    let trimmedKey = soundKey.trimmingCharacters(in: .whitespacesAndNewlines)
    let orb = SoundOrbView(size: size, artworkName: artworkName, symbolName: symbolName, isPlaying: isPlaying)

    if trimmedKey.isEmpty {
        orb.opacity(0.68)
    } else {
        Button(intent: ToggleWidgetSoundIntent(soundKey: trimmedKey)) {
            orb
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause \(soundTitle)" : "Play \(soundTitle)")
    }
}

private struct SoundOrbView: View {
    let size: CGFloat
    let artworkName: String?
    let symbolName: String
    let isPlaying: Bool

    var body: some View {
        ZStack {
            rotatingSymbol

            Circle()
                .fill(Color(hex: "#F7F3EC").opacity(isPlaying ? 0.19 : 0.15))
                .frame(width: size * 0.32, height: size * 0.32)
                .overlay(
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: size * 0.14, weight: .bold))
                        .foregroundStyle(Color(hex: "#F7F3EC").opacity(0.98))
                )
                .scaleEffect(isPlaying ? 0.96 : 1.0)
                .shadow(color: Color.black.opacity(0.24), radius: 10, x: 0, y: 4)
                .animation(.easeInOut(duration: 0.18), value: isPlaying)
        }
        .frame(width: size, height: size)
    }

    private var rotatingSymbol: some View {
        Group {
            if let artworkName, UIImage(named: artworkName) != nil {
                Image(artworkName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.56, weight: .semibold))
                    .foregroundStyle(Color(hex: "#F7F3EC").opacity(0.97))
            }
        }
        .shadow(color: Color.black.opacity(0.22), radius: 5, x: 0, y: 1)
    }
}

private struct WidgetContentGlow: View {
    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.05), Color.clear]),
                center: .leading,
                startRadius: 0,
                endRadius: 140
            )
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.035), Color.clear]),
                center: .center,
                startRadius: 0,
                endRadius: 220
            )
        }
        .blur(radius: 10)
        .allowsHitTesting(false)
    }
}

private func widgetMantra(_ raw: String) -> String {
    let cleaned = raw
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !cleaned.isEmpty else {
        return "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care."
    }

    let sentences = cleaned
        .split(whereSeparator: { [".", "!", "?"].contains($0) })
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    if let first = sentences.first, first.count <= 84 {
        return first
    }

    let words = cleaned.split(separator: " ")
    if words.count <= 13, cleaned.count <= 84 {
        return cleaned
    }

    let shortened = words.prefix(13).joined(separator: " ")
    return shortened + "…"
}

private func soundArtworkAssetName(for key: String, title: String) -> String? {
    let candidates = [
        key.trimmingCharacters(in: .whitespacesAndNewlines),
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    ].filter { !$0.isEmpty }

    for candidate in candidates where UIImage(named: candidate) != nil {
        return candidate
    }

    return nil
}

private func soundSymbolName(for key: String, title: String) -> String {
    let source = "\(key) \(title)".lowercased()
    if source.contains("ocean") || source.contains("wave") || source.contains("water") {
        return "water.waves"
    }
    if source.contains("rain") || source.contains("storm") {
        return "cloud.rain"
    }
    if source.contains("wind") || source.contains("breeze") {
        return "wind"
    }
    if source.contains("forest") || source.contains("bird") || source.contains("leaf") {
        return "leaf"
    }
    if source.contains("fire") || source.contains("candle") {
        return "flame"
    }
    if source.contains("night") || source.contains("moon") {
        return "moon.stars"
    }
    return "waveform"
}

@ViewBuilder
private func zodiacHeader(
    sun: String,
    moon: String,
    rising: String,
    phase: String,
    color: Color,
    size: CGFloat
) -> some View {
    let items = [
        ("sun.max.fill", cleanHeaderValue(sun)),
        ("moon.fill", cleanHeaderValue(moon)),
        ("arrow.up.right", cleanHeaderValue(rising)),
        (moonPhaseSymbol(for: phase), cleanHeaderValue(compactMoonPhase(phase)))
    ].filter { !$0.1.isEmpty }

    if !items.isEmpty {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: size * 0.02) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Circle()
                            .fill(color.opacity(0.5))
                            .frame(width: 2.5, height: 2.5)
                    }
                    headerSegment(symbol: item.0, text: item.1, color: color, size: size)
                }
            }
            HStack(spacing: size * 0.016) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Circle()
                            .fill(color.opacity(0.5))
                            .frame(width: 2, height: 2)
                    }
                    headerSegment(symbol: item.0, text: String(item.1.prefix(3)), color: color, size: size * 0.96)
                }
            }
        }
    }
}

private func headerSegment(symbol: String, text: String, color: Color, size: CGFloat) -> some View {
    HStack(spacing: size * 0.009) {
        Image(systemName: symbol)
            .font(.system(size: size * 0.038, weight: .semibold))
        Text(text)
            .lineLimit(1)
    }
    .font(.custom("Merriweather-Regular", size: size * 0.053))
    .foregroundStyle(color)
}

@ViewBuilder
private func footerSegments(_ items: [WidgetFooterItem], color: Color, size: CGFloat, scale: CGFloat) -> some View {
    let labelSize = size * 0.066 * scale
    let valueSize = size * 0.068 * scale

    HStack(spacing: size * 0.015 * scale) {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            if index > 0 {
                Circle()
                    .fill(color.opacity(0.45))
                    .frame(width: 2.2 * scale, height: 2.2 * scale)
            }

            (
                Text("\(item.label) ")
                    .font(.custom("Merriweather-Bold", size: labelSize))
                +
                Text(item.text)
                    .font(.custom("Merriweather-Light", size: valueSize))
            )
            .lineLimit(1)
        }
    }
    .foregroundStyle(color)
    .minimumScaleFactor(0.82)
    .truncationMode(.tail)
}

private func widgetFooterItems(weather: String, weatherDetail: String, environment: String, airQuality: String) -> [WidgetFooterItem] {
    let weatherBits = compactWeatherDetails(weatherDetail)
    let weatherText = compactWeather(weather)
    let environmentText = readableEnvironment(environment)
    let airText = airQualityFeeling(
        airQuality
            .replacingOccurrences(of: "Air Quality:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    )

    let zh = widgetIsChinese()
    var items: [WidgetFooterItem] = []
    if !environmentText.isEmpty {
        items.append(WidgetFooterItem(label: zh ? "环境" : "Environment", text: environmentText))
    }
    if !weatherText.isEmpty {
        items.append(WidgetFooterItem(label: zh ? "天气" : "Weather", text: titleCase(weatherText)))
    }
    if !airText.isEmpty {
        items.append(WidgetFooterItem(label: zh ? "空气" : "Air", text: airText))
    }
    if let windText = weatherBits.wind, !windText.isEmpty {
        items.append(WidgetFooterItem(label: zh ? "风速" : "Wind", text: windText))
    }
    if let humidityText = weatherBits.humidity, !humidityText.isEmpty {
        items.append(WidgetFooterItem(label: zh ? "湿度" : "Humidity", text: humidityText))
    }
    if let pressureText = weatherBits.pressure, !pressureText.isEmpty {
        items.append(WidgetFooterItem(label: zh ? "气压" : "Pressure", text: pressureText))
    }
    return items
}

private func airQualityFeeling(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    let zh = widgetIsChinese()
    let lowered = trimmed.lowercased()
    if lowered.contains("good") { return zh ? "清新" : "Clean" }
    if lowered.contains("moderate") { return zh ? "尚可" : "Fair" }
    if lowered.contains("sensitive") { return zh ? "敏感" : "Sensitive" }
    if lowered.contains("very unhealthy") { return zh ? "很差" : "Very Poor" }
    if lowered.contains("unhealthy") { return zh ? "较差" : "Poor" }
    if lowered.contains("hazardous") { return zh ? "危险" : "Severe" }

    return titleCase(trimmed)
}

private func compactMoonPhase(_ raw: String) -> String {
    let phase = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    switch phase {
    case "Waxing Crescent": return "Waxing crescent"
    case "Waxing Gibbous": return "Waxing gibbous"
    case "Waning Gibbous": return "Waning gibbous"
    case "Waning Crescent": return "Waning crescent"
    default: return phase
    }
}

private func moonPhaseSymbol(for phase: String) -> String {
    switch phase.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "New Moon": return "moonphase.new.moon"
    case "Waxing Crescent": return "moonphase.waxing.crescent"
    case "First Quarter": return "moonphase.first.quarter"
    case "Waxing Gibbous": return "moonphase.waxing.gibbous"
    case "Full Moon": return "moonphase.full.moon"
    case "Waning Gibbous": return "moonphase.waning.gibbous"
    case "Third Quarter": return "moonphase.last.quarter"
    case "Waning Crescent": return "moonphase.waning.crescent"
    default: return "moon.fill"
    }
}

private func compactWeather(_ raw: String) -> String {
    let text = raw
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "air, ", with: "")
        .replacingOccurrences(of: "Mostly ", with: "")
        .replacingOccurrences(of: "mostly ", with: "")
        .replacingOccurrences(of: "Light ", with: "Light ")

    if text.count <= 22 {
        return text
    }

    let parts = text
        .components(separatedBy: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    if let first = parts.first, first.count <= 22 {
        return first
    }

    let words = text.split(separator: " ").prefix(3)
    return words.joined(separator: " ")
}

private func compactWeatherDetails(_ raw: String) -> (wind: String?, humidity: String?, pressure: String?) {
    let clean = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return (nil, nil, nil) }

    let parts = clean
        .components(separatedBy: "·")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    let windRaw = parts.first(where: { $0.localizedCaseInsensitiveContains("wind") })?
        .replacingOccurrences(of: "Wind ", with: "")
        .replacingOccurrences(of: "Mph", with: "mph")
    let humidityRaw = parts.first(where: { $0.localizedCaseInsensitiveContains("humidity") })?
        .replacingOccurrences(of: "Humidity ", with: "")
    let pressureRaw = parts.first(where: { $0.localizedCaseInsensitiveContains("pressure") })?
        .replacingOccurrences(of: "Pressure ", with: "")

    let zh = widgetIsChinese()
    let wind = windRaw.flatMap { raw in
        if let value = Double(raw.filter { $0.isNumber || $0 == "." }) {
            switch value {
            case ..<3: return zh ? "无风" : "Calm"
            case ..<8: return zh ? "微风" : "Light"
            case ..<15: return zh ? "清风" : "Breezy"
            case ..<22: return zh ? "有风" : "Windy"
            case ..<30: return zh ? "强风" : "Blustery"
            default: return zh ? "大风" : "Gusty"
            }
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let humidity = humidityRaw.flatMap { raw in
        if let value = Double(raw.filter { $0.isNumber || $0 == "." }) {
            switch value {
            case ..<30: return zh ? "干燥" : "Dry"
            case ..<45: return zh ? "舒适" : "Comfortable"
            case ..<60: return zh ? "平衡" : "Balanced"
            case ..<75: return zh ? "潮湿" : "Humid"
            default: return zh ? "闷热" : "Muggy"
            }
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let pressure = pressureRaw.flatMap { raw in
        if let value = Double(raw.filter { $0.isNumber || $0 == "." }) {
            switch value {
            case ..<1005: return zh ? "低压" : "Heavy"
            case ..<1019: return zh ? "正常" : "Balanced"
            default: return zh ? "高压" : "Crisp"
            }
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return (wind, humidity, pressure)
}

private func compactEnvironment(_ raw: String, tighter: Bool = false) -> String {
    var text = raw
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "Mostly ", with: "")
        .replacingOccurrences(of: "mostly ", with: "")
        .replacingOccurrences(of: "with quiet ", with: "")
        .replacingOccurrences(of: "with ", with: "")
        .replacingOccurrences(of: "urban edges", with: "urban edges")
        .replacingOccurrences(of: "quiet urban edges", with: "urban edges")
        .replacingOccurrences(of: "touched by ", with: "")

    if tighter {
        text = text
            .replacingOccurrences(of: "green", with: "green")
            .replacingOccurrences(of: " and ", with: " · ")
    }

    if text.count <= (tighter ? 18 : 26) {
        return text
    }

    if text.localizedCaseInsensitiveContains("green") && text.localizedCaseInsensitiveContains("urban") {
        return tighter ? "Green · urban" : "Green with urban edges"
    }

    if text.localizedCaseInsensitiveContains("water") && text.localizedCaseInsensitiveContains("city") {
        return tighter ? "Water · city" : "Water with city edges"
    }

    let words = text.split(separator: " ").prefix(tighter ? 3 : 4)
    return words.joined(separator: " ")
}

private func environmentSymbol(for text: String) -> String {
    let lowered = text.lowercased()
    if lowered.contains("green") { return "leaf.fill" }
    if lowered.contains("water") { return "water.waves" }
    if lowered.contains("urban") || lowered.contains("city") { return "building.2.fill" }
    return "map.fill"
}

private func weatherSymbol(for text: String) -> String {
    let lowered = text.lowercased()
    if lowered.contains("rain") || lowered.contains("storm") { return "cloud.rain.fill" }
    if lowered.contains("mist") || lowered.contains("fog") { return "cloud.fog.fill" }
    if lowered.contains("cloud") { return "cloud.fill" }
    if lowered.contains("clear") { return "sun.max.fill" }
    return "cloud.sun.fill"
}

private func readableEnvironment(_ raw: String) -> String {
    let lowered = raw.lowercased()
    let zh = widgetIsChinese()
    if lowered.contains("green") && lowered.contains("urban") {
        return zh ? "绿植 / 城市" : "Green / Urban"
    }
    if lowered.contains("water") && lowered.contains("city") {
        return zh ? "水岸 / 城市" : "Water / City"
    }
    if lowered.contains("green") && lowered.contains("water") {
        return zh ? "绿植 / 水岸" : "Green / Water"
    }
    if lowered.contains("green") {
        return zh ? "绿植环境" : "Mostly Green"
    }
    if lowered.contains("urban") || lowered.contains("city") {
        return zh ? "城市环境" : "Mostly Urban"
    }
    let compact = compactEnvironment(raw, tighter: true)
    return titleCase(compact)
}

private func cleanHeaderValue(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "—", with: "")
}

private func titleCase(_ raw: String) -> String {
    raw
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
        .map { word in
            let lower = word.lowercased()
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }
        .joined(separator: " ")
}

private func widgetHeaderLine(date: Date, location: String) -> String {
    let formatter = DateFormatter()
    let zh = widgetIsChinese()
    if zh {
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"
    } else {
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
    }

    let dateText = formatter.string(from: date)
    let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedLocation.isEmpty else {
        return dateText
    }

    return zh ? "\(dateText) · \(trimmedLocation)" : "\(dateText) at \(trimmedLocation)"
}

private func moonPhaseLabel(for date: Date = Date()) -> String {
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
struct AlynnaMediumWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlynnaWidget", provider: AlynnaProvider()) { entry in
            AlynnaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Alynna 每日")
        .description("每日心语，含色彩、地点、宝石与香气推荐。")
        .supportedFamilies([.systemMedium])
    }
}

struct AlynnaRecommendationWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "AlynnaRecommendationWidget",
            intent: SelectRecommendationCategoryIntent.self,
            provider: AlynnaSmallProvider()
        ) { entry in
            AlynnaSmallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Alynna 焦点")
        .description("在方形卡片中突出显示八项每日推荐之一。")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct AlynnaWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlynnaMediumWidget()
        AlynnaRecommendationWidget()
    }
}

#if DEBUG
struct AlynnaWidget_Previews: PreviewProvider {
    private static let previewSnapshot = AlynnaWidgetSnapshot(
        mantra: "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care.",
        locationName: "Brooklyn",
        weatherSummary: "Cool, rainy",
        environmentSummary: "Mostly green with quiet urban edges",
        soundKey: "brown_noise",
        soundTitle: "Brown Noise",
        colorKey: "amber",
        colorTitle: "Amber",
        colorHex: "#D99100",
        placeKey: "echo_niche",
        placeTitle: "Echo Niche",
        gemstoneKey: "amethyst",
        gemstoneTitle: "Amethyst",
        scentKey: "bergamot",
        scentTitle: "Bergamot",
        activityKey: "clean_mirror",
        activityTitle: "Polishing Mirror",
        careerKey: "clear_channel",
        careerTitle: "Clear Channel",
        relationshipKey: "breathe_sync",
        relationshipTitle: "Breathe in Sync",
        categoryReasoning: [
            "Place": "A quieter place helps you process the day without extra noise.",
            "Gemstone": "This gemstone reinforces steadiness and emotional protection.",
            "Color": "This tone supports a clearer and more balanced mood.",
            "Scent": "This scent is meant to soften overstimulation and restore ease.",
            "Activity": "This activity invites a small reset instead of pushing harder.",
            "Sound": "This sound supports a steadier rhythm for focus and rest.",
            "Career": "This cue favors thoughtful pacing over reactive decisions.",
            "Relationship": "This cue encourages gentler communication and connection."
        ],
        reasoningSummary: "Today asks for steadiness over perfection. Your recommendations point toward quieter rituals, clearer pacing, and choices that keep your nervous system supported."
    )

    static var previews: some View {
        AlynnaWidgetEntryView(
            entry: AlynnaEntry(
                date: Date(),
                snapshot: previewSnapshot,
                showsBack: false
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))

        AlynnaWidgetEntryView(
            entry: AlynnaEntry(
                date: Date(),
                snapshot: previewSnapshot,
                showsBack: true
            )
        )
        .previewDisplayName("Medium Back")
        .previewContext(WidgetPreviewContext(family: .systemMedium))

        AlynnaSmallWidgetEntryView(
            entry: AlynnaSmallEntry(
                date: Date(),
                snapshot: previewSnapshot,
                baseCategory: .gemstone,
                category: .gemstone,
                showsBack: false
            )
        )
        .previewDisplayName("Small Gemstone")
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        AlynnaSmallWidgetEntryView(
            entry: AlynnaSmallEntry(
                date: Date(),
                snapshot: previewSnapshot,
                baseCategory: .place,
                category: .place,
                showsBack: false
            )
        )
        .previewDisplayName("Small Place")
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        AlynnaSmallWidgetEntryView(
            entry: AlynnaSmallEntry(
                date: Date(),
                snapshot: previewSnapshot,
                baseCategory: .color,
                category: .color,
                showsBack: false
            )
        )
        .previewDisplayName("Small Color")
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        AlynnaSmallWidgetEntryView(
            entry: AlynnaSmallEntry(
                date: Date(),
                snapshot: previewSnapshot,
                baseCategory: .scent,
                category: .scent,
                showsBack: false
            )
        )
        .previewDisplayName("Small Scent")
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        AlynnaSmallWidgetEntryView(
            entry: AlynnaSmallEntry(
                date: Date(),
                snapshot: previewSnapshot,
                baseCategory: .activity,
                category: .activity,
                showsBack: false
            )
        )
        .previewDisplayName("Small Activity")
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        AlynnaSmallWidgetEntryView(
            entry: AlynnaSmallEntry(
                date: Date(),
                snapshot: previewSnapshot,
                baseCategory: .sound,
                category: .sound,
                showsBack: false
            )
        )
        .previewDisplayName("Small Sound")
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        AlynnaSmallWidgetEntryView(
            entry: AlynnaSmallEntry(
                date: Date(),
                snapshot: previewSnapshot,
                baseCategory: .career,
                category: .career,
                showsBack: false
            )
        )
        .previewDisplayName("Small Career")
        .previewContext(WidgetPreviewContext(family: .systemSmall))

        AlynnaSmallWidgetEntryView(
            entry: AlynnaSmallEntry(
                date: Date(),
                snapshot: previewSnapshot,
                baseCategory: .relationship,
                category: .relationship,
                showsBack: false
            )
        )
        .previewDisplayName("Small Relationship")
        .previewContext(WidgetPreviewContext(family: .systemSmall))
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
