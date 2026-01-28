import SwiftUI
import Foundation
import MapKit
import CoreLocation
import Combine
import WidgetKit


func getAddressFromCoordinate(
    _ coordinate: CLLocationCoordinate2D,
    preferredLocale: Locale = Locale(identifier: "en_US"),
    completion: @escaping (String?) -> Void
) {
    let geocoder = CLGeocoder()
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

    func humanReadable(from p: CLPlacemark) -> String? {
        // 优先城市 → 区/县 → 省/州（都不行再尝试 name/country）
        let candidates: [String?] = [
            p.locality,
            p.subLocality,
            p.administrativeArea,
            p.subAdministrativeArea,
            p.name,
            p.country
        ]

        // 选出第一个非空且不是坐标串的
        if let picked = candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty && !isCoordinateLikeString($0) }) {
            return picked
        }
        return nil
    }

    func reverse(allowRetry: Bool) {
        geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { placemarks, error in
            if let p = placemarks?.first, let name = humanReadable(from: p) {
                completion(name)
                return
            }
            // 对“无结果”重试一次（网络/缓存偶发）
            if let e = error as? CLError, e.code == .geocodeFoundNoResult, allowRetry {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    reverse(allowRetry: false)
                }
                return
            }
            // 其它错误或仍无结果：返回 nil（调用方用 Unknown 等兜底）
            completion(nil)
        }
    }

    reverse(allowRetry: true)
}

func isCoordinateLikeString(_ s: String) -> Bool {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    // 允许前后空格、正负号、小数；不做经纬度范围校验，仅用于“像不像坐标”的判定
    let pattern = #"^\s*-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?\s*$"#
    return trimmed.range(of: pattern, options: .regularExpression) != nil
}




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
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
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
private func parseBirthDateString(_ s: String) -> Date? {
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
import SwiftUI

struct LoadingView: View {
    var onStartLoading: (() -> Void)? = nil
    
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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackgroundView()
                    .environmentObject(starManager)

                // === Nebula effects ===
                // Blue nebula
                Circle()
                    .fill(Color(.sRGB, red: 59/255, green: 130/255, blue: 246/255, opacity: 0.10))
                    .frame(width: 384, height: 384)
                    .scaleEffect(1.5)
                    .blur(radius: 48)
                    .offset(x: geo.size.width * -0.17, y: geo.size.height * -0.25)

                // Purple nebula
                Circle()
                    .fill(Color(.sRGB, red: 168/255, green: 85/255, blue: 247/255, opacity: 0.10))
                    .frame(width: 320, height: 320)
                    .scaleEffect(1.2)
                    .blur(radius: 48)
                    .offset(x: geo.size.width * 0.25, y: geo.size.height * 0.18)

                // === Central radial glow ===
                RadialGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.05), .clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: min(geo.size.width, geo.size.height) * 0.5
                )
                .allowsHitTesting(false)

                // === Main content ===
                VStack(spacing: 32) {
                    let disk: CGFloat = 96

                    // Logo（透明背景 + 颜色跟随 ThemeManager）
                    ZStack {
                        let iconColor: Color = themeManager.primaryText

                        Image("appLogo")
                            .resizable()
                            .renderingMode(.template)   // 使用 template 方便着色
                            .scaledToFit()
                            .frame(width: disk, height: disk)
                            .foregroundColor(iconColor)  // 月亮等标识颜色 = 主题文字颜色
                            .shadow(color: iconColor.opacity(0.35), radius: 24, x: 0, y: 8)
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
                    VStack(spacing: 8) {
                        Text("Alynna")
                            .font(AlignaType.brandTitle())       // Gloock 34
                            .lineSpacing(40 - 34)                // 6
                            .foregroundColor(.white)
                            .shimmer()

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.6), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 128, height: 1)
                    }

                    // Spinner (two rings)
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.20), lineWidth: 2)
                            .frame(width: 64, height: 64)

                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(spinFast ? 360 : 0))
                            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: spinFast)

                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
                        Text(loadingMessages[msgIndex])
                            .font(AlignaType.loadingSubtitle())  // Merriweather Italic 16
                            .lineSpacing(AlignaType.body16LineSpacing)
                            .foregroundColor(.white.opacity(0.9))
                            
                        HStack(spacing: 6) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(Color.white.opacity(0.6))
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
                // Rotate messages every 2s
                Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        msgIndex = (msgIndex + 1) % loadingMessages.count
                    }
                }
                withAnimation {
                    dotPhase = 1
                }
            }
            .preferredColorScheme(themeManager.preferredColorScheme)
        }
    }

    // mimic three “animate-bounce-dot-*” offsets
    private func dotOffset(for i: Int) -> CGFloat {
        let up = (Int(dotPhase) + i) % 2 == 0
        return up ? -4 : 0
    }
}


import SwiftUI

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
            
            RadialGradient(
                colors: [Color.white.opacity(0.06), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .allowsHitTesting(false)

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
                    .shadow(color: iconColor.opacity(0.35), radius: 22, x: 0, y: 8)
                
                // Brand + hairline underline
                VStack(spacing: 6) {
                    Text("Alynna")
                        .font(AlignaType.brandTitle())
                       .lineSpacing(40 - 34)
                       .foregroundColor(.white)
                
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.7), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 120, height: 1)
                }

                // Info rows（统一字号 16、行间距约 22，首字母对齐）
                VStack(alignment: .leading, spacing: 10) {
                    infoLine(icon: "📍",
                             text: location,
                             textOpacity: 0.9)

                    infoLine(icon: zodiacIcon,
                             text: zodiacText,
                             textOpacity: 0.85)

                    // 这里改成 cleanMoonText，这样只有左边一个固定的 🌙 emoji
                    infoLine(icon: "🌙",
                             text: cleanMoonText,
                             textOpacity: 0.75)
                }
                .padding(.top, 6)
                .padding(.horizontal, 30)
                .frame(maxWidth: 260, alignment: .leading)
            }
            .multilineTextAlignment(.leading)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)
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
                .foregroundColor(.white.opacity(textOpacity))
                .font(.custom("Merriweather-Regular", size: 16))
                .lineSpacing(AlignaType.body16LineSpacing)
        }
    }
}


enum AlignaType {
    static func logo() -> Font { .custom("CormorantGaramond-Bold", size: 38) }
    static func brandTitle() -> Font { .custom("Gloock-Regular", size: 34) }

    static func homeSubtitle() -> Font { .custom("Merriweather-Italic", size: 18) }

    static func gridCategoryTitle() -> Font { .custom("Merriweather-Black", size: 18) }
    static func gridItemName() -> Font { .custom("Merriweather-Light", size: 16) }

    static func loadingSubtitle() -> Font { .custom("Merriweather-Italic", size: 16) }
    static func helperSmall() -> Font { .custom("Merriweather24pt-Light", size: 14) }

    static let logoLineSpacing: CGFloat = 44 - 38   // 6
    static let descLineSpacing: CGFloat = 26 - 18   // 8
    static let body16LineSpacing: CGFloat = 22 - 16 // 6
    static let small14LineSpacing: CGFloat = 20 - 14// 6
}




