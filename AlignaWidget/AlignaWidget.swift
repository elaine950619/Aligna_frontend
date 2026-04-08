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
    var colorTitle: String
    var colorHex: String?
    var placeTitle: String
    var gemstoneTitle: String
    var scentTitle: String

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
        colorTitle: String,
        colorHex: String? = nil,
        placeTitle: String,
        gemstoneTitle: String,
        scentTitle: String,
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
                locationName: "Brooklyn",
                sunSign: "Virgo",
                moonSign: "Pisces",
                risingSign: "Libra",
                weatherSummary: "Cool, rainy",
                weatherDetailSummary: "Wind 8 Mph · Humidity 63%",
                environmentSummary: "Mostly green with quiet urban edges",
                soundKey: "ocean_waves",
                soundTitle: "Ocean Waves",
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
        let phaseText = moonPhaseLabel(for: entry.snapshot.savedAt)
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

        return GeometryReader { geometry in
            let minSide = min(geometry.size.width, geometry.size.height)

            VStack(alignment: .leading, spacing: minSide * 0.024) {
                HStack(alignment: .firstTextBaseline, spacing: minSide * 0.03) {
                    Text(topLine)
                        .font(.custom("Merriweather-Bold", size: minSide * 0.072))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: minSide * 0.02)

                    zodiacHeader(
                        sun: entry.snapshot.sunSign,
                        moon: entry.snapshot.moonSign,
                        rising: entry.snapshot.risingSign,
                        phase: phaseText,
                        color: secondaryTextColor,
                        size: minSide
                    )
                }

                Spacer(minLength: minSide * 0.004)

                HStack(alignment: .center, spacing: minSide * 0.042) {
                    soundOrbControl(
                        size: minSide * 0.48,
                        soundKey: entry.snapshot.soundKey,
                        soundTitle: entry.snapshot.soundTitle,
                        artworkName: soundArtworkName,
                        symbolName: soundSymbol,
                        isPlaying: isSoundPlaying
                    )

                    ViewThatFits(in: .vertical) {
                        mantraText(displayMantra, size: minSide * 0.14)
                        mantraText(displayMantra, size: minSide * 0.132)
                        mantraText(displayMantra, size: minSide * 0.124)
                    }
                }
                .foregroundColor(textColor)
                .layoutPriority(1)
                .background {
                    WidgetContentGlow()
                        .padding(.horizontal, -minSide * 0.03)
                        .padding(.vertical, -minSide * 0.02)
                }

                Spacer(minLength: minSide * 0.01)

                if !footerItems.isEmpty {
                    let lineColor = secondaryTextColor
                    let topFooterItems = footerItems.filter { ["Environment", "Weather"].contains($0.label) }
                    let bottomFooterItems = footerItems.filter { ["Air", "Wind", "Humidity", "Pressure"].contains($0.label) }

                    VStack(alignment: .leading, spacing: minSide * 0.012) {
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
                    .padding(.top, minSide * 0.006)
                }
            }
            .padding(.horizontal, minSide * 0.082)
            .padding(.vertical, minSide * 0.066)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .containerBackground(for: .widget) {
            WidgetBackground(hex: resolvedBackgroundHex)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "Alynna://open"))
    }
}

private struct WidgetFooterItem: Hashable {
    let label: String
    let text: String
}

private func mantraText(_ text: String, size: CGFloat) -> some View {
    Text(text)
        .font(.custom("CormorantGaramond-SemiBold", size: size))
        .multilineTextAlignment(.leading)
        .lineLimit(3)
        .minimumScaleFactor(0.8)
        .lineSpacing(size * 0.1)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
}

