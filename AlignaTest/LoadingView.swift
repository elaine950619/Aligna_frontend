import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit

enum BootPhase {
    case loading
    case onboarding   // ← 新增：需要走新手引导
    case main
}


func currentZodiacSign(for date: Date = Date()) -> String {
    let cal = Calendar(identifier: .gregorian)
    let (m, d) = (cal.component(.month, from: date), cal.component(.day, from: date))
    switch (m, d) {
    case (3,21...31),(4,1...19):  return "♈️ Aries"
    case (4,20...30),(5,1...20):  return "♉️ Taurus"
    case (5,21...31),(6,1...20):  return "♊️ Gemini"
    case (6,21...30),(7,1...22):  return "♋️ Cancer"
    case (7,23...31),(8,1...22):  return "♌️ Leo"
    case (8,23...31),(9,1...22):  return "♍️ Virgo"
    case (9,23...30),(10,1...22): return "♎️ Libra"
    case (10,23...31),(11,1...21):return "♏️ Scorpio"
    case (11,22...30),(12,1...21):return "♐️ Sagittarius"
    case (12,22...31),(1,1...19): return "♑️ Capricorn"
    case (1,20...31),(2,1...18):  return "♒️ Aquarius"
    default:                      return "♓️ Pisces"
    }
}

/// quick-and-pleasant moon phase label (like your React demo)
func currentMoonPhaseLabel(for date: Date = Date()) -> String {
    // Simple ~29.53 day cycle approximation
    let synodic: Double = 29.53058867
    // Anchor: 2000-01-06 18:14 UTC is a known new moon (approx). Good enough for a splash.
    let anchor = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: .init(secondsFromGMT: 0),
        year: 2000, month: 1, day: 6, hour: 18, minute: 14
    ).date!
    
    let days = date.timeIntervalSince(anchor) / 86400
    let phase = (days - floor(days / synodic) * synodic) // [0, synodic)
    switch phase {
    case 0..<1.84566:  return "🌑 New Moon"
    case 1.84566..<5.53699: return "🌒 Waxing Crescent"
    case 5.53699..<9.22831: return "🌓 First Quarter"
    case 9.22831..<12.91963: return "🌔 Waxing Gibbous"
    case 12.91963..<16.61096: return "🌕 Full Moon"
    case 16.61096..<20.30228: return "🌖 Waning Gibbous"
    case 20.30228..<23.99361: return "🌗 Third Quarter"
    case 23.99361..<27.68493: return "🌘 Waning Crescent"
    default: return "🌑 New Moon"
    }
}

// MARK: - Helpers
extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hexSanitized.count {
        case 6: (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 1)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: opacity)
    }
}
// ====== Time & Parse Helpers (新增) ======
struct ISO8601Calendar {
    private static let f1: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let f2: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func date(from s: String) -> Date? { f1.date(from: s) ?? f2.date(from: s) }
}

/// 仅用“本地时区的时分”构造一个 Date（锚定在固定参考日，避免跨时区/日期导致显示漂移）
func makeLocalDate(hour: Int, minute: Int, tz: TimeZone = .current) -> Date? {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    // 选择一个固定参考日（不会用于展示，只为承载时分）
    var comp = DateComponents()
    comp.year = 2000; comp.month = 1; comp.day = 1
    comp.hour = hour; comp.minute = minute
    return cal.date(from: comp)
}

/// 兼容 "HH:mm" / "H:mm" / "h:mm a" / "hh:mm a"
func timeToDateFlexible(_ s: String, tz: TimeZone = .current) -> Date? {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let fmts = ["HH:mm","H:mm","h:mm a","hh:mm a","h:mma","hh:mma"]
    for pat in fmts {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = pat
        if let d = f.date(from: trimmed) {
            let cal = Calendar(identifier: .gregorian)
            let hm = cal.dateComponents([.hour,.minute], from: d)
            return makeLocalDate(hour: hm.hour ?? 0, minute: hm.minute ?? 0, tz: tz)
        }
    }
    return nil
}
// 兼容 "yyyy-MM-dd" 和 "yyyy/M/d" 的日期解析（本地时区）
private let DF_YMD: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private let DF_YMD_SLASH: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy/M/d"
    return f
}()

@inline(__always)
func parseBirthDateString(_ s: String) -> Date? {
    // 先试 ISO8601（含 T…Z 的情况），再试两种纯日期
    return ISO8601Calendar.date(from: s) ?? DF_YMD.date(from: s) ?? DF_YMD_SLASH.date(from: s)
}