struct FirstPageView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @AppStorage("lastRecommendationDate") var lastRecommendationDate: String = ""
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("lastCurrentPlaceUpdate") var lastCurrentPlaceUpdate: String = ""
    @AppStorage("todayFetchLock") private var todayFetchLock: String = ""  // 当天的拉取互斥锁
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @State private var isFetchingToday: Bool = false

    // 🔐 当天是否已经触发过一次“自动兜底重拉”
    @AppStorage("todayAutoRefetchDone") private var todayAutoRefetchDone: String = ""
    // 本次进程是否已经安排过 watchdog 计时器（避免重复安排）
    @State private var autoRefetchScheduled = false
    
    // === 放在 FirstPageView 的属性区（和其他 @State / @AppStorage 放一起）===

    // NEW: 认证监听 + 看门狗计数（跨天持久）
    @State private var authListenerHandle: AuthStateDidChangeListenerHandle? = nil
    @State private var authWaitTimedOut = false

    @AppStorage("watchdogDay") private var watchdogDay: String = ""
    @AppStorage("todayAutoRefetchAttempts") private var todayAutoRefetchAttempts: Int = 0  // 当天已重试次数

    // NEW: 多次重试的配置
    private let maxRefetchAttempts = 3
    private let initialRefetchDelay: TimeInterval = 8.0

    @StateObject private var locationManager = LocationManager()
    @State private var recommendationTitles: [String: String] = [:]
    
    @State private var selectedDate = Date()
    
    @State private var bootPhase: BootPhase = .loading
    @State private var splashLocation: String = "Your Current Location"
    @State private var splashZodiac: String = ""
    @State private var splashMoon: String = ""
    
    @State private var didBootVisuals = false
    
    private func ensureDefaultsIfMissing() {
        // If nothing loaded yet, supply local demo content
        if viewModel.recommendations.isEmpty {
            viewModel.recommendations = DesignRecs.docs
            viewModel.dailyMantra = viewModel.dailyMantra.isEmpty ? DesignRecs.mantra : viewModel.dailyMantra
        }
        // If we don’t have human-facing titles yet, use local titles
        if recommendationTitles.isEmpty {
            recommendationTitles = DesignRecs.titles
        }
    }
    
    private var mainContent: some View {
        NavigationStack {
            ZStack {
                // ✅ Full-screen background, not constrained by inner GeometryReader
                AppBackgroundView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .ignoresSafeArea()

                // ✅ Foreground content uses GeometryReader for layout
                GeometryReader { geometry in
                    let minLength = min(geometry.size.width, geometry.size.height)

                    VStack(spacing: minLength * 0.015) {
                        // 顶部按钮
                        HStack {
                            
                            HStack(spacing: geometry.size.width * 0.035) {
                                // Timeline / calendar
                                NavigationLink(
                                    destination: ContentView()
                                        .environmentObject(starManager)
                                        .environmentObject(themeManager)
                                        .environmentObject(viewModel)
                                ) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20))
                                        .foregroundColor(themeManager.foregroundColor)
                                        .frame(width: 28, height: 28)
                                }

                                // Journal button – book icon
                                NavigationLink(
                                    destination: JournalView(date: selectedDate)
                                        .environmentObject(starManager)
                                        .environmentObject(themeManager)
                                ) {
                                    Image(systemName: "book.closed")      // ⬅️ journal symbol
                                        .font(.system(size: 20))
                                        .foregroundColor(themeManager.foregroundColor)
                                        .frame(width: 28, height: 28)
                                }
                            }
                            .padding(.leading, geometry.size.width * 0.05)

                            Spacer()

                            HStack(spacing: geometry.size.width * 0.04) {
                                if isLoggedIn {
                                    NavigationLink(
                                        destination: AccountDetailView(viewModel: OnboardingViewModel())
                                            .environmentObject(starManager)
                                            .environmentObject(themeManager)
                                    ) {
                                        Image("account")
                                            .resizable()
                                            .renderingMode(.template)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(themeManager.foregroundColor)
                                    }
                                } else {
                                    NavigationLink(
                                        destination: AccountDetailView(viewModel: OnboardingViewModel())
                                    ) {
                                        Image("account")
                                            .resizable()
                                            .renderingMode(.template)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(themeManager.foregroundColor)
                                    }
                                }
                            }
                            .padding(.trailing, geometry.size.width * 0.05)
                        }
//                        .padding(.top, 120)
//                        .padding(.horizontal, geometry.size.width * 0.05)

                        Text("Alynna")
                            .font(AlignaType.logo())
                            .lineSpacing(AlignaType.logoLineSpacing)
                            .foregroundColor(themeManager.foregroundColor)
                            .padding(.top, 20)

                        Text(viewModel.dailyMantra)
                            .font(AlignaType.homeSubtitle())
                            .lineSpacing(AlignaType.descLineSpacing) // 26-18=8
                            .multilineTextAlignment(.center)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.7))
                            .padding(.horizontal, geometry.size.width * 0.1)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()

                        VStack(spacing: minLength * 0.05) {
                            let columns = [
                                GridItem(.flexible(), alignment: .center),
                                GridItem(.flexible(), alignment: .center)
                            ]

                            LazyVGrid(columns: columns,
                                      spacing: geometry.size.height * 0.023) {
                                navItemView(title: "Place", geometry: geometry)
                                navItemView(title: "Gemstone", geometry: geometry)
                                navItemView(title: "Color", geometry: geometry)
                                navItemView(title: "Scent", geometry: geometry)
                                navItemView(title: "Activity", geometry: geometry)
                                navItemView(title: "Sound", geometry: geometry)
                                navItemView(title: "Career", geometry: geometry)
                                navItemView(title: "Relationship", geometry: geometry)
                            }
                            .padding(.horizontal, geometry.size.width * 0.05)
                        }

                        // ✅ 给底部说明文字留出空间
                        Spacer().frame(height: geometry.size.height * 0.11)
                    }
                    .padding(.top, 16)
                    .frame(width: geometry.size.width,
                           height: geometry.size.height,
                           alignment: .top)
                    .preferredColorScheme(themeManager.preferredColorScheme)
                    .onAppear {
                        starManager.animateStar = true
                        themeManager.appBecameActive()
                        ensureDefaultsIfMissing()
                        fetchAllRecommendationTitles()
                    }
                }
            }
            // ✅ 只作用在首页这个 ZStack 上，push 新页面后不会带过去
            .safeAreaInset(edge: .bottom) {
                Text("The daily rhythms above are derived from integrated modeling of Earth observation, climate, air-quality, physiological, and astrological data, updated in real time.")
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.foregroundColor.opacity(0.28))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 0)
            }
        }
        .navigationViewStyle(.stack)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }


    private func persistWidgetSnapshotFromViewModel() {
//        // 你已有：viewModel.dailyMantra, recommendationTitles["Color"/"Place"/"Gemstone"/"Scent"]
//        let snap = AlignaWidgetSnapshot(
//            mantra: viewModel.dailyMantra.isEmpty ? "Find your flow." : viewModel.dailyMantra,
//            colorTitle: recommendationTitles["Color"] ?? "Color",
//            placeTitle: recommendationTitles["Place"] ?? "Place",
//            gemstoneTitle: recommendationTitles["Gemstone"] ?? "Gemstone",
//            scentTitle: recommendationTitles["Scent"] ?? "Scent"
//        )
//        AlignaWidgetStore.save(snap) // ↩︎ 写入 App Group + 刷新 Widget
    }

    
    // 冷启动只看“是否已登录 + 本地标记”来分流；不再在这里查 Firestore 决定是否强拉 Onboarding。
    // === 替换你原来的 startInitialLoad()（整段替换） ===
    private func startInitialLoad() {
        
        
        #if DEBUG
        if _isPreview { bootPhase = .main; return }
        #endif
        // 冷启动先“等用户恢复”，最多等一小会（例如 6 秒）
        waitForAuthenticatedUserThenBoot(maxWait: 6.0)
    }

    // NEW: 等待 Firebase 恢复 currentUser 后再走原有分流逻辑
    private func waitForAuthenticatedUserThenBoot(maxWait: TimeInterval) {
        // 每天首次启动：重置 watchdog 计数/锁
        resetDailyWatchdogIfNeeded()

        if let user = Auth.auth().currentUser, !authWaitTimedOut {
            // 已有用户（或超时标记未触发）：按你原来的分流逻辑走
            // A) 未登录
            if user.uid.isEmpty {
                shouldOnboardAfterSignIn = false
                hasCompletedOnboarding = false
                withAnimation(.easeInOut) { bootPhase = .onboarding }
                return
            }
            // B) 刚注册需要走引导
            if shouldOnboardAfterSignIn && !hasCompletedOnboarding {
                withAnimation(.easeInOut) { bootPhase = .onboarding }
                return
            }
            // C) 正常首页启动
            shouldOnboardAfterSignIn = false
            proceedNormalBoot()
            return
        }

        // 没有 currentUser：安装监听，等待恢复
        if authListenerHandle == nil {
            authListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
                if user != nil {
                    // 恢复到用户了 → 移除监听并启动
                    if let h = authListenerHandle { Auth.auth().removeStateDidChangeListener(h) }
                    authListenerHandle = nil
                    authWaitTimedOut = false
                    waitForAuthenticatedUserThenBoot(maxWait: 0) // 递归调用进入分流
                }
            }
        }

        // 兜底超时：防止无限等。到时仍未恢复用户，就按“未登录”进入。
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.5, maxWait)) {
            guard Auth.auth().currentUser == nil else { return }
            authWaitTimedOut = true
            if let h = authListenerHandle { Auth.auth().removeStateDidChangeListener(h) }
            authListenerHandle = nil
            // 超时还没恢复用户 → 走未登录 OpeningPage
            shouldOnboardAfterSignIn = false
            hasCompletedOnboarding = false
            withAnimation(.easeInOut) { bootPhase = .onboarding }
        }
    }

    // NEW: 按自然日重置 watchdog 相关的 @AppStorage
    private func resetDailyWatchdogIfNeeded() {
        let today = todayString()
        if watchdogDay != today {
            watchdogDay = today
            todayAutoRefetchAttempts = 0
            todayAutoRefetchDone = ""   // 你原有的“一次触发标记”也清掉
            todayFetchLock = ""         // 清理潜在残留锁
        }
    }

    // ====== FirstPageView 内新增 ======
    private func hydrateBirthFromProfileIfNeeded(_ done: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { done(); return }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)
        ref.getDocument { snap, _ in
            defer { done() }
            guard let data = snap?.data() else { return }
            

            // birth date
            if let ts = data["birthday"] as? Timestamp {
                viewModel.birth_date = ts.dateValue()
            } else if let s = data["birthDate"] as? String,
                      let d = parseBirthDateString(s) {
                viewModel.birth_date = d
            }


            // birth time（统一通过 timeToDateFlexible 解析成本地时区的“时分锚定”Date）
            if let t = data["birthTime"] as? String, let d = timeToDateFlexible(t) {
                viewModel.birth_time = d
            }

            // ✅ 出生经纬度 → 注入 viewModel（供上升星座使用）
            if let lat = data["birthLat"] as? CLLocationDegrees,
               let lng = data["birthLng"] as? CLLocationDegrees,
               lat != 0 || lng != 0 {
                viewModel.birthCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }
    }


    // 原先 startInitialLoad 的主体逻辑移到这里（不修改其内容）
    private func proceedNormalBoot() {
        
        startAutoRefetchWatchdog(delay: 8.0)
        locationManager.requestLocation()

        let group = DispatchGroup()

        // FIX: 先把生日/时间从用户档案同步到 viewModel
        group.enter()
        hydrateBirthFromProfileIfNeeded { group.leave() }

        group.enter()
        ensureDailyCurrentPlaceSaved { group.leave() }

        group.enter()
        fetchAndSaveRecommendationIfNeeded()
        waitUntilRecommendationsReady(timeout: 12) { group.leave() }

        group.notify(queue: .main) {
            resolveSplashInfoAndAdvance()
        }
    }


    private func ensureDailyCurrentPlaceSaved(completion: @escaping () -> Void) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: Date())

        // 当天已经写过了，直接过
        if lastCurrentPlaceUpdate == today {
            completion()
            return
        }

        // 等待定位（最多等 8 秒）
        let start = Date()
        let waitLimit: TimeInterval = 8.0

        func attempt() {
            if let coord = locationManager.currentLocation {
                // 有坐标 → 反地理解析城市名 → 写入 Firestore
                getAddressFromCoordinate(coord) { city in
                    let place = city ?? "Unknown"
                    upsertUserCurrentPlace(place: place, coord: coord) { ok in
                        if ok { lastCurrentPlaceUpdate = today }
                        completion()
                    }
                }
                return
            }

            // 超时兜底：没有坐标也尽量落一次（Unknown），不阻塞启动
            if Date().timeIntervalSince(start) > waitLimit {
                upsertUserCurrentPlace(place: "Unknown", coord: nil) { ok in
                    if ok { lastCurrentPlaceUpdate = today }
                    completion()
                }
                return
            }

            // 继续等
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { attempt() }
        }

        attempt()
    }
    private func upsertUserCurrentPlace(
        place: String,
        coord: CLLocationCoordinate2D?,
        completion: @escaping (Bool) -> Void
    ) {
        guard let user = Auth.auth().currentUser else {
            print("❌ 未登录，跳过写入 currentPlace")
            completion(false)
            return
        }
        let db = Firestore.firestore()

        var fields: [String: Any] = ["currentPlace": place]
        if let c = coord {
            fields["currentLat"] = c.latitude
            fields["currentLng"] = c.longitude
        }

        func write(to ref: DocumentReference) {
            ref.setData(fields, merge: true) { err in
                if let err = err {
                    print("❌ 更新 currentPlace 失败：\(err.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ 已更新用户 currentPlace: \(place)")
                    completion(true)
                }
            }
        }

        // 1) users 按 uid
        db.collection("users").whereField("uid", isEqualTo: user.uid).limit(to: 1).getDocuments { s1, _ in
            if let doc = s1?.documents.first { write(to: doc.reference); return }

            // 2) user 按 uid
            db.collection("user").whereField("uid", isEqualTo: user.uid).limit(to: 1).getDocuments { s2, _ in
                if let doc2 = s2?.documents.first { write(to: doc2.reference); return }

                // 3) users / user 按 email（如有）
                if let email = user.email {
                    db.collection("users").whereField("email", isEqualTo: email).limit(to: 1).getDocuments { s3, _ in
                        if let d3 = s3?.documents.first { write(to: d3.reference); return }

                        db.collection("user").whereField("email", isEqualTo: email).limit(to: 1).getDocuments { s4, _ in
                            if let d4 = s4?.documents.first { write(to: d4.reference); return }

                            // 4) 都没有 → 在 users 新建最小档案
                            var payload = fields
                            payload["uid"] = user.uid
                            payload["email"] = email
                            payload["createdAt"] = Timestamp()
                            db.collection("users").addDocument(data: payload) { err in
                                if let err = err {
                                    print("❌ 创建用户文档失败：\(err.localizedDescription)")
                                    completion(false)
                                } else {
                                    print("✅ 已创建用户文档并写入 currentPlace")
                                    completion(true)
                                }
                            }
                        }
                    }
                } else {
                    // 没有 email：用 uid 最小化建档
                    var payload = fields
                    payload["uid"] = user.uid
                    payload["createdAt"] = Timestamp()
                    db.collection("users").addDocument(data: payload) { err in
                        if let err = err {
                            print("❌ 创建用户文档失败：\(err.localizedDescription)")
                            completion(false)
                        } else {
                            print("✅ 已创建用户文档并写入 currentPlace")
                            completion(true)
                        }
                    }
                }
            }
        }
    }




    /// Polls viewModel.recommendations until non-empty (or timeout)
    private func waitUntilRecommendationsReady(timeout: TimeInterval = 12, poll: TimeInterval = 0.2, onReady: @escaping () -> Void) {
        let start = Date()
        func check() {
            if !viewModel.recommendations.isEmpty {
                onReady()
                return
            }
            if Date().timeIntervalSince(start) > timeout {
                // Timeout: still move on (you can choose to stay on loading if you prefer)
                onReady()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + poll, execute: check)
        }
        check()
    }

    private func resolveSplashInfoAndAdvance() {
        // Compute zodiac/moon locally (fast)
        splashZodiac = currentZodiacSign()
        splashMoon   = currentMoonPhaseLabel()

        // Resolve a friendly city name if we have coordinates now
        if let coord = locationManager.currentLocation {
            getAddressFromCoordinate(coord) { place in
                splashLocation = place ?? "Your Current Location"
                withAnimation(.easeInOut) { bootPhase = .infoSplash }
            }
        } else {
            splashLocation = "Your Current Location"
            withAnimation(.easeInOut) { bootPhase = .infoSplash }
        }
    }



    var body: some View {
        Group {
            switch bootPhase {
            case .loading:
                LoadingView(onStartLoading: {
                    startInitialLoad()
                })
                .ignoresSafeArea()
                
            case .onboarding:
                NavigationStack {
                    if shouldOnboardAfterSignIn {
                        // 注册后正式进入引导：Step1
                        OnboardingStep1(viewModel: viewModel)
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .navigationBarBackButtonHidden(true)
                    } else {
                        // 冷启动未登录：先到 OpeningPage（包含 Sign Up / Log In）
                        OnboardingOpeningPage()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .navigationBarBackButtonHidden(true)
                    }
                }
                
            case .infoSplash:
                WelcomeSplashView(location: splashLocation,
                                  zodiac: splashZodiac,
                                  moon: splashMoon)
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .onAppear {
                    // Show the splash briefly, then go main
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut) { bootPhase = .main }
                    }
                }
                .ignoresSafeArea()
                
            case .main:
                mainContent // (extract your existing NavigationStack content into a computed var)
            }
        }
        .onAppear {
            // run once on cold start
            guard !didBootVisuals else { return }
            didBootVisuals = true

            starManager.animateStar = true
            themeManager.appBecameActive()
        }
    }
    

    private func fetchAllRecommendationTitles() {
        #if DEBUG
        if _isPreview { return }
        #endif
        
        let db = Firestore.firestore()

        for (rawCategory, rawDoc) in viewModel.recommendations {
            // 统一得到规范写法（如果已经是规范写法，也会直接返回自身）
            guard let canon = canonicalCategory(from: rawCategory) ?? canonicalCategory(from: rawCategory.capitalized) ?? rawCategory as String? else {
                print("⚠️ 跳过未知类别：\(rawCategory)")
                continue
            }
            guard let collection = firebaseCollectionName(for: canon) else {
                print("⚠️ 未知集合映射：\(canon)")
                continue
            }

            let documentName = sanitizeDocumentName(rawDoc)
            guard !documentName.isEmpty else {
                print("⚠️ 跳过空文档名（\(canon)）")
                continue
            }

            db.collection(collection).document(documentName).getDocument { snapshot, error in
                if let error = error {
                    print("❌ 加载 \(canon) 标题失败: \(error)")
                    return
                }
                if let data = snapshot?.data(), let title = data["title"] as? String {
                    DispatchQueue.main.async {
                        self.recommendationTitles[canon] = title // 以规范写法作键
                    }
                } else {
                    print("⚠️ \(canon)/\(documentName) 无 title 字段或文档不存在")
                }
            }
        }
    }

    /// 启动“保底看门狗”：若 delay 秒后仍未拿到 mantra 或推荐，则强制走一次 FastAPI 重拉
    // === 替换你原有的 startAutoRefetchWatchdog(delay:)（整段替换） ===
    private func startAutoRefetchWatchdog(delay: TimeInterval = 8.0) {
        // 只安排一次根任务
        guard !autoRefetchScheduled else { return }
        autoRefetchScheduled = true

        func scheduleNext(after: TimeInterval) {
            // 已经有数据就不用继续重试了
            let mantraReady = !viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let recsReady   = !viewModel.recommendations.isEmpty
            if mantraReady && recsReady { return }

            // 达到上限就停
            if todayAutoRefetchAttempts >= maxRefetchAttempts { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + after) {
                // 进入具体一次尝试：再次判断是否已经就绪
                let readyNow = !viewModel.dailyMantra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.recommendations.isEmpty
                guard !readyNow else { return }

                // 触发一次强制重拉
                print("🛡️ Watchdog attempt #\(todayAutoRefetchAttempts + 1)")
                forceRefetchDailyIfNotLocked()

                // 增加计数并安排下一次（指数退避，封顶 60s）
                todayAutoRefetchAttempts += 1
                let nextDelay = min(60.0, max(6.0, after * 1.8))
                scheduleNext(after: nextDelay)
            }
        }

        scheduleNext(after: delay <= 0 ? initialRefetchDelay : delay)
    }


    /// 强制当日重拉（跳过“今日已有推荐”的判断），仍复用今日互斥锁与定位等待
    // === 替换你原有的 forceRefetchDailyIfNotLocked()（整段替换） ===
    private func forceRefetchDailyIfNotLocked() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法强制重拉"); return
        }
        let today = todayString()
        let docRef = todayDocRef(uid: uid, day: today)

        // 若已有在途请求，就不重复发
        if todayFetchLock == today || isFetchingToday {
            print("⏳ Watchdog: 今日请求已在进行中，跳过强制重拉")
            return
        }

        todayFetchLock = today
        isFetchingToday = true

        // Watchdog 重拉也需要定位；没有的话先申请并等待
        if locationManager.currentLocation == nil {
            locationManager.requestLocation()
        }
        waitForLocationThenRequest(uid: uid, today: today, docRef: docRef)
    }


    
    // 当天字符串
    private func todayString() -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    // 当天唯一 DocID：uid_yyyy-MM-dd
    private func todayDocRef(uid: String, day: String) -> DocumentReference {
        Firestore.firestore()
            .collection("daily_recommendation")
            .document("\(uid)_\(day)")
    }

    // 等待定位后只发一次请求（最多等 8 秒）
    private func waitForLocationThenRequest(uid: String, today: String, docRef: DocumentReference) {
        let start = Date()
        let limit: TimeInterval = 8.0

        func attempt() {
            if let coord = locationManager.currentLocation {
                fetchFromFastAPIAndSave(coord: coord, userId: uid, today: today, docRef: docRef)
                return
            }
            if Date().timeIntervalSince(start) > limit {
                print("⚠️ 超时仍未拿到坐标，本次放弃生成；稍后可重试")
                todayFetchLock = ""  // 释放互斥锁
                isFetchingToday = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: attempt)
        }
        attempt()
    }

    private func fetchAndSaveRecommendationIfNeeded() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ 用户未登录，跳过获取推荐"); return
        }
        let today = todayString()
        let docRef = todayDocRef(uid: uid, day: today)

        // 单日互斥：同一天只允许一条在途请求
        if todayFetchLock == today || isFetchingToday {
            print("⏳ 今日拉取已在进行或已加锁，跳过二次触发")
            return
        }

        // 直接命中 docId 判断是否已有今日推荐（避免并发竞态）
        docRef.getDocument { snap, err in
            if let err = err {
                print("❌ 查询今日推荐失败：\(err.localizedDescription)")
                return
            }
            if (snap?.exists ?? false) {
                print("📌 今日已有推荐（docId 命中），不重复生成")
                let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                lastRecommendationDate = today
                loadTodayRecommendation()
                return
            }

            // 尚无今日记录 → 加锁并等待定位就绪后只发一次
            todayFetchLock = today
            isFetchingToday = true
            if locationManager.currentLocation == nil {
                locationManager.requestLocation()
            }
            waitForLocationThenRequest(uid: uid, today: today, docRef: docRef)
        }
    }

    
    private func fetchFromFastAPIAndSave(
        coord: CLLocationCoordinate2D,
        userId: String,
        today: String,
        docRef: DocumentReference
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let birthDateString = dateFormatter.string(from: viewModel.birth_date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let birthTimeString = timeFormatter.string(from: viewModel.birth_time)

        let payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": coord.latitude,
            "longitude": coord.longitude
        ]

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
            print("❌ 无效的 FastAPI URL")
            todayFetchLock = ""; isFetchingToday = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ JSON 序列化失败: \(error)")
            todayFetchLock = ""; isFetchingToday = false
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer {                    // 不管成功失败都释放“今日锁”
                DispatchQueue.main.async {
                    todayFetchLock = ""
                    isFetchingToday = false
                }
            }

            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                return
            }
            guard let http = response as? HTTPURLResponse else {
                print("❌ 非 HTTP 响应"); return
            }
            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data ?? Data(), encoding: .utf8) ?? "<no body>"
                print("❌ 非 2xx：\(http.statusCode), body=\(body)")
                return
            }
            guard let data = data else { print("❌ 空数据"); return }

            do {
                if let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let recs = parsed["recommendations"] as? [String: String],
                   let mantra = parsed["mantra"] as? String {

                    DispatchQueue.main.async {
                        // ✅ 把后端 recommendations 的 key 统一成规范写法
                        let normalized: [String: String] = recs.reduce(into: [:]) { acc, kv in
                            if let canon = canonicalCategory(from: kv.key) {
                                acc[canon] = sanitizeDocumentName(kv.value)
                            }
                        }

                        // 更新本地
                        viewModel.recommendations = normalized
                        viewModel.dailyMantra = mantra
                        lastRecommendationDate = today

                        // 先刷新标题（UI 需要）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            fetchAllRecommendationTitles()
                        }

                        // 幂等：固定 docId = uid_yyyy-MM-dd，setData(merge:)
                        var recommendationData: [String: Any] = normalized   // ← 用规范写法保存
                        recommendationData["uid"] = userId
                        recommendationData["createdAt"] = today
                        recommendationData["mantra"] = mantra

                        docRef.setData(recommendationData, merge: true) { err in
                            if let err = err {
                                print("❌ 保存 daily_recommendation 失败：\(err)")
                            } else {
                                print("✅ 今日推荐已保存（幂等写入）")
                            }
                        }
                        persistWidgetSnapshotFromViewModel()
                    }
                }
            } catch {
                print("❌ FastAPI 响应解析失败: \(error)")
                print("↳ raw body:", String(data: data ?? Data(), encoding: .utf8) ?? "<binary>")
            }
        }.resume()
    }

    
    
    
    private func navItemView(title: String, geometry: GeometryProxy) -> some View {
        let documentName = viewModel.recommendations[title] ?? ""
        let startCat = RecCategory(rawValue: title) // "Place" -> .Place
        
        return Group {
            if let startCat, !documentName.isEmpty {
                        NavigationLink {
                            // Build the docs map for all eight categories from your viewModel
                            let docsMap: [RecCategory: String] = Dictionary(uniqueKeysWithValues:
                                RecCategory.allCases.map { cat in
                                    let key = cat.rawValue
                                    return (cat, viewModel.recommendations[key] ?? "")
                                }
                            )
                            RecommendationPagerView(docsByCategory: docsMap, selected: startCat)
                                .environmentObject(starManager)
                                .environmentObject(themeManager)
                                .environmentObject(viewModel)
                        } label: {
                    VStack(spacing: 2) {   // ⬅️ tighter spacing
                        // 图标图像
                        SafeImage(name: documentName, renderingMode: .template, contentMode: .fit)
                            .foregroundColor(themeManager.foregroundColor)
                            .frame(width: geometry.size.width * 0.18)  // slightly smaller to balance text
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 1.5)
                        
                        // 推荐名称（小字体，紧贴图标）
                        Text(recommendationTitles[title] ?? "")
                            .font(AlignaType.gridItemName())
                            .lineSpacing(AlignaType.body16LineSpacing) // 22-16=6
                            .foregroundColor(themeManager.foregroundColor.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        // 类别标题（和上面稍微拉开）
                        Text(title)
                            .font(AlignaType.gridCategoryTitle())
                            .lineSpacing(34 - 28) // 6
                            .foregroundColor(themeManager.foregroundColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            } else {
                Button {
                    print("⚠️ 无法进入 '\(title)'，推荐结果尚未加载")
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "questionmark.square.dashed")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.18)
                            .foregroundColor(themeManager.foregroundColor.opacity(0.4))
                        
                        Text("Loading")
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.033))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.5))
                        
                        Text(title)
                            .font(Font.custom("PlayfairDisplay-Regular", size: geometry.size.width * 0.05))
                            .foregroundColor(themeManager.foregroundColor.opacity(0.5))
                    }
                }
            }
        }
    }
    
    
    
    @ViewBuilder
    private func viewForCategory(title: String, documentName: String) -> some View {
        switch title {
        case "Place":
            PlaceDetailView(documentName: documentName)
        case "Gemstone":
            GemstoneDetailView(documentName: documentName)
        case "Color":
            ColorDetailView(documentName: documentName)
        case "Scent":
            ScentDetailView(documentName: documentName)
        case "Activity":
            ActivityDetailView(
                documentName: documentName
//                soundDocumentName: viewModel.recommendations["Sound"] ?? ""
            )
        case "Sound":
            SoundDetailView(documentName: documentName)
        case "Career":
            CareerDetailView(documentName: documentName)
        case "Relationship":
            RelationshipDetailView(documentName: documentName)
        default:
            Text("⚠️ Unknown Category")
        }
    }
    
    
    private func loadTodayRecommendation() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法获取推荐")
            return
        }

        let db = Firestore.firestore()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        db.collection("daily_recommendation")
            .whereField("uid", isEqualTo: userId)
            .whereField("createdAt", isEqualTo: today)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ 查询推荐失败：\(error). 使用本地默认内容")
                    ensureDefaultsIfMissing()
                    return
                }
                guard let documents = snapshot?.documents, let doc = documents.first else {
                    print("⚠️ 今日暂无推荐数据。使用本地默认内容")
                    ensureDefaultsIfMissing()
                    return
                }

                var recs: [String: String] = [:]
                var fetchedMantra = ""

                for (key, value) in doc.data() {
                    if key == "mantra", let mantraText = value as? String {
                        fetchedMantra = mantraText
                        continue
                    }
                    if key == "uid" || key == "createdAt" { continue }

                    // ✅ 关键：把后端 key 做大小写无关匹配 → 规范写法
                    if let canon = canonicalCategory(from: key), let str = value as? String {
                        recs[canon] = sanitizeDocumentName(str)
                    } else {
                        print("ℹ️ 忽略非推荐字段或未知类别：\(key)")
                    }
                }

                DispatchQueue.main.async {
                    self.viewModel.recommendations = recs   // 用规范写法作字典 key
                    self.viewModel.dailyMantra = fetchedMantra
                    fetchAllRecommendationTitles()           // 读取标题时就能命中正确集合
                    persistWidgetSnapshotFromViewModel()
                    print("✅ 成功加载今日推荐：\(recs)")
                }
            }
    }

    // === Case-insensitive category normalization ===
    // 后端可能返回 "color" / "Color" / "COLOR"；统一映射到规范写法
    private let categoryCanonicalMap: [String: String] = [
        "place": "Place",
        "gemstone": "Gemstone",
        "color": "Color",
        "scent": "Scent",
        "activity": "Activity",
        "sound": "Sound",
        "career": "Career",
        "relationship": "Relationship"
    ]

    private func canonicalCategory(from raw: String) -> String? {
        categoryCanonicalMap[raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    // ✅ 仅允许的类别白名单
    private let allowedCategories: Set<String> = [
        "Place", "Gemstone", "Color", "Scent",
        "Activity", "Sound", "Career", "Relationship"
    ]

    // ✅ 类别 -> 集合名 映射函数（返回可选，未知类别返回 nil）
    private func firebaseCollectionName(for rawCategory: String) -> String? {
        let category = rawCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        switch category {
        case "Place":        return "places"
        case "Gemstone":     return "gemstones"
        case "Color":        return "colors"
        case "Scent":        return "scents"
        case "Activity":     return "activities"
        case "Sound":        return "sounds"
        case "Career":       return "careers"
        case "Relationship": return "relationships"
        default:
            return nil
        }
    }

    // ✅ 文档名清洗：移除会破坏路径的字符（如 /、\、# 等）
    //   Firestore 文档 ID 不允许包含斜杠；这里最小清洗，保留字母数字下划线与连字符。
    private func sanitizeDocumentName(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


enum DesignRecs {
    static let docs: [String:String] = [
        "Place": "echo_niche",
        "Gemstone": "amethyst",
        "Color": "amber",
        "Scent": "bergamot",
        "Activity": "clean_mirror",
        "Sound": "brown_noise",
        "Career": "clear_channel",
        "Relationship": "breathe_sync"
    ]
    static let titles: [String:String] = [
        "Place": "Echo Niche", "Gemstone": "Amethyst", "Color": "Amber",
        "Scent": "Bergamot", "Activity": "Polishing Mirror",
        "Sound": "Brown Noise", "Career": "Clear Channel",
        "Relationship": "Breathe in Sync"
    ]
    static let mantra = "Find your flow."
}


#if DEBUG
extension FirstPageView {
    init(previewBoot: BootPhase) {
        self.init()
        _bootPhase = State(initialValue: previewBoot) // jump straight to .main
    }
}
#endif

#if DEBUG
struct FirstPageView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = OnboardingViewModel()
        vm.recommendations = [
            "Place": "echo_niche",
            "Gemstone": "amethyst",
            "Color": "amber",
            "Scent": "bergamot",
            "Activity": "clean_mirror",
            "Sound": "brown_noise",
            "Career": "clear_channel",
            "Relationship": "breathe_sync"
        ]
        vm.dailyMantra = "Find your flow."

        return FirstPageView(previewBoot: .main)
            .environmentObject(StarAnimationManager())
            .environmentObject(ThemeManager())
            .environmentObject(vm)
            .previewDisplayName("FirstPage main grid")
    }
}
#endif

#if DEBUG
let _isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#endif


enum RecCategory: String, CaseIterable, Identifiable {
    case Place, Gemstone, Color, Scent, Activity, Sound, Career, Relationship
    var id: String { rawValue }
}

struct RecommendationPagerView: View {
    let docsByCategory: [RecCategory: String]
    @State var selected: RecCategory
    
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Full-bleed background
            AppBackgroundView()
                .environmentObject(starManager)
                .ignoresSafeArea() // <- key line

            TabView(selection: $selected) {
                ForEach(RecCategory.allCases) { cat in
                    Group {
                        if let doc = docsByCategory[cat], !doc.isEmpty {
                            pageView(for: cat, documentName: doc).id(doc)
                        } else {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading \(cat.rawValue)…")
                                    .foregroundColor(themeManager.foregroundColor.opacity(0.7))
                            }
                        }
                    }
                    .tag(cat)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            
            CustomBackButton(
//                iconSize: 18,
////                paddingSize: 8,
//                backgroundColor: Color.black.opacity(0.3),
//                iconColor: themeManager.foregroundColor,
////                topPadding: 120,
//                horizontalPadding: 24
            )
            .onTapGesture {
                dismiss()          // pop back to FirstPageView
            }
        }
        // Prevent the default nav bar blur from showing at the top
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar) // if you don’t want any bar at all
        .preferredColorScheme(themeManager.preferredColorScheme)
    }
    
    @ViewBuilder
    private func pageView(for cat: RecCategory, documentName: String) -> some View {
        switch cat {
        case .Place:
            PlaceDetailView(documentName: documentName)
        case .Gemstone:
            GemstoneDetailView(documentName: documentName)
        case .Color:
            ColorDetailView(documentName: documentName)
        case .Scent:
            ScentDetailView(documentName: documentName)
        case .Activity:
            ActivityDetailView(documentName: documentName)
//                               soundDocumentName: docsByCategory[.Sound] ?? "")
        case .Sound:
            SoundDetailView(documentName: documentName)
        case .Career:
            CareerDetailView(documentName: documentName)
        case .Relationship:
            RelationshipDetailView(documentName: documentName)
        }
    }
}







