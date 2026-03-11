import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit

enum BootPhase {
    case loading
    case infoSplash
    case onboarding   // ← 新增：需要走新手引导
    case main
}


func currentZodiacSign(for date: Date = Date()) -> String {
    let cal = Calendar(identifier: .gregorian)
    let (m, d) = (cal.component(.month, from: date), cal.component(.day, from: date))
    switch (m, d) {
    case (3,21...31),(4,1...19):  return "♈︎ Aries"
    case (4,20...30),(5,1...20):  return "♉︎ Taurus"
    case (5,21...31),(6,1...20):  return "♊︎ Gemini"
    case (6,21...30),(7,1...22):  return "♋︎ Cancer"
    case (7,23...31),(8,1...22):  return "♌︎ Leo"
    case (8,23...31),(9,1...22):  return "♍︎ Virgo"
    case (9,23...30),(10,1...22): return "♎︎ Libra"
    case (10,23...31),(11,1...21):return "♏︎ Scorpio"
    case (11,22...30),(12,1...21):return "♐︎ Sagittarius"
    case (12,22...31),(1,1...19): return "♑︎ Capricorn"
    case (1,20...31),(2,1...18):  return "♒︎ Aquarius"
    default:                      return "♓︎ Pisces"
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
    private let fixedMessageIndex: Int?
    private let brandDisk: CGFloat = 96
    
    @State private var loadingMessages = [
        "Aligning with the cosmos",
        "Reading celestial patterns",
        "Gathering stellar insights",
        "Preparing your journey"
    ]
    @State private var msgIndex = 0
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var spinFast = false
    @State private var spinSlow = false
    @State private var pulse = false
    @State private var dotPhase: CGFloat = 0
    @State private var bounce = false
    
    @State private var showWelcome = false
    @State private var currentLocation: String = "Your Current Location"
    @State private var zodiacSign: String = ""
    @State private var moonPhase: String = ""

    init(onStartLoading: (() -> Void)? = nil, fixedMessageIndex: Int? = nil) {
        self.onStartLoading = onStartLoading
        self.fixedMessageIndex = fixedMessageIndex
    }

    private var currentLoadingMessage: String {
        guard let fixedMessageIndex else { return loadingMessages[msgIndex] }
        let clampedIndex = min(max(fixedMessageIndex, 0), loadingMessages.count - 1)
        return loadingMessages[clampedIndex]
    }

    @ViewBuilder
    private var brandTitle: some View {
        let title = Text("Alynna")
            .font(AlignaType.brandTitle())
            .lineSpacing(40 - 34)
            .foregroundColor(themeManager.primaryText)

        if themeManager.isNight {
            title.shimmer()
        } else {
            title
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                // === Main content ===
                VStack(spacing: 32) {
                    // Logo（透明背景 + 颜色跟随 ThemeManager）
                    ZStack {
                        let iconColor: Color = themeManager.primaryText

                        Image("appLogo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: brandDisk, height: brandDisk)
                            .foregroundColor(iconColor)
                            .scaleEffect(pulse ? 1.04 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.8)
                                    .repeatForever(autoreverses: true),
                                value: pulse
                            )
                    }
                    .onAppear {
                        onStartLoading?()
                        pulse = true
                    }

                    // Brand title + thin underline + shimmer
                    VStack(spacing: 6) {
                        brandTitle

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        themeManager.primaryText.opacity(0.6), // ✅ 跟随主题
                                        .clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 120, height: 1)
                    }

                    // Spinner (two rings)
                    ZStack {
                        Circle()
                            .stroke(themeManager.primaryText.opacity(0.20), lineWidth: 2) // ✅
                            .frame(width: 64, height: 64)

                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(themeManager.primaryText, style: StrokeStyle(lineWidth: 2, lineCap: .round)) // ✅
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(spinFast ? 360 : 0))
                            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: spinFast)

                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(themeManager.primaryText.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round)) // ✅
                            .frame(width: 48, height: 48)
                            .rotationEffect(.degrees(spinSlow ? 360 : 0))
                            .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: spinSlow)
                    }
                    .onAppear {
                        spinFast = true
                        spinSlow = true
                    }

                    // Loading text + bouncing dots
                    VStack(spacing: 12) {
                        Text(currentLoadingMessage)
                            .font(AlignaType.loadingSubtitle())
                            .lineSpacing(AlignaType.body16LineSpacing)
                            .foregroundColor(themeManager.descriptionText.opacity(0.90)) // ✅

                        HStack(spacing: 6) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(themeManager.primaryText.opacity(0.55)) // ✅
                                    .frame(width: 8, height: 8)
                                    .offset(y: bounce ? -6 : 0)
                                    .animation(
                                        .easeInOut(duration: 0.5)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.15),
                                        value: bounce
                                    )
                            }
                        }
                        .padding(.top, 15)
                    }
                    .onAppear { bounce = true }
                }
                .frame(maxWidth: 480)
                .padding(16)
            }
            .onAppear {
                if fixedMessageIndex == nil {
                    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            msgIndex = (msgIndex + 1) % loadingMessages.count
                        }
                    }
                }
                withAnimation { dotPhase = 1 }
            }
            .preferredColorScheme(themeManager.preferredColorScheme)
        }
    }

    private func dotOffset(for i: Int) -> CGFloat {
        let up = (Int(dotPhase) + i) % 2 == 0
        return up ? -4 : 0
    }
}