// Subtle text shimmer like your React “brand-title animate-text-shimmer”
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.7), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .blendMode(.screen)
                .mask(content)

            )
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}
extension View { func shimmer() -> some View { modifier(Shimmer()) } }

// MARK: - LoadingView

struct LoadingView: View {
    var onStartLoading: (() -> Void)? = nil
    var onPersonalComplete: (() -> Void)? = nil
    private let fixedMessageIndex: Int?

    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var didStartLoading = false
    @State private var stage: LoadingStage = .cosmic
    @State private var cosmicEmojiIndex = 0
    @State private var placeEmojiIndex = 0
    @State private var autoSkipWorkItem: DispatchWorkItem?
    @State private var personalCompleted = false
    @State private var didInteractPersonal = false

    @State private var mood: String? = nil
    @State private var stress: String? = nil
    @State private var sleep: String? = nil
    @State private var source: String? = nil

    var sunText: String = "—"
    var moonText: String = "—"
    var risingText: String = "—"
    var locationText: String = "Your Current Location"
    var conditionText: String = "Cloud · Wind · Rain"

    init(
        onStartLoading: (() -> Void)? = nil,
        onPersonalComplete: (() -> Void)? = nil,
        fixedMessageIndex: Int? = nil
    ) {
        self.onStartLoading = onStartLoading
        self.onPersonalComplete = onPersonalComplete
        self.fixedMessageIndex = fixedMessageIndex
    }

    fileprivate enum LoadingStage: Int {
        case cosmic
        case place
        case personal
    }

    private var anyPersonalSelection: Bool {
        mood != nil || stress != nil || sleep != nil || source != nil
    }