// Back button

struct CustomBackButton: View {
    @Environment(\.dismiss) private var dismiss
    var iconSize: CGFloat = 20
    var paddingSize: CGFloat = 10
    var backgroundColor: Color = Color.black.opacity(0.3)
    var iconColor: Color = .white
    var topPadding: CGFloat = 12
    var horizontalPadding: CGFloat = 12
    
    var body: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(iconColor)
                        .padding(paddingSize)
//                        .background(backgroundColor)
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.top, topPadding)
            .padding(.horizontal, horizontalPadding)
            Spacer()
        }
    }
}





// 替换你文件中现有的 OnboardingViewModel
import FirebaseFirestore
import FirebaseAuth
import MapKit

class OnboardingViewModel: ObservableObject {
    @Published var nickname: String = ""
    @Published var gender: String = ""
    @Published var relationshipStatus: String = ""
    @Published var birth_date: Date = Date()
    @Published var birth_time: Date = Date()
    @Published var birthPlace: String = ""
    @Published var currentPlace: String = ""
    @Published var birthCoordinate: CLLocationCoordinate2D?
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var recommendations: [String: String] = [:]
    @Published var dailyMantra: String = ""
    
    // ✅ 新增：Step3 的五个答案
    @Published var scent_dislike: Set<String> = []     // 多选
    @Published var act_prefer: String = ""             // 单选，可清空
    @Published var color_dislike: Set<String> = []     // 多选
    @Published var allergies: Set<String> = []         // 多选
    @Published var music_dislike: Set<String> = []     // 多选
}




import SwiftUI
// 统一进场动画修饰器：按 index 级联
struct StaggeredAppear: ViewModifier {
    let index: Int
    @Binding var show: Bool
    var baseDelay: Double = 0.08
    
    func body(content: Content) -> some View {
        content
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : 16)
            .scaleEffect(show ? 1 : 0.985)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0.2)
                    .delay(baseDelay * Double(index)),
                value: show
            )
    }
}

extension View {
    func staggered(_ index: Int, show: Binding<Bool>, baseDelay: Double = 0.08) -> some View {
        self.modifier(StaggeredAppear(index: index, show: show, baseDelay: baseDelay))
    }
}

// MARK: - Aligna 标题（逐字母入场）
struct AlignaHeading: View {
    // 保持你原来的入参不变，兼容现有调用
    let textColor: Color
    @Binding var show: Bool

    // 新增可调参数（有默认值，不会破坏现有调用）
    var text: String = "Alynna"
    var fontSize: CGFloat = 34
    var perLetterDelay: Double = 0.07   // 每个字母的出现间隔
    var duration: Double = 0.26         // 单个字母动画时长
    var letterSpacing: CGFloat = 0      // 需要更“松”的字距，可以传入 > 0

    var body: some View {
        let letters = Array(text)
        HStack(spacing: letterSpacing) {
            ForEach(letters.indices, id: \.self) { i in
                Text(String(letters[i]))
                    .font(Font.custom("PlayfairDisplay-Regular", size: fontSize))
                    .foregroundColor(textColor)
                    .opacity(show ? 1 : 0)
                    .offset(y: show ? 0 : 8)
                    .animation(
                        .easeOut(duration: duration).delay(perLetterDelay * Double(i)),
                        value: show
                    )
            }
        }
        .accessibilityLabel(text)
    }
}


// MARK: - Staggered Letters (逐字母入场)
struct StaggeredLetters: View {
    let text: String
    let font: Font
    let color: Color
    let letterSpacing: CGFloat
    let duration: Double       // 单个字母的动画时长
    let perLetterDelay: Double // 每个字母之间的间隔

    @State private var active = false

    var body: some View {
        HStack(spacing: letterSpacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { idx, ch in
                Text(String(ch))
                    .font(font)
                    .foregroundColor(color)
                    .opacity(active ? 1 : 0)
                    .offset(y: active ? 0 : 8)
                    .animation(
                        .easeOut(duration: duration)
                            .delay(perLetterDelay * Double(idx)),
                        value: active
                    )
            }
        }
        .onAppear { active = true }
    }
}




struct OnboardingOpeningPage: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let minLength = min(geometry.size.width, geometry.size.height)
                
                ZStack {
                    AppBackgroundView(mode: .night)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                    
                    VStack(spacing: minLength * 0.04) {
                        Spacer()
                        
                        Text("Alynna")
                            .font(Font.custom("PlayfairDisplay-Regular", size: minLength * 0.12))
                            .foregroundColor(themeManager.fixedNightTextPrimary)
                        
                        Text("FIND YOUR FLOW")
                            .font(.subheadline)
                            .foregroundColor(themeManager.fixedNightTextSecondary)
                        
                        Image("openingSymbol")
                            .resizable()
                            .scaledToFit()
                            .frame(width: minLength * 0.35)
                        
                        Spacer()
                        
                        // Sign Up（按钮本身用白底黑字，保持原样）
                        NavigationLink(destination: RegisterPageView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)) {
                                Text("Sign Up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.9))
                                    .foregroundColor(.black)
                                    .cornerRadius(14)
                                    .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 4)
                                    .padding(.horizontal, minLength * 0.1)
                            }

                        // Log In（按钮文案保留白色）
                        NavigationLink(destination: AccountPageView()
                            .environmentObject(starManager)
                            .environmentObject(themeManager)
                            .environmentObject(OnboardingViewModel())) {
                                Text("Log In")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                                    .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 4)
                                    .padding(.horizontal, minLength * 0.1)
                            }

                        Text("Welcome to the Journal of Alynna")
                            .font(.footnote)
                            .foregroundColor(themeManager.fixedNightTextTertiary)
                            .padding(.top, 10)
                        
                        Spacer()
                    }
                    .padding(.bottom, geometry.size.height * 0.05)
                    .preferredColorScheme(.dark)
                }
            }
        }
        .onAppear { starManager.animateStar = true }
        .navigationBarBackButtonHidden(true)
    }
}

import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import FirebaseFirestore

struct RegisterPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToOnboarding = false
    @State private var navigateToLogin = false
    @State private var currentNonce: String? = nil
    
    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false


    // 入场动画控制
    @State private var showIntro = false

    // 焦点控制
    @FocusState private var registerFocus: RegisterField?
    private enum RegisterField { case email, password }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height
                let minL = min(w, h)

                let sectionGap  = h * 0.075
                let fieldGap    = minL * 0.030
                let socialGap   = minL * 0.035

                ZStack {
                    AppBackgroundView(mode: .night)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)

                    VStack(spacing: 0) {
                        // 顶部：返回 + 标题
                        VStack(spacing: minL * 0.02) {
                            HStack {
                                Button(action: { dismiss() }) {
                                    Image(systemName: "chevron.left")
                                        .font(.title2)
                                        .foregroundColor(themeManager.fixedNightTextPrimary)
                                        .padding(10)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .padding(.leading, w * 0.05)
                                Spacer()
                            }

                            VStack(spacing: 8) {
                                AlignaHeading(
                                    textColor: themeManager.fixedNightTextPrimary,
                                    show: $showIntro,
                                    fontSize: minL * 0.12,
                                    letterSpacing: minL * 0.005
                                )
                                Text("Create Account")
                                    .font(.custom("PlayfairDisplay-Regular", size: 28))
                                    .foregroundColor(themeManager.fixedNightTextPrimary.opacity(0.9))
                            }
                            .padding(.top, h * 0.01)
                            .staggered(1, show: $showIntro)
                        }
                        .padding(.top, h * 0.05)
                        .staggered(0, show: $showIntro)

                        Spacer(minLength: sectionGap)

                        // 表单
                        VStack(spacing: fieldGap) {

                            // Email
                            Group {
                                TextField("Email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(14)
                                    .foregroundColor(themeManager.fixedNightTextPrimary)
                                    .focused($registerFocus, equals: .email)
                                    .focusGlow(
                                        active: registerFocus == .email,
                                        color: themeManager.fixedNightTextPrimary,
                                        lineWidth: 2.2,
                                        cornerRadius: 14
                                    )
                                    .submitLabel(.next)
                                    .onSubmit { registerFocus = .password }
                            }
                            .staggered(2, show: $showIntro)
                            .animation(nil, value: registerFocus)

                            // Password
                            Group {
                                SecureField("Password", text: $password)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(14)
                                    .foregroundColor(themeManager.fixedNightTextPrimary)
                                    .focused($registerFocus, equals: .password)
                                    .focusGlow(
                                        active: registerFocus == .password,
                                        color: themeManager.fixedNightTextPrimary,
                                        lineWidth: 2.2,
                                        cornerRadius: 14
                                    )
                                    .submitLabel(.done)
                            }
                            .staggered(3, show: $showIntro)
                            .animation(nil, value: registerFocus)

                            Button(action: { registerWithEmailPassword() }) {
                                Text("Register & Send Email")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(themeManager.fixedNightTextPrimary)
                                    .foregroundColor(.black)
                                    .cornerRadius(14)
                            }
                            .staggered(4, show: $showIntro)
                        }
                        .padding(.horizontal, w * 0.1)

                        Spacer(minLength: sectionGap)

                        // 第三方登录
                        VStack(spacing: socialGap) {
                            Text("Or register with")
                                .font(.footnote)
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                                .staggered(5, show: $showIntro)

                            HStack(spacing: minL * 0.10) {
                                // Google
                                Button(action: {
                                    // ① 预设标记（你原有逻辑，保留）
                                    hasCompletedOnboarding = false
                                    isLoggedIn = false
                                    shouldOnboardAfterSignIn = true

                                    // ② 自检：没过就给出友好提示并 return
                                    if !GoogleSignInDiagnostics.preflight(context: "RegisterPageView.GoogleButton") {
                                        alertMessage = """
                                        Google Sign-In 配置未就绪：
                                        • 请确认 Info.plist 的 URL Types 中已添加 REVERSED_CLIENT_ID
                                        • 请确认 GoogleService-Info.plist 属于 App 主 target
                                        • 请在可见页面触发登录
                                        """
                                        showAlert = true
                                        return
                                    }

                                    // ③ 通过预检 → 执行你原有的注册逻辑
                                    handleGoogleFromRegister(
                                        onNewUserGoOnboarding: {
                                            shouldOnboardAfterSignIn = true
                                            navigateToOnboarding = true
                                        },
                                        onExistingUserGoLogin: { msg in
                                            shouldOnboardAfterSignIn = false
                                            alertMessage = msg; showAlert = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                navigateToLogin = true
                                            }
                                        },
                                        onError: { message in
                                            shouldOnboardAfterSignIn = false
                                            alertMessage = message; showAlert = true
                                        }
                                    )
                                }) {
                                    Image("googleIcon")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .padding(14)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .staggered(6, show: $showIntro)

                                // Apple
                                SignInWithAppleButton(
                                    .signUp,
                                    onRequest: { request in
                                        let nonce = randomNonceString()
                                        currentNonce = nonce
                                        request.requestedScopes = [.fullName, .email]
                                        request.nonce = sha256(nonce)
                                        // 进入 Apple 注册流程也先打上标记
                                        hasCompletedOnboarding = false
                                        isLoggedIn = false
                                        shouldOnboardAfterSignIn = true
                                    },
                                    onCompletion: { result in
                                        handleAppleFromRegister(
                                            result: result,
                                            rawNonce: currentNonce ?? "",
                                            onNewUserGoOnboarding: {
                                                shouldOnboardAfterSignIn = true
                                                navigateToOnboarding = true
                                            },
                                            onExistingUserGoLogin: { msg in
                                                shouldOnboardAfterSignIn = false
                                                alertMessage = msg; showAlert = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                    navigateToLogin = true
                                                }
                                            },
                                            onError: { message in
                                                shouldOnboardAfterSignIn = false
                                                alertMessage = message; showAlert = true
                                            }
                                        )
                                    }
                                )

                                .frame(width: 160, height: 50)
                                .signInWithAppleButtonStyle(.black) // 固定黑色样式更稳
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .staggered(7, show: $showIntro)
                            }
                        }
                        .padding(.horizontal, w * 0.1)

                        Spacer(minLength: h * 0.08)
                    }
                    .preferredColorScheme(.dark)
                    .transaction { $0.animation = nil } // 阻断布局隐式动画
                }
                .hideKeyboardOnTapOutside($registerFocus)
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Notice"),
                          message: Text(alertMessage),
                          dismissButton: .default(Text("OK")))
                }
                .navigationDestination(isPresented: $navigateToOnboarding) {
                    OnboardingStep1(viewModel: viewModel)
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                }
                .navigationDestination(isPresented: $navigateToLogin) {
                    AccountPageView()
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                        .environmentObject(viewModel)
                }
                .onAppear {
                    showIntro = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        registerFocus = .email
                    }
                    GoogleSignInDiagnostics.run(context: "RegisterPageView.onAppear")
                }
                .onDisappear { showIntro = false }
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { registerFocus = nil }
                    }
                }
            }
        }
    }

    // MARK: - Email & Password 注册（保留你的原逻辑）
    // MARK: - Email & Password 注册（跳转到 Onboarding）
    // MARK: - Email & Password 注册（跳转到 Onboarding）
    private func registerWithEmailPassword() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showAlert = true
            return
        }
        
        // ✅ 关键：在调用 createUser 之前，先打上“需要 Onboarding”的标记
        hasCompletedOnboarding = false
        isLoggedIn = false
        shouldOnboardAfterSignIn = true
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                // 特殊处理：邮箱已经被注册 → 引导去登录
                if let errCode = AuthErrorCode(rawValue: error._code),
                   errCode == .emailAlreadyInUse {
                    
                    // 这个情况其实是“老用户”，所以这里顺便把标记改回来也可以
                    shouldOnboardAfterSignIn = false
                    isLoggedIn = false
                    hasCompletedOnboarding = false
                    
                    alertMessage = "This email is already in use. Redirecting to Sign In..."
                    showAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        navigateToLogin = true
                    }
                    return
                }
                
                // 其他错误，直接弹出
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }
            
            // ✅ 账号创建成功：发验证邮件（就算失败也不影响继续 Onboarding）
            result?.user.sendEmailVerification(completion: nil)
            
            // 此时 FirstPageView 那个监听已经看到 shouldOnboardAfterSignIn = true，
            // 不会把你拉去首页，只会保持在 .onboarding。
            // 这里我们用本页的 NavigationStack 去推 OnboardingStep1。
            DispatchQueue.main.async {
                navigateToOnboarding = true
            }
        }
    }

}