private func widgetAirQualityText() -> String {
    let defaults = UserDefaults(suiteName: widgetAppGroupID)
    return defaults?.string(forKey: "widgetAirQualityText") ?? ""
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
        return "Today is not about perfection. It is about noticing small moments."
    }

    let sentences = cleaned
        .split(whereSeparator: { [".", "!", "?"].contains($0) })
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    if let first = sentences.first, first.count <= 84 {
        return first + "."
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
    .font(.custom("Merriweather-Regular", size: size * 0.05))
    .foregroundStyle(color)
}

@ViewBuilder
private func footerSegments(_ items: [WidgetFooterItem], color: Color, size: CGFloat, scale: CGFloat) -> some View {
    let labelSize = size * 0.064 * scale
    let valueSize = size * 0.066 * scale

    return HStack(spacing: size * 0.018 * scale) {
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

    var items: [WidgetFooterItem] = []
    if !environmentText.isEmpty {
        items.append(WidgetFooterItem(label: "Environment", text: environmentText))
    }
    if !weatherText.isEmpty {
        items.append(WidgetFooterItem(label: "Weather", text: titleCase(weatherText)))
    }
    if !airText.isEmpty {
        items.append(WidgetFooterItem(label: "Air", text: airText))
    }
    if let windText = weatherBits.wind, !windText.isEmpty {
        items.append(WidgetFooterItem(label: "Wind", text: windText))
    }
    if let humidityText = weatherBits.humidity, !humidityText.isEmpty {
        items.append(WidgetFooterItem(label: "Humidity", text: humidityText))
    }
    if let pressureText = weatherBits.pressure, !pressureText.isEmpty {
        items.append(WidgetFooterItem(label: "Pressure", text: pressureText))
    }
    return items
}

private func airQualityFeeling(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    let lowered = trimmed.lowercased()
    if lowered.contains("good") { return "Clean" }
    if lowered.contains("moderate") { return "Fair" }
    if lowered.contains("sensitive") { return "Sensitive" }
    if lowered.contains("very unhealthy") { return "Very Poor" }
    if lowered.contains("unhealthy") { return "Poor" }
    if lowered.contains("hazardous") { return "Severe" }

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

    let wind = windRaw.flatMap { raw in
        if let value = Double(raw.filter { $0.isNumber || $0 == "." }) {
            switch value {
            case ..<3: return "Calm"
            case ..<8: return "Light"
            case ..<15: return "Breezy"
            case ..<22: return "Windy"
            case ..<30: return "Blustery"
            default: return "Gusty"
            }
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let humidity = humidityRaw.flatMap { raw in
        if let value = Double(raw.filter { $0.isNumber || $0 == "." }) {
            switch value {
            case ..<30: return "Dry"
            case ..<45: return "Comfortable"
            case ..<60: return "Balanced"
            case ..<75: return "Humid"
            default: return "Muggy"
            }
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let pressure = pressureRaw.flatMap { raw in
        if let value = Double(raw.filter { $0.isNumber || $0 == "." }) {
            switch value {
            case ..<1005: return "Heavy"
            case ..<1019: return "Balanced"
            default: return "Crisp"
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
    if lowered.contains("green") && lowered.contains("urban") {
        return "Green / Urban"
    }
    if lowered.contains("water") && lowered.contains("city") {
        return "Water / City"
    }
    if lowered.contains("green") && lowered.contains("water") {
        return "Green / Water"
    }
    if lowered.contains("green") {
        return "Mostly Green"
    }
    if lowered.contains("urban") || lowered.contains("city") {
        return "Mostly Urban"
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
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE, MMM d"

    let dateText = formatter.string(from: date)
    let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedLocation.isEmpty else {
        return dateText
    }

    return "\(dateText) at \(trimmedLocation)"
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
                    mantra: "Today is not about perfection. It is about noticing small moments, honoring how I feel, and allowing myself to move forward with patience and care.",
                    locationName: "Brooklyn",
                    weatherSummary: "Cool, rainy",
                    environmentSummary: "Mostly green with quiet urban edges",
                    soundKey: "ocean_waves",
                    soundTitle: "Ocean Waves",
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