    private var shouldAutoSkipPersonal: Bool {
        !didInteractPersonal && !anyPersonalSelection
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                // === Main content ===
                VStack(spacing: 22) {
                    stageContent
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .onAppear {
                    if !didStartLoading {
                        didStartLoading = true
                        onStartLoading?()
                    }
                }
            }
            .onAppear {
                scheduleStageProgression()
                startEmojiTimers()
            }
            .onChange(of: stage, initial: false) { _, newStage in
                if newStage == .personal {
                    scheduleAutoSkipIfNeeded()
                }
            }
            .onChange(of: anyPersonalSelection, initial: false) { _, hasSelection in
                if hasSelection {
                    autoSkipWorkItem?.cancel()
                }
            }
            .onChange(of: didInteractPersonal, initial: false) { _, interacted in
                if interacted {
                    autoSkipWorkItem?.cancel()
                }
            }
            .preferredColorScheme(themeManager.preferredColorScheme)
        }
    }

    private var stageContent: some View {
        VStack(spacing: 16) {
            switch stage {
            case .cosmic:
                stageHeader(title: "Cosmic signals",
                            subtitle: cosmicSubtitle,
                            emoji: cosmicEmojis[cosmicEmojiIndex])
                stageSupplement("Sun: \(sunText) · Moon: \(moonText) · Rising: \(risingText)")
                stageSource("Astronomical data from NOAA and NASA.")

            case .place:
                stageHeader(title: "Place signals",
                            subtitle: placeSubtitle,
                            emoji: placeEmojis[placeEmojiIndex])
                stageSupplement("Location: \(locationText) · Conditions: \(conditionText)")
                stageSource("Environmental observations from NASA and ESA satellites.")

            case .personal:
                stageHeader(title: "Personal check-in",
                            subtitle: "Tap what feels true right now.",
                            emoji: "🙂")
                personalCheckIn
                if personalCompleted {
                    Text("Logged for today.")
                        .font(AlignaType.helperSmall())
                        .foregroundColor(themeManager.descriptionText.opacity(0.9))
                }
            }
        }
    }

    private func stageHeader(title: String, subtitle: String, emoji: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(AlignaType.loadingSubtitle())
                .foregroundColor(themeManager.primaryText)
            emojiText(emoji, size: 64)
            Text(subtitle)
                .font(AlignaType.helperSmall())
                .foregroundColor(themeManager.descriptionText.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private func stageSupplement(_ text: String) -> some View {
        Text(text)
            .font(AlignaType.helperSmall())
            .foregroundColor(themeManager.descriptionText.opacity(0.85))
    }

    private func stageSource(_ text: String) -> some View {
        Text(text)
            .font(AlignaType.helperSmall())
            .foregroundColor(themeManager.descriptionText.opacity(0.6))
            .padding(.top, 6)
    }

    private func emojiText(_ emoji: String, size: CGFloat) -> some View {
        Text(emoji)
            .font(.custom("AppleColorEmoji", size: size))
            .textSelection(.disabled)
    }

    private var personalCheckIn: some View {
        VStack(spacing: 14) {
            emojiRow(
                title: "Mood",
                options: [("😀", "Good"), ("🙂", "Calm"), ("😐", "Neutral"), ("😟", "Anxious"), ("😞", "Low")],
                selection: $mood
            )
            emojiRow(
                title: "Stress",
                options: [("😌", "Low"), ("😬", "Medium"), ("😣", "High")],
                selection: $stress
            )
            emojiRow(
                title: "Sleep",
                options: [("😴", "Poor"), ("😌", "OK"), ("😃", "Great")],
                selection: $sleep
            )
            emojiRow(
                title: "Source",
                options: [("💼", "Work"), ("🤝", "Relationships"), ("💪", "Health"), ("💸", "Money"), ("❓", "Unclear")],
                selection: $source
            )
            HStack(spacing: 12) {
                Button("Skip") {
                    didInteractPersonal = true
                    completePersonal()
                }
                Button("Continue") {
                    didInteractPersonal = true
                    completePersonal()
                }
            }
            .font(AlignaType.helperSmall())
            .foregroundColor(themeManager.primaryText)
        }
    }

    private func emojiRow(
        title: String,
        options: [(String, String)],
        selection: Binding<String?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AlignaType.helperSmall())
                .foregroundColor(themeManager.descriptionText.opacity(0.8))
            HStack(spacing: 10) {
                ForEach(options, id: \.1) { option in
                    Button {
                        didInteractPersonal = true
                        selection.wrappedValue = option.1
                    } label: {
                        HStack(spacing: 6) {
                            emojiText(option.0, size: 16)
                            Text(option.1)
                        }
                        .font(AlignaType.helperSmall())
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(selection.wrappedValue == option.1 ? themeManager.primaryText.opacity(0.2) : Color.white.opacity(0.06))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    private var cosmicEmojis: [String] { ["☀️", "🌙", "🪐", "✨"] }
    private var placeEmojis: [String] { ["🌧️", "🌬️", "☁️", "🌊", "🌲"] }

    private var cosmicSubtitle: String {
        let lines = [
            "Your Sun, Moon, and Rising are coming into view",
            "Aligning today’s light and shadow",
            "Listening to the sky’s quiet math"
        ]
        return lines[cosmicEmojiIndex % lines.count]
    }

    private var placeSubtitle: String {
        let lines = [
            "Wind, rain, and light are moving",
            "Water, air, and temperature shift with you",
            "Reading today’s living atmosphere"
        ]
        return lines[placeEmojiIndex % lines.count]
    }

    private func scheduleStageProgression() {
        guard fixedMessageIndex == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if stage == .cosmic { stage = .place }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            if stage == .place { stage = .personal }
        }
    }

    private func startEmojiTimers() {
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            cosmicEmojiIndex = (cosmicEmojiIndex + 1) % cosmicEmojis.count
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            placeEmojiIndex = (placeEmojiIndex + 1) % placeEmojis.count
        }
    }

    private func scheduleAutoSkipIfNeeded() {
        autoSkipWorkItem?.cancel()
        let item = DispatchWorkItem {
            if shouldAutoSkipPersonal {
                completePersonal()
            }
        }
        autoSkipWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: item)
    }

    private func completePersonal() {
        guard !personalCompleted else { return }
        autoSkipWorkItem?.cancel()
        personalCompleted = true
        onPersonalComplete?()
    }
}


#if DEBUG
private extension LoadingView {
    init(previewStage: LoadingStage) {
        self.init(onStartLoading: nil, onPersonalComplete: nil, fixedMessageIndex: 0)
        _stage = State(initialValue: previewStage)
    }
}

private struct LoadingViewPreviewContainer: View {
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager
    let isNight: Bool
    let stage: LoadingView.LoadingStage

    init(isNight: Bool = false, stage: LoadingView.LoadingStage) {
        self.isNight = isNight
        self.stage = stage
        let themeManager = ThemeManager()
        themeManager.selected = isNight ? .night : .day
        _themeManager = StateObject(wrappedValue: themeManager)
    }

    var body: some View {
        LoadingView(previewStage: stage)
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Loading Cosmic") {
    LoadingViewPreviewContainer(stage: .cosmic)
}

#Preview("Loading Place") {
    LoadingViewPreviewContainer(stage: .place)
}

#Preview("Loading Personal") {
    LoadingViewPreviewContainer(stage: .personal)
}

#Preview("Loading Night") {
    LoadingViewPreviewContainer(isNight: true, stage: .cosmic)
}
#endif