extension View {
    func hideKeyboardOnTapOutside<T: Hashable>(_ focus: FocusState<T?>.Binding) -> some View {
        self
            .contentShape(Rectangle()) // 让空白也可点
            .simultaneousGesture(TapGesture().onEnded {
                focus.wrappedValue = nil
            })
            .gesture(DragGesture().onChanged { _ in
                focus.wrappedValue = nil
            })
    }
}
import SwiftUI
import MapKit

struct AlignaTopHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            if let _ = UIImage(named: "alignaSymbol") {
                Image("alignaSymbol")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.white)
                    .padding(.top, 6)
            } else {
                Image(systemName: "leaf.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }
            Text("Alynna")
                .font(Font.custom("PlayfairDisplay-Regular", size: 34))
                .foregroundColor(.white)
        }
    }
}
extension Text {
    func onboardingQuestionStyle() -> some View {
        self.font(.custom("PlayfairDisplay-Regular", size: 17)) // 统一字号
            .foregroundColor(.white) // 统一颜色
            .multilineTextAlignment(.center) // 统一居中
            .frame(maxWidth: .infinity)
    }
}




import SwiftUI
import MapKit

struct OnboardingStep1: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    
    @State private var goOpening = false


    private let panelBG = Color.white.opacity(0.08)
    private let stroke   = Color.white.opacity(0.25)

    // 出生地搜索
    @State private var birthSearch = ""
    @State private var birthResults: [PlaceResult] = []
    @State private var didSelectBirth = false

    // 🔹 焦点控制
    @FocusState private var step1Focus: Step1Field?
    private enum Step1Field { case nickname, birth }

    // 若你也想给 Step1 做入场级联动画，可以用 showIntro；这里只保留结构
    @State private var showIntro = true

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView(mode: .night)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                ScrollView {
                    VStack(spacing: minLength * 0.045) {
                        // 顶部
                        AlignaTopHeader()

                        Text("Tell us about yourself")
                            .onboardingQuestionStyle()
                            .padding(.top, 6)

                        // 基础信息
                        Group {
                            // Nickname
                            VStack(alignment: .center, spacing: 10) {
                                Text("Your Nickname")
                                    .onboardingQuestionStyle()

                                Group {
                                    TextField("Enter your nickname", text: $viewModel.nickname)
                                        .padding()
                                        .background(panelBG)
                                        .cornerRadius(12)
                                        .foregroundColor(.white)
                                        .focused($step1Focus, equals: .nickname)
                                        .focusGlow(active: step1Focus == .nickname,
                                                   color: .white,
                                                   lineWidth: 2,
                                                   cornerRadius: 12)
                                }
                                .animation(nil, value: step1Focus)
                            }

                            // Gender
                            VStack(alignment: .center, spacing: 10) {
                                Text("Gender")
                                    .onboardingQuestionStyle()

                                HStack(spacing: 10) {
                                    ForEach(["Male", "Female", "Other"], id: \.self) { gender in
                                        Button {
                                            viewModel.gender = gender
                                        } label: {
                                            Text(gender)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(viewModel.gender == gender ? Color.white : panelBG)
                                                .foregroundColor(viewModel.gender == gender ? .black : .white)
                                                .overlay(RoundedRectangle(cornerRadius: 10)
                                                    .stroke(stroke, lineWidth: 1))
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }

                            // Relationship
                            VStack(alignment: .center, spacing: 10) {
                                Text("Status")
                                    .onboardingQuestionStyle()

                                HStack(spacing: 10) {
                                    ForEach(["Single", "In a relationship", "Other"], id: \.self) { status in
                                        Button {
                                            viewModel.relationshipStatus = status
                                        } label: {
                                            Text(status)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(viewModel.relationshipStatus == status ? Color.white : panelBG)
                                                .foregroundColor(viewModel.relationshipStatus == status ? .black : .white)
                                                .overlay(RoundedRectangle(cornerRadius: 10)
                                                    .stroke(stroke, lineWidth: 1))
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // 出生地
                        VStack(alignment: .center, spacing: 12) {
                            Text("Place of Birth")
                                .onboardingQuestionStyle()

                            Group {
                                TextField("Your Birth Place", text: $birthSearch)
                                    .padding()
                                    .background(panelBG)
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .focused($step1Focus, equals: .birth)
                                    .focusGlow(active: step1Focus == .birth,
                                               color: .white,
                                               lineWidth: 2,
                                               cornerRadius: 12)
                                    .onChange(of: birthSearch) { _, newVal in
                                        if !didSelectBirth && !newVal.isEmpty {
                                            performBirthSearch(query: newVal)
                                        }
                                        didSelectBirth = false
                                    }
                            }
                            .animation(nil, value: step1Focus)

                            if !viewModel.birthPlace.isEmpty {
                                Text("✓ Selected: \(viewModel.birthPlace)")
                                    .font(.footnote)
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }

                            VStack(spacing: 8) {
                                ForEach(birthResults) { result in
                                    Button {
                                        viewModel.birthPlace = result.name
                                        viewModel.birthCoordinate = result.coordinate
                                        birthSearch = result.name
                                        birthResults = []
                                        didSelectBirth = true
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.name)
                                                .font(.subheadline).fontWeight(.semibold)
                                                .foregroundColor(.white)
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(panelBG)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Continue
                        NavigationLink(destination: OnboardingStep2(viewModel: viewModel)
                            .environmentObject(themeManager)) {
                                Text("Continue")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isFormComplete ? Color.white : Color.white.opacity(0.1))
                                    .foregroundColor(isFormComplete ? .black : .white)
                                    .cornerRadius(16)
                                    .shadow(color: .white.opacity(isFormComplete ? 0.15 : 0),
                                            radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal)
                            .disabled(!isFormComplete)

                        // Back
                        Button {
                            dismiss()
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
                .safeAreaInset(edge: .top) {
                    Color.clear
                        .frame(height: geometry.safeAreaInsets.top + 8)
                        .allowsHitTesting(false)
                }
                // 给底部 Home 指示条留点空间，手感更好
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: max(12, geometry.safeAreaInsets.bottom))
                        .allowsHitTesting(false)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
            }
        }
    }

    private var isFormComplete: Bool {
        !viewModel.nickname.isEmpty &&
        !viewModel.gender.isEmpty &&
        !viewModel.relationshipStatus.isEmpty &&
        !viewModel.birthPlace.isEmpty
    }

    private func performBirthSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        MKLocalSearch(request: request).start { response, _ in
            guard let items = response?.mapItems else { return }
            let results = items.compactMap { item in
                PlaceResult(
                    name: item.name ?? "",
                    subtitle: item.placemark.title ?? "",
                    coordinate: item.placemark.coordinate
                )
            }
            DispatchQueue.main.async { self.birthResults = results }
        }
    }
}

// MARK: - OnboardingStep2（顶部与 Step1/Step3 一致，日期/时间用弹出滚轮）
// MARK: - OnboardingStep2（顶部与 Step1 一致 + 时间保存改为本地锚定）
struct OnboardingStep2: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var starManager: StarAnimationManager

    // 弹窗控制
    @State private var showDatePickerSheet = false
    @State private var showTimePickerSheet = false

    // 临时选择值（用于滚轮，不直接写回 VM）
    @State private var tempBirthDate: Date = Date()
    @State private var tempBirthTime: Date = Date()

    private let panelBG = Color.white.opacity(0.08)
    private let stroke  = Color.white.opacity(0.25)

    // 生日范围（1900 ~ 今天）
    private var dateRange: ClosedRange<Date> {
        var comps = DateComponents()
        comps.year = 1900; comps.month = 1; comps.day = 1
        let calendar = Calendar.current
        let start = calendar.date(from: comps) ?? Date(timeIntervalSince1970: 0)
        let end = Date()
        return start...end
    }

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView(mode: .night)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)

                VStack(spacing: minLength * 0.05) {
                    // 顶部与 Step1 保持一致（无系统返回）
                    AlignaTopHeader()

                    Text("When were you born?")
                        .onboardingQuestionStyle()
                        .padding(.top, 10)

                    // Birthday
                    VStack(spacing: 15) {
                        Text("Birthday").onboardingQuestionStyle()

                        Button {
                            tempBirthDate = viewModel.birth_date
                            showDatePickerSheet = true
                        } label: {
                            HStack {
                                Text(viewModel.birth_date.formatted(.dateTime.year().month(.wide).day()))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(panelBG)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(stroke, lineWidth: 1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // Time of Birth
                    VStack(spacing: 15) {
                        Text("Time of Your Birth").onboardingQuestionStyle()

                        Button {
                            tempBirthTime = viewModel.birth_time
                            showTimePickerSheet = true
                        } label: {
                            HStack {
                                Text(viewModel.birth_time.formatted(date: .omitted, time: .shortened))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(panelBG)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(stroke, lineWidth: 1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Continue
                    NavigationLink(
                        destination: OnboardingStep3(viewModel: viewModel)
                    ) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                            .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)

                    // Back（自定义返回按钮，不用系统自带的）
                    Button(action: { dismiss() }) {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)
                    .padding(.bottom, 30)
                }
                .preferredColorScheme(.dark)
                .padding(.horizontal)
            }
            .onAppear {
                // 默认值兜底
                if viewModel.birth_date.timeIntervalSince1970 == 0 {
                    viewModel.birth_date = Date()
                }
                if viewModel.birth_time.timeIntervalSince1970 == 0 {
                    viewModel.birth_time = Date()
                }
            }
            // 日期滚轮
            .sheet(isPresented: $showDatePickerSheet) {
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            viewModel.birth_date = tempBirthDate
                            showDatePickerSheet = false
                        }
                        .padding(.trailing)
                        .padding(.top, 8)
                    }

                    DatePicker(
                        "",
                        selection: $tempBirthDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 24)
                }
                .presentationDetents([.fraction(0.45), .medium])
                .background(.black.opacity(0.6))
            }
            // 时间滚轮（关键：保存时用 makeLocalDate 固定到本地时区的参考日，防止后续显示漂移）
            .sheet(isPresented: $showTimePickerSheet) {
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: tempBirthTime)
                            if let d = makeLocalDate(hour: comps.hour ?? 0, minute: comps.minute ?? 0) {
                                viewModel.birth_time = d
                            } else {
                                viewModel.birth_time = tempBirthTime
                            }
                            showTimePickerSheet = false
                        }
                        .padding(.trailing)
                        .padding(.top, 8)
                    }

                    DatePicker(
                        "",
                        selection: $tempBirthTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 24)
                }
                .presentationDetents([.fraction(0.35), .medium])
                .background(.black.opacity(0.6))
            }
        }
        // === 彻底隐藏系统导航条 & 返回按钮，去掉顶部白条 ===
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .ignoresSafeArea() // 防止出现顶边色带
    }
}

import SwiftUI
import MapKit
import CoreLocation

struct PlaceResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(subtitle)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}


import SwiftUI

struct OnboardingStep3: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager

    // 选项文案（对齐效果图）
    private let scentOptions  = ["Floral", "Strong", "Woody",
                                 "Citrus", "Spicy", "Other"]
    private let actOptions    = ["Static", "Dynamic", "No preference"]
    private let colorOptions  = ["Yellow", "Pink", "Green",
                                 "Orange", "Purple", "Other"]
    private let allergyOpts   = ["Pollen/Dust", "Food", "Pet",
                                 "Chemical", "Seasonal", "Other"]
    private let musicOptions  = ["Heavy metal", "Classical", "Electronic",
                                 "Country", "Jazz", "Other"]

    private var hasAnySelection: Bool {
        !viewModel.scent_dislike.isEmpty ||
        !viewModel.color_dislike.isEmpty ||
        !viewModel.allergies.isEmpty ||
        !viewModel.music_dislike.isEmpty ||
        !viewModel.act_prefer.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackgroundView(mode: .night)
                .environmentObject(starManager)
                .environmentObject(themeManager)

            ScrollView {
                VStack(spacing: 24) {
                    header

                    // 说明
                    subHeader(
                        title: "A few quick preferences",
                        subtitle: "This helps us personalize your experience"
                    )

                    // Scents
                    sectionTitle("Any scents you dislike?")
                    chips(options: scentOptions,
                          isSelected: { viewModel.scent_dislike.contains($0) },
                          toggle: { toggleSet(&viewModel.scent_dislike, $0) })

                    // Activity
                    sectionTitle("Activity preference?")
                    chips(options: actOptions,
                          isSelected: { viewModel.act_prefer == $0 },
                          toggle: { toggleSingle(&viewModel.act_prefer, $0) })

                    // Colors
                    sectionTitle("Any colors you dislike?")
                    chips(options: colorOptions,
                          isSelected: { viewModel.color_dislike.contains($0) },
                          toggle: { toggleSet(&viewModel.color_dislike, $0) })

                    // Allergies
                    sectionTitle("Any allergies we should know about?")
                    chips(options: allergyOpts,
                          isSelected: { viewModel.allergies.contains($0) },
                          toggle: { toggleSet(&viewModel.allergies, $0) })

                    // Music
                    sectionTitle("Any music you dislike?")
                    chips(options: musicOptions,
                          isSelected: { viewModel.music_dislike.contains($0) },
                          toggle: { toggleSet(&viewModel.music_dislike, $0) })

                    // Continue / Continue without answers
                    NavigationLink {
                        OnboardingFinalStep(viewModel: viewModel)
                    } label: {
                        Text(hasAnySelection ? "Continue" : "Continue without answers")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                            .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 8)

                    // Back
                    Button {
                        dismiss()
                    } label: {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            // 顶部 Skip
            VStack {
                HStack {
                    Spacer()
                    NavigationLink {
                        OnboardingFinalStep(viewModel: viewModel)
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .underline()
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.trailing, 20)
                            .padding(.top, 16)
                    }
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header（与 Step1/2 保持一致）
    private var header: some View {
        VStack(spacing: 8) {
            if let _ = UIImage(named: "alignaSymbol") {
                Image("alignaSymbol")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .padding(.top, 6)
            } else {
                Image(systemName: "leaf.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }

            Text("Alynna")
                .font(Font.custom("PlayfairDisplay-Regular", size: 34))
                .foregroundColor(.white)
        }
    }

    // 统一副说明的小字样式
    private func subHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title).onboardingQuestionStyle()
            Text(subtitle)
                .onboardingQuestionStyle()
                .opacity(0.8)
        }
        .padding(.top, 6)
    }

    // 统一题干标题的小字样式
    private func sectionTitle(_ title: String) -> some View {
        Text(title).onboardingQuestionStyle()
    }

    // MARK: - 固定三列的 Chips（大小一致、间距一致）
    private func chips(options: [String],
                       isSelected: @escaping (String) -> Bool,
                       toggle: @escaping (String) -> Void) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(options, id: \.self) { opt in
                Button {
                    toggle(opt)
                } label: {
                    let selected = isSelected(opt)
                    Text(opt)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity) // 填满单元列宽
                        .frame(height: 44)          // 统一高度
                        .background(selected ? Color.white : Color.white.opacity(0.08))
                        .foregroundColor(selected ? .black : .white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(selected ? 0.0 : 0.25), lineWidth: 1)
                        )
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Toggle Helpers
    private func toggleSet(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
    private func toggleSingle(_ current: inout String, _ value: String) {
        current = (current == value) ? "" : value
    }
}

// ===============================
// MARK: - FlexibleWrap / FlowLayout（修复版）
// ===============================
struct FlexibleWrap<Content: View>: View {
    var spacing: CGFloat = 12
    var runSpacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        // 注意：这里返回的是 FlowLayout{ ... }，不是再次调用 FlexibleWrap 本身
        FlowLayout(spacing: spacing, runSpacing: runSpacing) {
            content()
        }
    }
}

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 12
    var runSpacing: CGFloat = 12

    // ❗️不要写带 @ViewBuilder 的 init，会覆盖系统合成的带内容闭包的初始化
    init(spacing: CGFloat = 12, runSpacing: CGFloat = 12) {
        self.spacing = spacing
        self.runSpacing = runSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews, placing: false)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        _ = layout(proposal: proposal, subviews: subviews, placing: true, in: bounds)
    }

    private func layout(proposal: ProposedViewSize,
                        subviews: Subviews,
                        placing: Bool,
                        in bounds: CGRect = .zero) -> CGSize {
        let maxWidth = proposal.width ?? (placing ? bounds.width : .greatestFiniteMagnitude)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)

            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }

            if placing {
                let origin = CGPoint(x: bounds.minX + x, y: bounds.minY + y)
                sv.place(at: origin, proposal: .unspecified)
            }

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }
}



import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationStatus: CLAuthorizationStatus?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 25   // 25m 再更新，减少抖动
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        // 单次请求即可，系统会在拿到最新定位后回调一次
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        DispatchQueue.main.async { self.currentLocation = last.coordinate }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 获取位置失败: \(error.localizedDescription)")
    }
}


class SearchDelegate: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    var onResults: ([MKLocalSearchCompletion]) -> Void = { _ in }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResults(completer.results)
    }
}