struct WelcomeSplashView: View {
    let location: String
    let zodiac: String
    let moon: String
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var appear = false

    // 根据星座文字“包含什么单词”来返回对应 emoji
    private var zodiacIcon: String {
        let lower = zodiac.lowercased()

        if lower.contains("aries") { return "♈️" }
        if lower.contains("taurus") { return "♉️" }
        if lower.contains("gemini") { return "♊️" }
        if lower.contains("cancer") { return "♋️" }
        if lower.contains("leo") { return "♌️" }
        if lower.contains("virgo") { return "♍️" }
        if lower.contains("libra") { return "♎️" }
        if lower.contains("scorpio") { return "♏️" }
        if lower.contains("sagittarius") { return "♐️" }
        if lower.contains("capricorn") { return "♑️" }
        if lower.contains("aquarius") { return "♒️" }
        if lower.contains("pisces") { return "♓️" }

        return "✨"
    }

    // 生成“干净”的星座名字
    private var zodiacText: String {
        let lower = zodiac.lowercased()

        if lower.contains("aries") { return "Aries" }
        if lower.contains("taurus") { return "Taurus" }
        if lower.contains("gemini") { return "Gemini" }
        if lower.contains("cancer") { return "Cancer" }
        if lower.contains("leo") { return "Leo" }
        if lower.contains("virgo") { return "Virgo" }
        if lower.contains("libra") { return "Libra" }
        if lower.contains("scorpio") { return "Scorpio" }
        if lower.contains("sagittarius") { return "Sagittarius" }
        if lower.contains("capricorn") { return "Capricorn" }
        if lower.contains("aquarius") { return "Aquarius" }
        if lower.contains("pisces") { return "Pisces" }

        return zodiac
    }

    // 去掉 moon 字符串里前面的 emoji，只保留文字描述
    private var cleanMoonText: String {
        let parts = moon.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2 {
            // 例如 "🌓 First Quarter" -> "First Quarter"
            return String(parts[1])
        } else {
            // 没有 emoji 时就原样返回
            return moon
        }
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                // Logo（透明背景 + 颜色跟随 ThemeManager）
                let disk: CGFloat = 96
                let iconColor: Color = themeManager.primaryText

                Image("appLogo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: disk, height: disk)
                    .foregroundColor(iconColor)
                
                // Brand + hairline underline
                VStack(spacing: 6) {
                    Text("Alynna")
                        .font(AlignaType.brandTitle())
                        .lineSpacing(40 - 34)
                        .foregroundColor(themeManager.primaryText)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, themeManager.primaryText.opacity(0.7), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 120, height: 1)
                }

                // Info rows: grouped as a light info card for clearer structure.
                VStack(alignment: .leading, spacing: 12) {
                    infoLine(icon: "📍",
                             text: location,
                             textOpacity: 0.9)

                    infoLine(icon: zodiacIcon,
                             text: zodiacText,
                             textOpacity: 0.85)

                    infoLine(icon: "🌙",
                             text: cleanMoonText,
                             textOpacity: 0.75)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(width: 220, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(themeManager.isNight ? Color.white.opacity(0.06) : Color.white.opacity(0.22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            themeManager.isNight
                                ? Color.white.opacity(0.12)
                                : Color(hex: "#D4A574").opacity(0.18),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(themeManager.isNight ? 0.10 : 0.05),
                    radius: 10,
                    x: 0,
                    y: 6
                )
                .padding(.top, 8)
            }
            .multilineTextAlignment(.leading)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? -28 : -16)
            .animation(.easeOut(duration: 0.45), value: appear)
        }
        .onAppear { appear = true }
    }

    // MARK: - 统一的 Info Row（16pt 字号 + 行高约 22pt + 首字母对齐）
    private func infoLine(icon: String, text: String, textOpacity: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // 固定宽度的 emoji 区域，保证后面文字首字母对齐
            Text(icon)
                .font(.system(size: 18))
                .frame(width: 24, alignment: .leading)

            Text(text)
                .foregroundColor(themeManager.primaryText.opacity(textOpacity))
                .font(.custom("Merriweather-Regular", size: 16))
                .lineSpacing(AlignaType.body16LineSpacing)

        }
    }
}

#if DEBUG
private struct LoadingViewPreviewContainer: View {
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager
    let isNight: Bool

    init(isNight: Bool = false) {
        self.isNight = isNight
        let themeManager = ThemeManager()
        themeManager.selected = isNight ? .night : .day
        _themeManager = StateObject(wrappedValue: themeManager)
    }

    var body: some View {
        LoadingView(fixedMessageIndex: 0)
            .environmentObject(starManager)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Loading Day") {
    LoadingViewPreviewContainer()
}

#Preview("Loading Night") {
    LoadingViewPreviewContainer(isNight: true)
}

private struct InfoSplashPreviewContainer: View {
    @StateObject private var starManager = StarAnimationManager()
    @StateObject private var themeManager: ThemeManager

    init(isNight: Bool = false) {
        let themeManager = ThemeManager()
        themeManager.selected = isNight ? .night : .day
        _themeManager = StateObject(wrappedValue: themeManager)
    }

    var body: some View {
        WelcomeSplashView(
            location: "Cupertino",
            zodiac: "♍︎ Virgo",
            moon: "🌔 Waxing Gibbous"
        )
        .environmentObject(starManager)
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

#Preview("Info Splash") {
    InfoSplashPreviewContainer()
}
#endif