import SwiftUI
import CoreLocation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct OnboardingFinalStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("shouldOnboardAfterSignIn") var shouldOnboardAfterSignIn: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false


    // 位置 & 流程
    @StateObject private var locationManager = LocationManager()
    @State private var locationMessage = "Requesting location permission..."
    @State private var didAttemptReverseGeocode = false

    // 上传/跳转
    @State private var isLoading = false
    @State private var navigateToHome = false

    // 入场动画
    @State private var showIntro = false

    var body: some View {
        GeometryReader { geo in
            let minL = min(geo.size.width, geo.size.height)

            // ===== 尺寸与间距（确保副标题 < 信息字体） =====
            let infoFontSize = max(18, minL * 0.046)           // 信息行字体（略大于 17，随屏变化）
            let subtitleFontSize = max(16, minL * 0.038)       // 副标题更小，始终 < infoFontSize
            let listItemSpacing = max(13, minL * 0.055)        // 信息项之间的垂直间距：更大
            let innerLineSpacing = max(3, minL * 0.016)        // 单个信息项内的行间距（多行时更松）

            ZStack {
                // 夜空背景（与 Step1~3 一致）
                AppBackgroundView(mode: .night)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: minL * 0.048) {
                        // 顶部：Logo + “Aligna”（逐字母入场）
                        VStack(spacing: 12) {
                            if let _ = UIImage(named: "alignaSymbol") {
                                Image("alignaSymbol")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: minL * 0.18, height: minL * 0.18)
                                    .staggered(0, show: $showIntro)
                            } else {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: minL * 0.18))
                                    .foregroundColor(.white)
                                    .staggered(0, show: $showIntro)
                            }

                            AlignaHeading(
                                textColor: .white,
                                show: $showIntro,
                                text: "Alynna",
                                fontSize: minL * 0.12,
                                perLetterDelay: 0.06,
                                duration: 0.22,
                                letterSpacing: minL * 0.004
                            )
                            .accessibilityHidden(true)
                        }
                        .padding(.top, minL * 0.06)

                        // ⬇️ 小副标题：明显小于信息字体
                        Text("Confirm your information")
                            .font(.custom("PlayfairDisplay-Regular", size: subtitleFontSize))
                            .foregroundColor(.white.opacity(0.95))
                            .kerning(minL * 0.0005)
                            .staggered(1, show: $showIntro)

                        // 信息条目：更大的项间距 + 更松的行间距
                        VStack(alignment: .leading, spacing: listItemSpacing) {
                            bulletRow(
                                emoji: "👤",
                                title: "Nickname",
                                value: viewModel.nickname,
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(2, show: $showIntro)

                            bulletRow(
                                emoji: "⚧️",
                                title: "Gender",
                                value: viewModel.gender,
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(3, show: $showIntro)

                            bulletRow(
                                emoji: "📅",
                                title: "Birthday",
                                value: viewModel.birth_date.formatted(.dateTime.year().month().day()),
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(4, show: $showIntro)

                            bulletRow(
                                emoji: "⏰",
                                title: "Time of Birth",
                                value: viewModel.birth_time.formatted(date: .omitted, time: .shortened),
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(5, show: $showIntro)

                            bulletRow(
                                emoji: "📍",
                                title: "Your Current Location",
                                value: viewModel.currentPlace.isEmpty ? locationMessage : viewModel.currentPlace,
                                fontSize: infoFontSize,
                                lineSpacing: innerLineSpacing
                            )
                            .staggered(6, show: $showIntro)
                        }
                        .padding(.horizontal, geo.size.width * 0.1)

                        // Loading
                        if isLoading {
                            ProgressView("Loading, please wait...")
                                .foregroundColor(.white)
                                .padding(.top, 6)
                                .staggered(7, show: $showIntro)
                        }

                        // ✅ 确认按钮（白底 + 黑字，与 Step1~3 一致）
                        Button {
                            guard !isLoading else { return }
                            isLoading = true
                            uploadUserInfo()
                        } label: {
                            Text("Confirm")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(16)
                                .shadow(color: .white.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, geo.size.width * 0.1)
                        .padding(.top, 6)
                        .staggered(8, show: $showIntro)

                        // 返回（与 Step1~3 一致）
                        Button {
                            dismiss()
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, geo.size.width * 0.1)
                        .padding(.bottom, minL * 0.08)
                        .staggered(9, show: $showIntro)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                starManager.animateStar = true
                showIntro = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }

                // 进页面即发起位置权限与解析
                didAttemptReverseGeocode = false
                locationMessage = "Requesting location permission..."
                locationManager.requestLocation()
            }
            // 监听坐标，做反向地理编码
            .onReceive(locationManager.$currentLocation.compactMap { $0 }) { coord in
                guard !didAttemptReverseGeocode else { return }
                didAttemptReverseGeocode = true
                reverseGeocode(coord) { place in
                    if let place = place {
                        viewModel.currentPlace = place
                        viewModel.currentCoordinate = coord
                        locationMessage = "✓ Current Place detected: \(place)"
                    } else {
                        locationMessage = "Location acquired, resolving address failed."
                    }
                }
            }
            // 监听权限
            .onReceive(locationManager.$locationStatus.compactMap { $0 }) { status in
                switch status {
                case .denied, .restricted:
                    locationMessage = "Location permission denied. Current place will be left blank."
                default:
                    break
                }
            }
            // 完成后跳首页
            .navigationDestination(isPresented: $navigateToHome) {
                FirstPageView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
                    .navigationBarBackButtonHidden(true)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - 单行条目（emoji + 斜体标题 + 正文字），支持传入字体与行距
    private func bulletRow(emoji: String, title: String, value: String, fontSize: CGFloat, lineSpacing: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 24, alignment: .center)

            // 组合文本：title 斜体，value 正常体；同一字号，内部行距更松
            (
                Text("\(title): ")
                    .italic()
                    .font(.custom("PlayfairDisplay-Regular", size: fontSize))
                +
                Text(value)
                    .font(.custom("PlayfairDisplay-Regular", size: fontSize))
            )
            .foregroundColor(.white)
            .lineSpacing(lineSpacing) // ⬅️ 单项内部行距（多行时生效）
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 反向地理编码
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            if let p = placemarks?.first {
                let city = p.locality ?? p.administrativeArea ?? p.name
                completion(city)
            } else {
                completion(nil)
            }
        }
    }

    // ====== 以下保持你原有逻辑：上传用户信息 + FastAPI 请求并写入 daily_recommendation ======
    @State private var recommendation: [String: String] = [:]
    @State private var mantra: String = ""

    private func uploadUserInfo() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ 未登录，无法上传")
            isLoading = false
            return
        }

        let db = Firestore.firestore()

        // 生日存成可读字符串（兼容你原有字段）
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let birthDateString = dateFormatter.string(from: viewModel.birth_date)

        // ✅ 关键：只存“时、分”两个整型，彻底规避时区改动
        let (h, m) = BirthTimeUtils.hourMinute(from: viewModel.birth_time)

        let lat = viewModel.currentCoordinate?.latitude ?? 0
        let lng = viewModel.currentCoordinate?.longitude ?? 0

        // ✅ 用 var，后面可追加字段
        var data: [String: Any] = [
            "uid": userId,
            "nickname": viewModel.nickname,
            "gender": viewModel.gender,
            "relationshipStatus": viewModel.relationshipStatus,
            "birthDate": birthDateString,          // 你原来的字符串生日
            "birthHour": h,                        // ✅ 新增：小时
            "birthMinute": m,                      // ✅ 新增：分钟
            "birthPlace": viewModel.birthPlace,
            "currentPlace": viewModel.currentPlace,
            "birthLat": viewModel.birthCoordinate?.latitude ?? 0,
            "birthLng": viewModel.birthCoordinate?.longitude ?? 0,
            "currentLat": lat,
            "currentLng": lng,
            "createdAt": Timestamp()
        ]

        // 可选保留：同时写入一个 Timestamp 生日（仅用于“年月日”）
        data["birthday"] = Timestamp(date: viewModel.birth_date)

        // ✅ 固定 docId，避免重复文档
        let ref = db.collection("users").document(userId)
        ref.setData(data, merge: true) { error in
            if let error = error {
                print("❌ Firebase 写入失败: \(error)")
            } else {
                print("✅ 用户信息已保存/更新（users/\(userId)）")
                hasCompletedOnboarding = true
            }
        }

        // ===== 下面保持你原有的 FastAPI 请求逻辑 =====
        // 这里仍然用你原来传给后端的“字符串时间”，不会影响我们在 Firestore 的存储方案
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = .current
        timeFormatter.dateFormat = "HH:mm"
        let birthTimeString = timeFormatter.string(from: viewModel.birth_time)

        let payload: [String: Any] = [
            "birth_date": birthDateString,
            "birth_time": birthTimeString,
            "latitude": lat,
            "longitude": lng
        ]

        guard let url = URL(string: "https://aligna-api-16639733048.us-central1.run.app/recommend/") else {
            print("❌ 无效的 FastAPI URL")
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ JSON 序列化失败: \(error)")
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ FastAPI 请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async { isLoading = false }
                return
            }
            guard let data = data,
                  let raw = String(data: data, encoding: .utf8),
                  let cleanedData = raw.data(using: .utf8) else {
                print("❌ FastAPI 无响应数据或解码失败")
                DispatchQueue.main.async { isLoading = false }
                return
            }

            do {
                if let parsed = try JSONSerialization.jsonObject(with: cleanedData) as? [String: Any],
                   let recs = parsed["recommendations"] as? [String: String],
                   let mantraText = parsed["mantra"] as? String {
                    DispatchQueue.main.async {
                        viewModel.recommendations = recs
                        self.isLoading = false

                        guard let userId = Auth.auth().currentUser?.uid else { return }
                        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                        let createdAt = df.string(from: Date())

                        var recommendationData: [String: Any] = recs
                        recommendationData["uid"] = userId
                        recommendationData["createdAt"] = createdAt
                        recommendationData["mantra"] = mantraText

                        let docId = "\(userId)_\(createdAt)"
                        Firestore.firestore()
                            .collection("daily_recommendation")
                            .document(docId)
                            .setData(recommendationData, merge: true) { error in
                                if let error = error {
                                    print("❌ 保存 daily_recommendation 失败：\(error)")
                                } else {
                                    print("✅ 推荐结果保存成功（幂等写入）")
                                    UserDefaults.standard.set(createdAt, forKey: "lastRecommendationDate")
                                }
                            }

                        self.isLoggedIn = true
                        self.hasCompletedOnboarding = true
                        self.shouldOnboardAfterSignIn = false
                        navigateToHome = true
                    }
                } else {
                    print("❌ JSON 解包失败或缺少字段")
                    DispatchQueue.main.async { self.isLoading = false }
                }
            } catch {
                print("❌ JSON 解析失败: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
    }

}
func firebaseCollectionName(for category: String) -> String {
    let mapping: [String: String] = [
        "Place": "places",
        "Gemstone": "gemstones",
        "Color": "colors",
        "Scent": "scents",
        "Activity": "activities",
        "Sound": "sounds",
        "Career": "careers",
        "Relationship": "relationships"
    ]
    return mapping[category] ?? ""
}


import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import FirebaseCore
import UIKit

struct AccountPageView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var currentNonce: String? = nil
    @State private var navigateToHome = false
    @State private var authBusy = false

    // 入场动画
    @State private var showIntro = false

    // 焦点控制
    @FocusState private var loginFocus: LoginField?
    private enum LoginField { case email, password }

    private var panelBG: Color { Color.white.opacity(0.10) }

    var body: some View {
        GeometryReader { geometry in
            let minLength = min(geometry.size.width, geometry.size.height)

            ZStack {
                AppBackgroundView(mode: .night)
                    .environmentObject(starManager)
                    .environmentObject(themeManager)

                VStack {
                    // 顶部返回
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .padding()
                                .background(panelBG)
                                .clipShape(Circle())
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                        }
                        .padding(.leading, geometry.size.width * 0.05)
                        .padding(.top, geometry.size.height * 0.05)
                        Spacer()
                    }
                    .staggered(0, show: $showIntro)

                    Spacer(minLength: geometry.size.height * 0.03)

                    // 标题区
                    VStack(spacing: minLength * 0.02) {
                        AlignaHeading(
                            textColor: themeManager.fixedNightTextPrimary,
                            show: $showIntro,
                            fontSize: minLength * 0.12,
                            letterSpacing: minLength * 0.005
                        )

                        VStack(spacing: 6) {
                            Text("Welcome Back")
                                .font(.title3)
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                            Text("Sign in to continue your journey")
                                .font(.subheadline)
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                        }
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                    }
                    .staggered(1, show: $showIntro)

                    Spacer(minLength: geometry.size.height * 0.02)

                    // 表单
                    VStack(spacing: minLength * 0.035) {

                        // Email
                        Group {
                            TextField("", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding(.vertical, 14)
                                .padding(.leading, 16)
                                .background(panelBG)
                                .cornerRadius(14)
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                                .placeholder(when: email.isEmpty) {
                                    Text("Enter your email")
                                        .foregroundColor(themeManager.fixedNightTextSecondary)
                                        .padding(.leading, 16)
                                }
                                .focused($loginFocus, equals: .email)
                                .focusGlow(
                                    active: loginFocus == .email,
                                    color: themeManager.fixedNightTextPrimary,
                                    lineWidth: 2,
                                    cornerRadius: 14
                                )
                                .submitLabel(.next)
                                .onSubmit { loginFocus = .password }
                        }
                        .staggered(2, show: $showIntro)
                        .animation(nil, value: loginFocus)

                        // Password
                        Group {
                            SecureField("", text: $password)
                                .padding(.vertical, 14)
                                .padding(.leading, 16)
                                .background(panelBG)
                                .cornerRadius(14)
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                                .placeholder(when: password.isEmpty) {
                                    Text("Enter your password")
                                        .foregroundColor(themeManager.fixedNightTextSecondary)
                                        .padding(.leading, 16)
                                }
                                .focused($loginFocus, equals: .password)
                                .focusGlow(
                                    active: loginFocus == .password,
                                    color: themeManager.fixedNightTextPrimary,
                                    lineWidth: 2,
                                    cornerRadius: 14
                                )
                                .submitLabel(.done)
                        }
                        .staggered(3, show: $showIntro)
                        .animation(nil, value: loginFocus)

                        // Forgot Password
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                guard !authBusy else { return }
                                if email.isEmpty {
                                    alertMessage = "Enter your email first."
                                    showAlert = true
                                    return
                                }
                                authBusy = true
                                Auth.auth().sendPasswordReset(withEmail: email) { error in
                                    authBusy = false
                                    if let error = error {
                                        alertMessage = error.localizedDescription
                                    } else {
                                        alertMessage = "Password reset email sent."
                                    }
                                    showAlert = true
                                }
                            }
                            .font(.footnote)
                            .foregroundColor(themeManager.fixedNightTextSecondary)
                            .underline()
                        }
                        .staggered(4, show: $showIntro)

                        // Log In
                        Button(action: {
                            guard !authBusy else { return }
                            if email.isEmpty || password.isEmpty {
                                alertMessage = "Please enter both email and password."
                                showAlert = true
                                return
                            }
                            authBusy = true
                            Auth.auth().signIn(withEmail: email, password: password) { _, error in
                                authBusy = false
                                if let error = error,
                                   let code = AuthErrorCode(rawValue: (error as NSError).code) {
                                    switch code {
                                    case .wrongPassword: alertMessage = "Incorrect password. Please try again."
                                    case .invalidEmail: alertMessage = "Invalid email address."
                                    case .userDisabled: alertMessage = "This account has been disabled."
                                    case .userNotFound: alertMessage = "No account found with this email."
                                    default: alertMessage = error.localizedDescription
                                    }
                                    showAlert = true
                                    return
                                }
                                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                                navigateToHome = true
                            }
                        }) {
                            Text(authBusy ? "Logging in…" : "Log In")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.fixedNightTextPrimary)
                                .foregroundColor(.black)
                                .cornerRadius(14)
                        }
                        .disabled(authBusy)
                        .staggered(5, show: $showIntro)

                        // 分隔线
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                            Text("or login with")
                                .font(.footnote)
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                            Rectangle().fill(Color.white.opacity(0.30)).frame(height: 1)
                        }
                        .staggered(6, show: $showIntro)

                        // Google / Apple
                        VStack(spacing: minLength * 0.025) {
                            Button(action: {
                                guard !authBusy else { return }
                                authBusy = true
                                handleGoogleLogin(
                                    viewModel: viewModel,
                                    onSuccessToLogin: {
                                        authBusy = false
                                        isLoggedIn = true
                                        navigateToHome = true
                                    },
                                    onSuccessToOnboarding: {
                                        authBusy = false
                                    },
                                    onError: { message in
                                        authBusy = false
                                        alertMessage = message
                                        showAlert = true
                                    }
                                )
                            }) {
                                HStack(spacing: 12) {
                                    Image("googleIcon")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    Text("Continue with Google")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(themeManager.fixedNightTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(panelBG)
                                .cornerRadius(14)
                            }
                            .staggered(7, show: $showIntro)

                            SignInWithAppleButton(
                                .signIn,
                                onRequest: { request in
                                    let nonce = randomNonceString()
                                    currentNonce = nonce
                                    request.requestedScopes = [.fullName, .email]
                                    request.nonce = sha256(nonce)
                                },
                                onCompletion: { result in
                                    guard !authBusy else { return }
                                    guard let raw = currentNonce, !raw.isEmpty else {
                                        alertMessage = "Missing nonce. Please try again."
                                        showAlert = true
                                        return
                                    }
                                    authBusy = true
                                    handleAppleLogin(
                                        result: result,
                                        rawNonce: raw,
                                        onSuccessToLogin: {
                                            authBusy = false
                                            isLoggedIn = true
                                            navigateToHome = true
                                        },
                                        onSuccessToOnboarding: {
                                            authBusy = false
                                        },
                                        onError: { message in
                                            authBusy = false
                                            alertMessage = message
                                            showAlert = true
                                        }
                                    )
                                }
                            )
                            .frame(height: 50)
                            .signInWithAppleButtonStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .staggered(8, show: $showIntro)
                        }
                        .padding(.top, 2)

                        // 去注册
                        HStack {
                            Text("Don't have an account?")
                                .font(.footnote)
                                .foregroundColor(themeManager.fixedNightTextSecondary)
                            NavigationLink(
                                destination: RegisterPageView()
                                    .environmentObject(starManager)
                                    .environmentObject(themeManager)
                                    .environmentObject(viewModel)
                            ) {
                                Text("Sign Up")
                                    .font(.footnote)
                                    .foregroundColor(themeManager.fixedNightTextPrimary)
                                    .underline()
                            }
                        }
                        .padding(.top)
                        .staggered(9, show: $showIntro)
                    }
                    .padding(.horizontal, geometry.size.width * 0.1)

                    Spacer(minLength: geometry.size.height * 0.08)
                }
            }
            .navigationDestination(isPresented: $navigateToHome) {
                FirstPageView()
                    .environmentObject(starManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
                    .navigationBarBackButtonHidden(true)
            }
            .preferredColorScheme(.dark)
            .onAppear {
                starManager.animateStar = true
                showIntro = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showIntro = true }
            }
            .onDisappear { showIntro = false }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
// MARK: - 登录工具函数（可直接替换）
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import FirebaseCore
import UIKit

// 1) 查询用户是否已经在 users 表里存在
func checkIfUserAlreadyRegistered(uid: String, completion: @escaping (Bool) -> Void) {
    let db = Firestore.firestore()
    db.collection("users")
        .whereField("uid", isEqualTo: uid)
        .limit(to: 1)
        .getDocuments { snapshot, error in
            if let error = error {
                print("❌ 查询用户注册状态失败: \(error)")
                completion(false)
                return
            }
            let isRegistered = !(snapshot?.documents.isEmpty ?? true)
            print(isRegistered ? "✅ 用户已注册" : "🆕 用户未注册")
            completion(isRegistered)
        }
}

// 统一设置本地标记（保持你旧代码兼容性）
private func updateLocalFlagsForReturningUser() {
    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    UserDefaults.standard.set(true, forKey: "isLoggedIn")
    print("🧭 Flags updated: hasCompletedOnboarding=true, isLoggedIn=true")
}

// 2) Google 登录（新版 withPresenting）
func handleGoogleLogin(
    viewModel: OnboardingViewModel,
    onSuccessToLogin: @escaping () -> Void,
    onSuccessToOnboarding: @escaping () -> Void,
    onError: @escaping (String) -> Void
) {
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        onError("Missing Firebase client ID.")
        return
    }
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

    guard let rootVC = UIApplication.shared.connectedScenes
        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
        onError("No root view controller.")
        return
    }

    GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
        if let error = error {
            onError("Google Sign-In failed: \(error.localizedDescription)")
            return
        }
        guard let user = result?.user,
              let idToken = user.idToken?.tokenString else {
            onError("Missing Google token.")
            return
        }

        let accessToken = user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                onError("Login failed: \(error.localizedDescription)")
                return
            }
            guard let uid = Auth.auth().currentUser?.uid else {
                onError("获取 UID 失败")
                return
            }

            // 判断是否老用户 → 决定跳转，并为老用户设置本地 flags
            checkIfUserAlreadyRegistered(uid: uid) { isRegistered in
                DispatchQueue.main.async {
                    if isRegistered {
                        updateLocalFlagsForReturningUser()  // ← 关键：老用户标记完成引导
                        onSuccessToLogin()
                    } else {
                        // 新用户：走 Onboarding，完成后 OnboardingFinalStep 会把 hasCompletedOnboarding 置 true
                        onSuccessToOnboarding()
                    }
                }
            }
        }
    }
}

// 3) Apple 登录
func handleAppleLogin(
    result: Result<ASAuthorization, Error>,
    rawNonce: String,
    onSuccessToLogin: @escaping () -> Void,
    onSuccessToOnboarding: @escaping () -> Void,
    onError: @escaping (String) -> Void
) {
    switch result {
    case .success(let authResults):
        guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            onError("Apple 登录失败，无法获取 token")
            return
        }

        let credential = OAuthProvider.credential(
            providerID: .apple,          // 或 AuthProviderID.apple
            idToken: tokenString,
            rawNonce: rawNonce
        )


        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                onError("Apple 登录失败: \(error.localizedDescription)")
                return
            }
            guard let uid = Auth.auth().currentUser?.uid else {
                onError("获取 UID 失败")
                return
            }

            checkIfUserAlreadyRegistered(uid: uid) { isRegistered in
                DispatchQueue.main.async {
                    if isRegistered {
                        updateLocalFlagsForReturningUser()  // ← 关键：老用户标记完成引导
                        onSuccessToLogin()
                    } else {
                        onSuccessToOnboarding()
                    }
                }
            }
        }

    case .failure(let error):
        onError("Apple 授权失败: \(error.localizedDescription)")
    }
}
import GoogleSignIn
import FirebaseAuth
import FirebaseCore
import UIKit
/// 替换你原有的 Google 注册逻辑（新版 API）
/// - onNewUserGoOnboarding: 新用户引导回调（进入 Step1）
/// - onExistingUserGoLogin: 老用户提示去登录的回调（传入提示文案）
/// - onError: 失败提示
func handleGoogleFromRegister(
    onNewUserGoOnboarding: @escaping () -> Void,
    onExistingUserGoLogin: @escaping (_ message: String) -> Void,
    onError: @escaping (_ message: String) -> Void
) {
    // 1) 准备配置与呈现控制器
    guard let clientID = FirebaseApp.app()?.options.clientID else {
        onError("Missing Firebase clientID."); return
    }
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    guard let presenter = UIApplication.shared.topViewController_aligna else {
        onError("No presenting view controller."); return
    }

    // 2) 调起 Google 登录（新版 withPresenting）
    GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { signInResult, signInError in
        if let signInError = signInError {
            onError("Google sign-in failed: \(signInError.localizedDescription)")
            return
        }
        guard
            let user = signInResult?.user,
            let idToken = user.idToken?.tokenString
        else {
            onError("Empty Google sign-in result."); return
        }

        // 3) 用 Google 凭证登录 Firebase
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        Auth.auth().signIn(with: credential) { authResult, authError in
            if let authError = authError {
                onError("Firebase auth failed: \(authError.localizedDescription)")
                return
            }

            let isNew = authResult?.additionalUserInfo?.isNewUser ?? false
            if isNew {
                // 新用户：进入 Onboarding（你按钮里已经把 shouldOnboardAfterSignIn 置为 true）
                onNewUserGoOnboarding()
            } else {
                // 老用户：提示去登录页
                onExistingUserGoLogin("This Google account is already registered. Please sign in instead.")
            }
        }
    }
}

// ===============================
// 注册页专用：Apple（替换原函数）
// ===============================
func handleAppleFromRegister(
    result: Result<ASAuthorization, Error>,
    rawNonce: String,
    onNewUserGoOnboarding: @escaping () -> Void,
    onExistingUserGoLogin: @escaping (_ message: String) -> Void,
    onError: @escaping (String) -> Void
) {
    switch result {
    case .success(let authResults):
        guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            onError("Apple 登录失败，无法获取 token")
            return
        }

        let credential = OAuthProvider.credential(
            providerID: .apple,
            idToken: tokenString,
            rawNonce: rawNonce
        )

        Auth.auth().signIn(with: credential) { _, error in
            if let error = error {
                onError("Apple 登录失败: \(error.localizedDescription)")
                return
            }
            // ⚠️ 关键：按“资料完整度”来分流
            determineRegistrationPathForCurrentUser { path in
                DispatchQueue.main.async {
                    switch path {
                    case .needsOnboarding:
                        onNewUserGoOnboarding()
                    case .existingAccount:
                        onExistingUserGoLogin("This Apple ID is already registered. Redirecting to Sign In…")
                        try? Auth.auth().signOut()
                    }
                }
            }
        }

    case .failure(let error):
        onError("Apple 授权失败: \(error.localizedDescription)")
    }
}

// ===============================
// 辅助：基于“资料完整度”的分流（新增）
// ===============================

private enum RegistrationPath { case needsOnboarding, existingAccount }

/// 读取当前登录用户在 Firestore 的档案；
/// 若无文档或文档不完整（缺少昵称/生日/出生时间/出生地），→ 需要 Onboarding；
/// 若文档完整 → 视为老用户。
private func determineRegistrationPathForCurrentUser(
    completion: @escaping (RegistrationPath) -> Void
) {
    guard let uid = Auth.auth().currentUser?.uid else {
        completion(.needsOnboarding); return
    }
    fetchUserDocByUID(uid) { data in
        guard let data = data else {
            // 没有任何用户文档 → 新用户
            completion(.needsOnboarding); return
        }
        completion(isProfileComplete(data) ? .existingAccount : .needsOnboarding)
    }
}

/// 依次在 "users" / "user" 集合中按 uid 查找文档，返回 data（任一命中即返回）
private func fetchUserDocByUID(_ uid: String, completion: @escaping ([String: Any]?) -> Void) {
    let db = Firestore.firestore()
    let cols = ["users", "user"]
    func go(_ i: Int) {
        if i >= cols.count { completion(nil); return }
        db.collection(cols[i]).whereField("uid", isEqualTo: uid).limit(to: 1).getDocuments { snap, _ in
            if let data = snap?.documents.first?.data() { completion(data) }
            else { go(i + 1) }
        }
    }
    go(0)
}

/// 判定档案是否“完整”：
/// - 昵称 nickname: 非空
/// - 生日：支持两种历史字段：`birthday`(Timestamp) 或 `birthDate`(String) 任一存在
/// - 出生时间 birthTime: 非空字符串
/// - 出生地 birthPlace: 非空字符串
private func isProfileComplete(_ d: [String: Any]) -> Bool {
    let nicknameOK   = !(d["nickname"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    let hasBirthTS   = d["birthday"] is Timestamp
    let hasBirthStr  = ((d["birthDate"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    let birthDateOK  = hasBirthTS || hasBirthStr
    let birthTimeOK  = ((d["birthTime"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    let birthPlaceOK = ((d["birthPlace"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)

    return nicknameOK && birthDateOK && birthTimeOK && birthPlaceOK
}



import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserInfo: Codable {
    var nickname: String
    var birth_date: String
    var birthPlace: String
    var birth_time: String
    var currentPlace: String
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// ========== Firestore Keys（不一致就改这里） ==========
private enum FSKeys {
    static let userPrimary   = "user"
    static let userAlt       = "users"
    static let recPrimary    = "daily recommendation"
    static let recAlt        = "daily_recommendation"

    static let uid           = "uid"
    static let email         = "email"
    static let nickname      = "nickname"
    static let birthday      = "birthday"   // Firestore Timestamp
    static let birthTime     = "birthTime"  // "h:mm a" 字符串
    static let birthPlace    = "birthPlace"
    static let currentPlace  = "currentPlace"
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// 主题偏好（轻/暗/系统）
private enum ThemePreference: String, CaseIterable, Identifiable {
    case light, dark, auto
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return "Light"
        case .dark:  return "Dark"
        case .auto:  return "System"
        }
    }
    var icon: String  {
        switch self {
        case .light: return "sun.max"
        case .dark:  return "moon.stars"
        case .auto:  return "gearshape"
        }
    }
}

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import AuthenticationServices
import FirebaseCore
import GoogleSignIn
import UIKit

struct AccountDetailView: View {
    @EnvironmentObject var starManager: StarAnimationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    // Firestore
    @State private var userDocID: String?
    @State private var userCollectionUsed: String?
    private let db = Firestore.firestore()

    // 当前登录用户
    @State private var email: String = Auth.auth().currentUser?.email ?? ""

    // 用户字段（UI 状态）
    @State private var nickname: String = ""
    @State private var birthday: Date = Date()
    @State private var birthTime: Date = Date()
    @State private var birthPlace: String = ""
    @State private var currentPlace: String = ""
    
    // Birth location & timezone & raw input (for exact display)
    @State private var birthLat: Double = 0
    @State private var birthLng: Double = 0
    @State private var birthTimezoneOffsetMinutes: Int = TimeZone.current.secondsFromGMT() / 60
    @State private var birthRawTimeString: String? = nil


    // 编辑状态
    @State private var editingNickname = false
    @State private var editingBirthPlace = false
    @State private var showBirthdaySheet = false
    @State private var showBirthTimeSheet = false

    // 主题偏好
    @AppStorage("themePreference") private var themePreferenceRaw: String = ThemePreference.auto.rawValue

    // Busy & Error
    @State private var isBusy = false
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?
    
    
    // 保持定位器存活，避免回调丢失
    @State private var activeLocationFetcher: OneShotLocationFetcher?

    // 刷新结果弹窗
    @State private var showRefreshAlert = false
    @State private var refreshAlertTitle = ""
    @State private var refreshAlertMessage = ""


    // === 固定英文格式的 Formatter（static，避免 mutating getter 报错）===
    private static let enUSPOSIX = Locale(identifier: "en_US_POSIX")

    private static let birthdayDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "MMM/d/yyyy"
        return f
    }()

    private static let birthTimeDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "h:mm a"
        return f
    }()
    private static let birthDateDisplayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = .current
        df.locale   = .current
        df.timeZone = .current
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private static let birthTimeStorageFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    // 解析兼容：旧的字符串存储
    private static let parseTimeFormatter12: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "h:mm a"
        return f
    }()
    private static let parseTimeFormatter24: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let parseDateYYYYMMDD: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let parseDateYMDSlash: DateFormatter = {
        let f = DateFormatter()
        f.locale = enUSPOSIX; f.timeZone = .current
        f.dateFormat = "yyyy/M/d" // 兼容少量 “2024/9/22” 样式
        return f
    }()

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                ZStack {
                    AppBackgroundView()
                        .environmentObject(starManager)
                        .environmentObject(themeManager)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            headerCard
                            personalInfoCard
                            timelineCard
                            themeCard
                            aboutCard
                            signOutCard
                            deleteAccountCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 36)
                    }

                    if isBusy {
                        ProgressView()
                            .scaleEffect(1.1)
                            .padding(18)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(themeManager.primaryText)
                        }
                    }
                }
                .onAppear {
                    makeNavBarTransparent()
                    themeManager.setSystemColorScheme(colorScheme)
                    initialLoad()
                }
                .onDisappear { restoreNavBarDefault() }
                .onChange(of: colorScheme) { newScheme in
                    themeManager.setSystemColorScheme(newScheme)
                }
            }
        }
        .alert("Delete Account?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove your profile and all daily recommendations associated with \(email).")
        }
        .alert("Error",
               isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(refreshAlertTitle, isPresented: $showRefreshAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(refreshAlertMessage)
        }

        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(themeManager.preferredColorScheme)
    }

    // MARK: - 导航栏透明/恢复
    private func makeNavBarTransparent() {
        let ap = UINavigationBarAppearance()
        ap.configureWithTransparentBackground()
        ap.backgroundEffect = nil
        ap.backgroundColor  = .clear
        ap.shadowColor      = .clear
        let nav = UINavigationBar.appearance()
        nav.standardAppearance = ap
        nav.scrollEdgeAppearance = ap
        nav.compactAppearance = ap
        nav.isTranslucent = true
    }
    private func restoreNavBarDefault() {
        let ap = UINavigationBarAppearance()
        ap.configureWithDefaultBackground()
        let nav = UINavigationBar.appearance()
        nav.standardAppearance = ap
        nav.scrollEdgeAppearance = ap
        nav.compactAppearance = ap
        nav.isTranslucent = false
    }
}

// MARK: - UI Sections
private extension AccountDetailView {
    var headerCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if editingNickname {
                    TextField("Nickname", text: $nickname)
                        .multilineTextAlignment(.center)
                        .font(.custom("PlayfairDisplay-Regular", size: 36))
                        .foregroundColor(themeManager.primaryText)
                        .tint(themeManager.accent)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    HStack(spacing: 10) {
                        Button { saveField(FSKeys.nickname, value: nickname) { editingNickname = false } }
                        label: { Image(systemName: "checkmark.circle.fill").font(.title2) }

                        Button { editingNickname = false; loadUser() }
                        label: { Image(systemName: "xmark.circle.fill").font(.title2) }
                    }
                    .foregroundColor(themeManager.accent)
                } else {
                    Text(nickname.isEmpty ? "—" : nickname)
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundColor(themeManager.primaryText)

                    Button { editingNickname = true } label: {
                        Image(systemName: "pencil").font(.title3).foregroundColor(themeManager.accent)
                    }
                }
            }

            // Inline zodiac row — use locally computed texts to avoid "Unknown"
            ZodiacInlineRow(
                sunText:  sunSignText,
                moonText: moonSignText,
                ascText:  ascSignText
            )
            .environmentObject(themeManager)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }



    var personalInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Personal Information")
                .font(.title3.weight(.semibold))
                .foregroundColor(themeManager.primaryText)

            VStack(spacing: 12) {
                // === Birthday | Birth Time ===
                // === Birthday | Birth Time ===
                // === Birthday | Birth Time ===
                HStack(spacing: 12) {
                    // Birthday —— 显示“日期”
                    infoRow(
                        title: "Birthday",
                        value: Self.birthDateDisplayFormatter.string(from: birthday),
                        editable: true
                    ) { showBirthdaySheet = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sheet(isPresented: $showBirthdaySheet) {
                        pickerSheet(
                            title: "Birthday",
                            picker: AnyView(
                                DatePicker("", selection: $birthday, displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                            ),
                            onSave: {
                                saveBirthDateOnly(newDate: birthday) {
                                    showBirthdaySheet = false
                                }
                            },
                            onCancel: { showBirthdaySheet = false }
                        )
                    }

                    // Birth Time —— 显示 “时:分 am/pm（或系统 24h）”
                    infoRow(
                        title: "Birth Time",
                        value: BirthTimeUtils.displayFormatter.string(from: birthTime).lowercased(),
                        editable: true
                    ) { showBirthTimeSheet = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sheet(isPresented: $showBirthTimeSheet) {
                        pickerSheet(
                            title: "Birth Time",
                            picker: AnyView(
                                DatePicker("", selection: $birthTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                            ),
                            onSave: {
                                saveBirthTimeOnly(newTime: birthTime) {
                                    showBirthTimeSheet = false
                                }
                            },
                            onCancel: { showBirthTimeSheet = false }
                        )
                    }
                }



                // === Birth Place | Current Place ===
                HStack(spacing: 12) {
                    infoRowEditableText(
                        title: "Birth Place",
                        text: $birthPlace,
                        isEditing: $editingBirthPlace,
                        onSave: { saveField(FSKeys.birthPlace, value: birthPlace) { editingBirthPlace = false } },
                        onCancel: { editingBirthPlace = false; loadUser() }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    infoRowWithTrailingButton(
                        title: "Current Place",
                        value: currentPlace.isEmpty ? "—" : currentPlace,
                        systemImage: "arrow.clockwise",
                        onTap: { refreshCurrentPlace() }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(Color.white.opacity(themeManager.isNight ? 0.05 : 0.08),
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(themeManager.isNight ? 0.08 : 0.06), lineWidth: 1))
        }
    }

    var timelineCard: some View {
        NavigationLink {
            ContentView()
                .environmentObject(starManager)
                .environmentObject(themeManager)
                .environmentObject(viewModel)
        } label: {
            rowCard(icon: "calendar", title: "Timeline", subtitle: "View your cosmic journey history")
        }
    }

    var themeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundColor(themeManager.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Theme").font(.headline).foregroundColor(themeManager.primaryText)
                    Text("Customize appearance").font(.subheadline).foregroundColor(themeManager.descriptionText)
                }
            }
            HStack(spacing: 12) { themeOption(.light); themeOption(.dark); themeOption(.auto) }
        }
        .padding()
        .background(Color.white.opacity(themeManager.isNight ? 0.05 : 0.08),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(Color.white.opacity(themeManager.isNight ? 0.08 : 0.06), lineWidth: 1))
    }

    var aboutCard: some View {
        NavigationLink { Text("About Alynna").padding() } label: {
            rowCard(icon: "info.circle",
                    title: "About Alynna",
                    subtitle: "Learn more about the app and privacy")
        }
    }

    var signOutCard: some View {
        Button {
            do { try Auth.auth().signOut(); dismiss() }
            catch { errorMessage = error.localizedDescription }
        } label: {
            rowCard(icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign out",
                    subtitle: "Sign out of your account")
        }
    }

    var deleteAccountCard: some View {
        Button(role: .destructive) { showDeleteAlert = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete Account").font(.headline).foregroundColor(.white)
                    Text("Permanently delete your account and data")
                        .font(.subheadline)
                        .foregroundColor(themeManager.descriptionText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.red.opacity(0.35), lineWidth: 1))
            .foregroundColor(.white)
        }
    }
    var astrologyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Astrology (approximate)")
                .font(.title3.weight(.semibold))
                .foregroundColor(themeManager.primaryText)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sun sign").font(.footnote).foregroundColor(themeManager.descriptionText)
                        Text(sunSignText).font(.headline).foregroundColor(themeManager.primaryText)
                    }
                    Spacer()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Moon sign").font(.footnote).foregroundColor(themeManager.descriptionText)
                        Text(moonSignText).font(.headline).foregroundColor(themeManager.primaryText)
                    }
                    Spacer()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ascendant").font(.footnote).foregroundColor(themeManager.descriptionText)
                        Text(ascSignText).font(.headline).foregroundColor(themeManager.primaryText)
                    }
                    Spacer()
                }
                Text("Note: Lightweight astronomical approximations; values near sign cusps may vary slightly.")
                    .font(.footnote)
                    .foregroundColor(themeManager.descriptionText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.white.opacity(themeManager.isNight ? 0.05 : 0.08),
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(themeManager.isNight ? 0.08 : 0.06), lineWidth: 1))
        }
    }

}

// MARK: - Reusable UI
private extension AccountDetailView {
    func rowCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(themeManager.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundColor(themeManager.primaryText)
                Text(subtitle).font(.subheadline).foregroundColor(themeManager.descriptionText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(themeManager.primaryText.opacity(0.9))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(themeManager.isNight ? 0.05 : 0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(themeManager.isNight ? 0.08 : 0.06), lineWidth: 1))
    }

    func infoRow(title: String, value: String, editable: Bool, onEdit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 上面一行：标题
            Text(title)
                .font(.footnote)
                .foregroundColor(themeManager.descriptionText)

            // 下面一行：内容 + 小笔 靠在一起
            HStack(spacing: 6) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(themeManager.primaryText)

                if editable {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.body.weight(.semibold))
                            .foregroundColor(themeManager.accent)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 6)
    }

    
    func infoRowWithTrailingButton(
        title: String,
        value: String,
        systemImage: String,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 上面一行：标题
            Text(title)
                .font(.footnote)
                .foregroundColor(themeManager.descriptionText)

            // 下面一行：内容 + 按钮 靠在一起
            HStack(spacing: 6) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(themeManager.primaryText)

                Button(action: onTap) {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundColor(themeManager.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Refresh \(title)"))

                Spacer(minLength: 0) // 可要可不要，留一点弹性空间
            }
        }
        .padding(.vertical, 6)
    }



    func infoRowEditableText(
        title: String,
        text: Binding<String>,
        isEditing: Binding<Bool>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 上面一行：标题
            Text(title)
                .font(.footnote)
                .foregroundColor(themeManager.descriptionText)

            // 下面一行：内容 / TextField + 图标 靠在一起
            HStack(spacing: 6) {
                if isEditing.wrappedValue {
                    TextField(title, text: text)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .tint(themeManager.accent)
                        .foregroundColor(themeManager.primaryText)
                        .font(.headline)
                } else {
                    Text(text.wrappedValue.isEmpty ? "—" : text.wrappedValue)
                        .font(.headline)
                        .foregroundColor(themeManager.primaryText)
                }

                if isEditing.wrappedValue {
                    HStack(spacing: 10) {
                        Button(action: onSave) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                        }
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                        }
                    }
                    .foregroundColor(themeManager.accent)
                } else {
                    Button { isEditing.wrappedValue = true } label: {
                        Image(systemName: "pencil")
                            .font(.body.weight(.semibold))
                            .foregroundColor(themeManager.accent)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 6)
    }


    func themeOption(_ pref: ThemePreference) -> some View {
        let selected = themePreferenceRaw == pref.rawValue
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                themePreferenceRaw = pref.rawValue
                switch pref {
                case .light: themeManager.selected = .day
                case .dark:  themeManager.selected = .night
                case .auto:  themeManager.selected = .system
                }
                themeManager.setSystemColorScheme(colorScheme)
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: pref.icon).font(.title2)
                Text(pref.title).font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? themeManager.accent.opacity(0.18)
                                   : Color.white.opacity(themeManager.isNight ? 0.06 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? themeManager.accent : Color.white.opacity(0.15),
                            lineWidth: selected ? 1 : 0.8)
            )
            .foregroundColor(selected ? themeManager.accent : themeManager.primaryText)
        }
        .buttonStyle(.plain)
    }
    /// Map "Aries" -> "aries", "Taurus" -> "taurus", ... for SF Symbols.
    /// If not found, fall back to "questionmark.circle".
    func zodiacSFIcon(for signName: String) -> String {
        switch signName.lowercased() {
        case "aries": return "aries"
        case "taurus": return "taurus"
        case "gemini": return "gemini"
        case "cancer": return "cancer"
        case "leo": return "leo"
        case "virgo": return "virgo"
        case "libra": return "libra"
        case "scorpio": return "scorpio"
        case "sagittarius": return "sagittarius"
        case "capricorn": return "capricorn"
        case "aquarius": return "aquarius"
        case "pisces": return "pisces"
        default: return "questionmark.circle"
        }
    }

    /// A compact pill with a kind icon (sun/moon/asc) + the zodiac glyph + text value.
    func zodiacPill(title: String, systemImage: String, signImage: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.caption2.weight(.semibold))
            Image(systemName: signImage).font(.caption2.weight(.semibold))
            Text(title).font(.caption2.weight(.semibold))
            Text(value).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(themeManager.isNight ? 0.06 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(themeManager.isNight ? 0.1 : 0.08), lineWidth: 0.8)
        )
        .foregroundColor(themeManager.primaryText)
    }


    @ViewBuilder
    func pickerSheet(title: String, picker: AnyView, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text(title).font(.headline).foregroundColor(themeManager.primaryText)
            picker.tint(themeManager.accent)
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Save", action: onSave)
            }
            .foregroundColor(themeManager.accent)
            .padding(.horizontal)
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .presentationDetents([.height(320)])
        .presentationBackground(.ultraThinMaterial)
    }
    final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
        private let manager = CLLocationManager()
        private var callback: ((Result<CLLocationCoordinate2D, Error>) -> Void)?

        override init() {
            super.init()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }

        func requestOnce(_ cb: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
            self.callback = cb
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                cb(.failure(NSError(domain: "Aligna", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "Location permission denied."])))
            default:
                manager.requestLocation()
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = locations.first else {
                callback?(.failure(NSError(domain: "Aligna", code: 2,
                                           userInfo: [NSLocalizedDescriptionKey: "No location found."])))
                callback = nil
                return
            }
            callback?(.success(loc.coordinate)); callback = nil
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            callback?(.failure(error)); callback = nil
        }
    }
    
    func refreshCurrentPlace() {
        // 防抖：忙时不再进入
        if isBusy { return }

        isBusy = true
        errorMessage = nil

        let previous = self.currentPlace.trimmingCharacters(in: .whitespacesAndNewlines)

        // 10 秒看门狗，防止永久 loading
        var timedOut = false
        let watchdog = DispatchWorkItem {
            timedOut = true
            self.isBusy = false
            self.activeLocationFetcher = nil
            self.refreshAlertTitle = "Location Timeout"
            self.refreshAlertMessage = "定位超过 10 秒未返回，请稍后再试或检查定位权限。"
            self.showRefreshAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: watchdog)

        // 持有引用，确保回调能触发
        let fetcher = OneShotLocationFetcher()
        self.activeLocationFetcher = fetcher

        fetcher.requestOnce { result in
            // 任一回调路径都先清理看门狗
            DispatchQueue.main.async {
                if !watchdog.isCancelled { watchdog.cancel() }
            }

            switch result {
            case .failure(let err):
                DispatchQueue.main.async {
                    guard !timedOut else { return } // 已经被看门狗处理
                    self.isBusy = false
                    self.activeLocationFetcher = nil
                    self.refreshAlertTitle = "Location Error"
                    self.refreshAlertMessage = err.localizedDescription
                    self.showRefreshAlert = true
                }

            case .success(let coord):
                // 逆地理
                getAddressFromCoordinate(coord) { maybeCity in
                    DispatchQueue.main.async {
                        guard !timedOut else { return }

                        let city = (maybeCity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let placeToShow = city.isEmpty
                            ? String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
                            : city

                        // 更新 UI
                        self.currentPlace = placeToShow

                        // 写入 Firestore（即使没变也写：更新坐标 & 时间戳）
                        var payload: [String: Any] = [
                            FSKeys.currentPlace: placeToShow,
                            "currentLat": coord.latitude,
                            "currentLng": coord.longitude,
                            "updatedAt": FieldValue.serverTimestamp()
                        ]
                        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastCurrentPlaceUpdate")

                        func finishAndAlert() {
                            self.isBusy = false
                            self.activeLocationFetcher = nil

                            // 比较是否变化（大小写与首尾空格忽略）
                            let changed = previous.lowercased() != placeToShow.lowercased()

                            if changed {
                                self.refreshAlertTitle = "Location Updated"
                                self.refreshAlertMessage = "已更新为：\(placeToShow)"
                            } else {
                                self.refreshAlertTitle = "No Change"
                                self.refreshAlertMessage = "位置没有变化（仍为：\(placeToShow)）。"
                            }
                            self.showRefreshAlert = true
                        }

                        if let col = self.userCollectionUsed, let id = self.userDocID {
                            self.db.collection(col).document(id).setData(payload, merge: true) { err in
                                if let err = err {
                                    // 写库失败也要结束 loading，并提示
                                    self.isBusy = false
                                    self.activeLocationFetcher = nil
                                    self.refreshAlertTitle = "Save Failed"
                                    self.refreshAlertMessage = err.localizedDescription
                                    self.showRefreshAlert = true
                                } else {
                                    finishAndAlert()
                                }
                            }
                        } else {
                            // 尚未载入用户文档：仍然结束并提示
                            finishAndAlert()
                        }
                    }
                }
            }
        }
    }
    
}

// === One-shot 定位器 ===



// MARK: - Data & Actions
private extension AccountDetailView {
    func initialLoad() {
        switch ThemePreference(rawValue: themePreferenceRaw) ?? .auto {
        case .light: themeManager.selected = .day
        case .dark:  themeManager.selected = .night
        case .auto:  themeManager.selected = .system
        }
        themeManager.setSystemColorScheme(colorScheme)
        loadUser()
    }

    private var candidateUserCollections: [String] { [FSKeys.userPrimary, FSKeys.userAlt] }

    func loadUser() {
        guard let user = Auth.auth().currentUser else { return }
        isBusy = true
        errorMessage = nil

        queryByUID(user.uid) { doc, col in
            if let doc = doc, let col = col {
                applyUserDoc(doc, in: col); isBusy = false; return
            }
            if let em = user.email {
                self.email = em
                queryByEmail(em) { doc2, col2 in
                    if let doc2 = doc2, let col2 = col2 {
                        applyUserDoc(doc2, in: col2)
                    } else {
                        self.errorMessage = "No user profile found for \(em)."
                    }
                    isBusy = false
                }
            } else {
                self.errorMessage = "No user profile for current account."
                isBusy = false
            }
        }
    }

    private func queryByUID(_ uid: String, completion: @escaping (DocumentSnapshot?, String?) -> Void) {
        queryInCollections { ref in
            ref.whereField(FSKeys.uid, isEqualTo: uid).limit(to: 1)
        } completion: { doc, col in completion(doc, col) }
    }

    private func queryByEmail(_ email: String, completion: @escaping (DocumentSnapshot?, String?) -> Void) {
        queryInCollections { ref in
            ref.whereField(FSKeys.email, isEqualTo: email).limit(to: 1)
        } completion: { doc, col in completion(doc, col) }
    }

    private func queryInCollections(
        where makeQuery: @escaping (CollectionReference) -> Query,
        completion: @escaping (DocumentSnapshot?, String?) -> Void
    ) {
        func go(_ i: Int) {
            if i >= candidateUserCollections.count { completion(nil, nil); return }
            let col = candidateUserCollections[i]
            makeQuery(db.collection(col)).getDocuments { snap, _ in
                if let doc = snap?.documents.first { completion(doc, col) }
                else { go(i + 1) }
            }
        }
        go(0)
    }

    func applyUserDoc(_ doc: DocumentSnapshot, in collection: String) {
        self.userDocID = doc.documentID
        self.userCollectionUsed = collection
        let data = doc.data() ?? [:]

        self.nickname = data[FSKeys.nickname] as? String ?? ""

        // birthday：优先 Timestamp；其次你旧的 "birthDate" 字符串（yyyy-MM-dd / yyyy/M/d）
        if let ts = data[FSKeys.birthday] as? Timestamp {
            self.birthday = ts.dateValue()
        } else if let s = data["birthDate"] as? String {
            if let d = Self.parseDateYYYYMMDD.date(from: s) {
                self.birthday = d
            } else if let d2 = Self.parseDateYMDSlash.date(from: s) {
                self.birthday = d2
            }
        }

        // birthTime：首选新的 birthHour/birthMinute；兼容旧的 "birthTime" 字符串
        var hour: Int? = data["birthHour"] as? Int
        var minute: Int? = data["birthMinute"] as? Int

        if hour == nil || minute == nil {
            if let t = data[FSKeys.birthTime] as? String, let d = timeToDate(t) {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: d)
                hour = hour ?? comps.hour
                minute = minute ?? comps.minute
            }
        }
        self.birthTime = BirthTimeUtils.makeLocalTimeDate(hour: hour ?? 0, minute: minute ?? 0)

        self.birthPlace   = data[FSKeys.birthPlace] as? String ?? ""
        self.currentPlace = (data[FSKeys.currentPlace] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // --- 修正 currentPlace（保持你原逻辑） ---
        let needsFix: Bool = {
            if currentPlace.isEmpty { return true }
            if currentPlace.lowercased() == "unknown" { return true }
            if isCoordinateLikeString(currentPlace) { return true }
            return false
        }()

        if needsFix,
           let lat = data["currentLat"] as? CLLocationDegrees,
           let lng = data["currentLng"] as? CLLocationDegrees {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            getAddressFromCoordinate(coord) { resolved in
                guard let city = resolved, !city.isEmpty else { return }
                DispatchQueue.main.async {
                    self.currentPlace = city
                    self.saveField(FSKeys.currentPlace, value: city) { }
                }
            }
        }

        // --- Birth geo & timezone & raw time（保持你的兼容逻辑） ---
        if let lat = data["birthLat"] as? CLLocationDegrees { self.birthLat = lat }
        else if let lat = data["birth_lat"] as? CLLocationDegrees { self.birthLat = lat }

        if let lng = data["birthLng"] as? CLLocationDegrees { self.birthLng = lng }
        else if let lng = data["birth_lng"] as? CLLocationDegrees { self.birthLng = lng }

        if let tzMin = data["birthTimezoneOffsetMinutes"] as? Int {
            self.birthTimezoneOffsetMinutes = tzMin
        } else if let tzMin = data["timezoneOffsetMinutes"] as? Int {
            self.birthTimezoneOffsetMinutes = tzMin
        } else {
            self.birthTimezoneOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
        }

        if let raw = data["birthTimeRaw"] as? String {
            self.birthRawTimeString = raw
        } else if let raw = data["birth_raw"] as? String {
            self.birthRawTimeString = raw
        } else if let raw = data["birthTimeOriginal"] as? String {
            self.birthRawTimeString = raw
        } else {
            self.birthRawTimeString = nil
        }
    }


    func saveField<T>(_ key: String, value: T, completion: @escaping () -> Void) {
        guard let col = userCollectionUsed, let id = userDocID else {
            errorMessage = "User document not found."; return
        }
        isBusy = true
        db.collection(col).document(id).setData([key: value], merge: true) { err in
            isBusy = false
            if let err = err { errorMessage = err.localizedDescription } else { completion() }
        }
    }
    // 统一保存（向后兼容旧字段）
    // === Replace the old saveBirthFields with two explicit flows ===

    // 仅更新“生日”部分（日期），并与当前“时间”合并后写库
    // 仅更新“生日”（日期）
    func saveBirthDateOnly(newDate: Date, completion: @escaping () -> Void) {
        guard let col = userCollectionUsed, let id = userDocID else {
            errorMessage = "User document not found."; return
        }
        isBusy = true

        let dateStr = Self.parseDateYYYYMMDD.string(from: newDate) // "yyyy-MM-dd"

        let payload: [String: Any] = [
            FSKeys.birthday: Timestamp(date: newDate), // 正式字段（仅日期语义）
            "birth_date": dateStr,                     // 兼容旧字段
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection(col).document(id).setData(payload, merge: true) { err in
            self.isBusy = false
            if let err = err { self.errorMessage = err.localizedDescription; return }
            self.birthday = newDate   // 本地状态只改日期
            completion()
        }
    }

    // 仅更新时间（时:分）
    func saveBirthTimeOnly(newTime: Date, completion: @escaping () -> Void) {
        guard let col = userCollectionUsed, let id = userDocID else {
            errorMessage = "User document not found."; return
        }
        isBusy = true

        let (h, m) = BirthTimeUtils.hourMinute(from: newTime)

        // 兼容：写一个 "HH:mm" 字符串，方便旧逻辑或后端使用
        let time24: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            f.dateFormat = "HH:mm"
            return f.string(from: newTime)
        }()

        let timeRaw = BirthTimeUtils.displayFormatter.string(from: newTime).lowercased()

        let payload: [String: Any] = [
            "birthHour": h,
            "birthMinute": m,
            "birth_time": time24,            // 兼容旧字段
            "birthTimeRaw": timeRaw,         // 显示方便
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection(col).document(id).setData(payload, merge: true) { err in
            self.isBusy = false
            if let err = err { self.errorMessage = err.localizedDescription; return }
            // 本地状态只改“时间”
            self.birthTime = BirthTimeUtils.makeLocalTimeDate(hour: h, minute: m)
            self.birthRawTimeString = timeRaw
            completion()
        }
    }


    // 合并“日期部分”和“时间部分”
    func merge(datePart: Date, timePart: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Self.enUSPOSIX
        cal.timeZone = .current
        let d = cal.dateComponents([.year, .month, .day], from: datePart)
        let t = cal.dateComponents([.hour, .minute, .second], from: timePart)
        var comp = DateComponents()
        comp.year = d.year
        comp.month = d.month
        comp.day = d.day
        comp.hour = t.hour
        comp.minute = t.minute
        comp.second = t.second ?? 0
        return cal.date(from: comp) ?? datePart
    }

    func deleteAccount() { /* 原样 */
        guard let user = Auth.auth().currentUser else { return }
        let uid   = user.uid
        let email = user.email
        isBusy = true
        errorMessage = nil
        purgeAllUserData(uid: uid, email: email) { purgeErr in
            if let purgeErr = purgeErr {
                self.isBusy = false
                self.errorMessage = "Delete failed (data purge): \(purgeErr.localizedDescription)"
                return
            }
            deleteAuthAccount { authErr in
                self.isBusy = false
                if let e = authErr as NSError? {
                    if e.code == AuthErrorCode.requiresRecentLogin.rawValue {
                        self.errorMessage = "For security reasons, please re-authenticate and try again."
                    } else {
                        self.errorMessage = "Account deletion failed: \(e.localizedDescription)"
                    }
                    return
                }
                clearLocalStateAfterAccountDeletion()
                self.dismiss()
            }
        }
    }
    func purgeCollection(
            _ name: String,
            whereField field: String,
            equals value: Any,
            batchSize: Int = 400,
            completion: @escaping (Error?) -> Void
        ) {
            let q = db.collection(name).whereField(field, isEqualTo: value).limit(to: batchSize)
            q.getDocuments { snap, err in
                if let err = err { completion(err); return }
                let docs = snap?.documents ?? []
                if docs.isEmpty { completion(nil); return }

                let batch = self.db.batch()
                docs.forEach { batch.deleteDocument($0.reference) }
                batch.commit { err in
                    if let err = err { completion(err); return }
                    // 继续删下一页
                    self.purgeCollection(name, whereField: field, equals: value, batchSize: batchSize, completion: completion)
                }
            }
        }

        // --- 多条件并行（uid / email） ---
        func purgeCollectionByFields(
            _ name: String,
            fieldsAndValues: [(String, Any)],
            completion: @escaping (Error?) -> Void
        ) {
            let group = DispatchGroup()
            var firstErr: Error?

            for (f, v) in fieldsAndValues {
                group.enter()
                purgeCollection(name, whereField: f, equals: v) { err in
                    if let err = err, firstErr == nil { firstErr = err }
                    group.leave()
                }
            }
            group.notify(queue: .main) { completion(firstErr) }
        }
    func purgeAllUserData(uid: String, email: String?, completion: @escaping (Error?) -> Void) {
            let group = DispatchGroup()
            var firstErr: Error?

            func record(_ err: Error?) {
                if let err = err, firstErr == nil { firstErr = err }
            }

            // A) 用户档案：users / user
            let userCols = ["users", "user"]
            for col in userCols {
                group.enter()
                var pairs: [(String, Any)] = [("uid", uid)]
                if let em = email, !em.isEmpty { pairs.append(("email", em)) }
                purgeCollectionByFields(col, fieldsAndValues: pairs) { err in
                    record(err); group.leave()
                }
            }

            // B) 日推荐：兼容 4 种集合名
            let recCols = ["daily_recommendation", "daily recommendation", "daily_recommendations", "dailyRecommendations"]
            for col in recCols {
                // B1) 按字段删（uid / 兼容旧 email）
                group.enter()
                var pairs: [(String, Any)] = [("uid", uid)]
                if let em = email, !em.isEmpty { pairs.append(("email", em)) }
                purgeCollectionByFields(col, fieldsAndValues: pairs) { err in
                    record(err); group.leave()
                }

                // B2) 追加按文档ID前缀删（历史数据可能没有 uid 字段）
                group.enter()
                purgeByDocIDPrefix(col, prefix: uid + "_") { err in
                    record(err); group.leave()
                }
                if let em = email, !em.isEmpty {
                    group.enter()
                    purgeByDocIDPrefix(col, prefix: em + "_") { err in
                        record(err); group.leave()
                    }
                }
            }

            group.notify(queue: .main) { completion(firstErr) }
        }
    func purgeByDocIDPrefix(
            _ name: String,
            prefix: String,
            batchSize: Int = 400,
            completion: @escaping (Error?) -> Void
        ) {
            guard !prefix.isEmpty else { completion(nil); return }
            // Firestore 的“前缀查询”技巧： [prefix, prefix+\u{f8ff}]
            let start = prefix
            let end   = prefix + "\u{f8ff}"

            let q = db.collection(name)
                .whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: start)
                .whereField(FieldPath.documentID(), isLessThanOrEqualTo: end)
                .limit(to: batchSize)

            q.getDocuments { snap, err in
                if let err = err { completion(err); return }
                let docs = snap?.documents ?? []
                if docs.isEmpty { completion(nil); return }

                let batch = self.db.batch()
                docs.forEach { batch.deleteDocument($0.reference) }
                batch.commit { err in
                    if let err = err { completion(err); return }
                    // 继续删下一页
                    self.purgeByDocIDPrefix(name, prefix: prefix, batchSize: batchSize, completion: completion)
                }
            }
        }

    func deleteAuthAccount(completion: @escaping (Error?) -> Void) {
            guard let user = Auth.auth().currentUser else { completion(nil); return }
            user.delete { err in
                if let e = err as NSError?,
                   e.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    // 需要最近登录 → 自动 reauth 后重试
                    self.reauthenticateCurrentUser { reErr in
                        if let reErr = reErr { completion(reErr); return }
                        Auth.auth().currentUser?.delete(completion: completion)
                    }
                } else {
                    completion(err)
                }
            }
        }
    func reauthenticateCurrentUser(completion: @escaping (Error?) -> Void) {
            guard let user = Auth.auth().currentUser else { completion(nil); return }

            // 找到优先可用的 provider
            let providerIDs = user.providerData.map { $0.providerID } // e.g., "google.com", "apple.com", "password"
            guard let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
                completion(NSError(domain: "Aligna", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller."]))
                return
            }

            if providerIDs.contains("google.com") {
                reauthWithGoogle(presenting: rootVC, completion: completion)
            } else if providerIDs.contains("apple.com") {
                reauthWithApple(presenting: rootVC, completion: completion)
            } else if providerIDs.contains("password") {
                completion(NSError(domain: "Aligna", code: Int(AuthErrorCode.requiresRecentLogin.rawValue),
                                   userInfo: [NSLocalizedDescriptionKey: "Please sign in again with email & password, then delete."]))
            } else {
                completion(NSError(domain: "Aligna", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unsupported provider."]))
            }
        }
    func reauthWithGoogle(presenting rootVC: UIViewController, completion: @escaping (Error?) -> Void) {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                completion(NSError(domain: "Aligna", code: -3, userInfo: [NSLocalizedDescriptionKey: "Missing Firebase client ID."]))
                return
            }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            // 直接触发一次 Google 登录获取新 token
            GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
                if let error = error { completion(error); return }
                guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                    completion(NSError(domain: "Aligna", code: -4, userInfo: [NSLocalizedDescriptionKey: "Missing Google token."]))
                    return
                }
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                Auth.auth().currentUser?.reauthenticate(with: credential) { _, err in completion(err) }
            }
        }

        // --- Apple 重新验证 ---
        func reauthWithApple(presenting rootVC: UIViewController, completion: @escaping (Error?) -> Void) {
            let nonce = randomNonceString()
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [] // 只需要 token，不需要姓名/邮箱
            request.nonce = sha256(nonce)

            let coordinator = AppleReauthCoordinator(nonce: nonce) { token, err in
                if let err = err { completion(err); return }
                guard let token = token, let tokenStr = String(data: token, encoding: .utf8) else {
                    completion(NSError(domain: "Aligna", code: -5, userInfo: [NSLocalizedDescriptionKey: "Missing Apple token."]))
                    return
                }
                let credential = OAuthProvider.credential(providerID: .apple, idToken: tokenStr, rawNonce: nonce)
                Auth.auth().currentUser?.reauthenticate(with: credential) { _, err in completion(err) }
            }

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator
            coordinator.presentingWindow = rootVC.view.window
            controller.performRequests()
        }

    func clearLocalStateAfterAccountDeletion() {
        // 1) 清空本地标记（避免冷启动误判）
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "shouldOnboardAfterSignIn")
        UserDefaults.standard.set("",    forKey: "lastRecommendationDate")
        UserDefaults.standard.set("",    forKey: "lastCurrentPlaceUpdate")
        UserDefaults.standard.set("",    forKey: "todayFetchLock")

        // 2) Firebase sign out（双保险：就算 user.delete 成功，也显式登出一次）
        try? Auth.auth().signOut()

        // 3) 断开 Google 会话（防止“静默恢复”导致下次进入就是已登录态）
        GIDSignIn.sharedInstance.disconnect { error in
            if let e = error { print("⚠️ Google disconnect failed: \(e)") }
            else { print("✅ Google session disconnected") }
        }
    }
    
    // ===== Astrology glue (no extra conversion) =====

    // Merge local civil date & time (your existing helper already uses .current)
    private var mergedLocalBirthDateTime: Date {
        merge(datePart: birthday, timePart: birthTime)
    }

    // BirthInfo used for display (keeps the local civil time; NO second conversion)
    private var birthInfo: BirthInfo {
        BirthInfo(
            date: mergedLocalBirthDateTime,
            latitude: birthLat,
            longitude: birthLng,
            timezoneOffsetMinutes: birthTimezoneOffsetMinutes,
            originalUserInput: birthRawTimeString
        )
    }

    // For Sun/Moon we want the absolute instant: local time minus offset = UTC
    private var birthDateUTC: Date {
        mergedLocalBirthDateTime.addingTimeInterval(-Double(birthTimezoneOffsetMinutes * 60))
    }

    // Display birth time exactly as typed (if available); otherwise format in birth timezone
    private var birthTimeDisplay: String {
        AstroCalculator.displayBirthTime(birthInfo, format: "yyyy-MM-dd HH:mm")
    }
    private var birthTimeDisplayOnly: String {
        AstroCalculator.displayBirthTime(birthInfo, format: "h:mm a").lowercased()
    }

    // Sign texts
    private var sunSignText: String {
        AstroCalculator.sunSign(date: birthDateUTC).rawValue
    }
    private var moonSignText: String {
        AstroCalculator.moonSign(date: birthDateUTC).rawValue
    }
    private var ascSignText: String {
        AstroCalculator.ascendantSign(info: birthInfo).rawValue
    }

}

// MARK: - 固定英文展示 & 解析（工具函数，供其它处复用）
private extension AccountDetailView {
    func dateString(_ d: Date) -> String {
        Self.birthdayDisplayFormatter.string(from: d)
    }
    func timeString(_ d: Date) -> String {
        Self.birthTimeDisplayFormatter.string(from: d).lowercased()
    }
    func timeToDate(_ s: String) -> Date? {
        if let d = Self.parseTimeFormatter12.date(from: s) { return d }
        if let d = Self.parseTimeFormatter24.date(from: s) { return d }
        return nil
    }
}


// 放在文件尾部的协调器（保持你的实现）
final class AppleReauthCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let nonce: String
    var presentingWindow: UIWindow?
    let completion: (Data?, Error?) -> Void

    init(nonce: String, completion: @escaping (Data?, Error?) -> Void) {
        self.nonce = nonce
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentingWindow ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let token = credential.identityToken else {
            completion(nil, NSError(domain: "Aligna", code: -6, userInfo: [NSLocalizedDescriptionKey: "Apple credential missing token."]))
            return
        }
        completion(token, nil)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(nil, error)
    }
}

import Foundation
import CoreLocation



import Foundation
import CoreLocation

// 把出生“日期”和“时间”合并成一个 Date（按用户当前时区；若有需要可换成出生地时区）
extension OnboardingViewModel {
    var birthDateTime: Date {
        let cal = Calendar(identifier: .gregorian)
        let tz = TimeZone.current
        var dc = cal.dateComponents(in: tz, from: birth_date)
        let t  = cal.dateComponents(in: tz, from: birth_time)
        dc.hour = t.hour; dc.minute = t.minute; dc.second = t.second ?? 0
        return cal.date(from: DateComponents(timeZone: tz,
                                             year: dc.year, month: dc.month, day: dc.day,
                                             hour: dc.hour, minute: dc.minute, second: dc.second)) ?? birth_date
    }

    var sunSignText: String {
        AstroCalculator.sunSign(date: birthDateTime).rawValue
    }

    var moonSignText: String {
        AstroCalculator.moonSign(date: birthDateTime).rawValue
    }

    var ascendantText: String {
        guard let coord = birthCoordinate else { return "—" } // no coords → show dash
        let tzMinutes = TimeZone.current.secondsFromGMT(for: birthDateTime) / 60
        let info = BirthInfo(
            date: birthDateTime,
            latitude: coord.latitude,
            longitude: coord.longitude,
            timezoneOffsetMinutes: tzMinutes
        )
        return AstroCalculator.ascendantSign(info: info).rawValue
    }
}

import SwiftUI

struct ZodiacInlineRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let sunText: String
    let moonText: String
    let ascText: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                Text(sunText).italic()
            }

            Text("•")
                .foregroundColor(themeManager.descriptionText)

            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                Text(moonText).italic()
            }

            Text("•")
                .foregroundColor(themeManager.descriptionText)

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                Text(ascText.isEmpty || ascText == "—" ? "Unknown" : ascText)
                    .italic()
            }
        }
        .font(.callout)
        .foregroundColor(themeManager.primaryText)
        .frame(maxWidth: .infinity, alignment: .center)
        // no background / border — clean style like your old version
    }
}
/// 安全加载本地 Asset 的图片：
/// - 若找不到对应的图片名，不会崩溃，而是回退到系统占位图标。
struct SafeImage: View {
    let name: String
    let renderingMode: Image.TemplateRenderingMode?
    let contentMode: ContentMode

    init(
        name: String,
        renderingMode: Image.TemplateRenderingMode? = .template,
        contentMode: ContentMode = .fit
    ) {
        self.name = name
        self.renderingMode = renderingMode
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .renderingMode(renderingMode)
                    .resizable()
                    .aspectRatio(contentMode: contentMode == .fit ? .fit : .fill)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: contentMode == .fit ? .fit : .fill)
                    .opacity(0.5)
            }
        }
        .accessibilityLabel(Text(name.isEmpty ? "image" : name))
    }
}


struct CollapsibleSection<Content: View>: View {
    let title: String
    let content: Content
    let width: CGFloat
    @State private var isExpanded = false
    
    init(title: String, width: CGFloat, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self.width = width
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .frame(width: width * 0.8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut, value: isExpanded)
    }
}
import Foundation

// 用于在界面上显示 12 小时制的时间（本地时区）
// === Only store/display hour & minute to avoid timezone shifts ===
enum BirthTimeUtils {
    /// 本地时区的时间显示格式（系统 12/24 小时会自动匹配）
    static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeStyle = .short
        f.dateStyle = .none
        f.timeZone = .current
        return f
    }()

    /// 从 Date 抽取小时/分钟（按本地时区）
    static func hourMinute(from date: Date) -> (hour: Int, minute: Int) {
        let cal = Calendar.current
        return (cal.component(.hour, from: date), cal.component(.minute, from: date))
    }

    /// 用小时+分钟拼一个固定日期（仅用于显示/计算，避免跨日/跨时区偏移）
    static func makeLocalTimeDate(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = .current
        comps.year = 2001; comps.month = 1; comps.day = 1
        comps.hour = hour; comps.minute = minute
        return comps.date ?? Date()
    }
}


import CryptoKit

// 生成随机字符串 nonce
func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: Array<Character> =
    Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    
    while remainingLength > 0 {
        let randoms: [UInt8] = (0..<16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
        }
        
        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    
    return result
}

// 对 nonce 做 SHA256 哈希
func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

// MARK: - placeholder 修饰符
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

func timeToDateFlexible(_ str: String) -> Date? {
    let fmts = ["HH:mm", "H:mm", "hh:mm a", "h:mm a"]
    for f in fmts {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale   = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0) // 与生日一致走 GMT，避免跨区跑偏
        df.dateFormat = f
        if let d = df.date(from: str) {
            // 仅取“时/分”，拼到一个稳定日期（2001-01-01）
            let comps = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: d)
            var only = DateComponents()
            only.year = 2001; only.month = 1; only.day = 1
            only.hour = comps.hour; only.minute = comps.minute
            return Calendar(identifier: .gregorian).date(from: only)
        }
    }
    return nil
}




// Hex Color 支持
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

// MARK: - Focus Glow (文本框获得焦点时高亮+发光)
struct FocusGlow: ViewModifier {
    var active: Bool
    var color: Color = .white
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            // 边框描边（焦点时加粗）
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(active ? 0.95 : 0.28),
                            lineWidth: active ? lineWidth : 1)
            )
            // 柔和发光（焦点时出现）
            .shadow(color: color.opacity(active ? 0.55 : 0.0), radius: active ? 10 : 0, x: 0, y: 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: active)
    }
}

extension View {
    /// 为可输入控件添加焦点高亮效果
    func focusGlow(active: Bool,
                   color: Color = .white,
                   lineWidth: CGFloat = 2,
                   cornerRadius: CGFloat = 14) -> some View {
        modifier(FocusGlow(active: active, color: color, lineWidth: lineWidth, cornerRadius: cornerRadius))
    }
}
// 固定“夜间”文字调色板：用在 Onboarding / 登录注册等必须恒为夜色的页面
extension ThemeManager {
    var fixedNightTextPrimary: Color   { Color(hex: "#E6D7C3") } // 主要文字
    var fixedNightTextSecondary: Color { Color(hex: "#B8C5D6") } // 次要说明
    var fixedNightTextTertiary: Color  { Color(hex: "#A8B5C8") } // 更淡的正文
}



#Preview {
    FirstPageView()
        .environmentObject(StarAnimationManager())
        .environmentObject(ThemeManager())
        .environmentObject(OnboardingViewModel())
        .environmentObject(SoundPlayer())
        
}
