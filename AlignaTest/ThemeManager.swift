import SwiftUI
import Combine
import CoreLocation

@MainActor
final class ThemeManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // 保留四个选项，.system 与 .autoClock 都按时段；rain/vitality/love 为独立主题
    enum ThemeOption: String, CaseIterable {
        case system, day, night, autoClock, rain, vitality, love
    }
    
    // 用于读取 AccountDetailView 用 @AppStorage("themePreference") 存的值
    private static let preferenceKey = "themePreference"
    
    // === 对外暴露（与原工程保持一致）===
    @Published private(set) var isNight: Bool = false
    @Published private(set) var isRain: Bool = false
    /// 雨天主题下是否处于夜间时段（用于背景深浅切换）
    @Published private(set) var rainIsDark: Bool = false
    @Published private(set) var isVitality: Bool = false
    @Published private(set) var isLove: Bool = false
    
    // MARK: – 文字与强调色（按你提供的映射）
    // 全局前景（如通用标题/按钮文字）：夜 #E6D9BD；日 #8F643E；雨 #C8DCE8；绿 #2D5A3A；粉 #C05070
    var foregroundColor: Color {
        if isLove     { return Color(hex: "#C05070") }
        if isVitality { return Color(hex: "#2D5A3A") }
        if isRain     { return Color(hex: "#C8DCE8") }
        return isNight ? Color(hex: "#E6D9BD") : Color(hex: "#8F643E")
    }
    
    // 图标/高亮：夜 #D4A574；日 #8F643E；雨 #7EB8D4；绿 #3A9457；粉 #E8607A
    var accent: Color {
        if isLove     { return Color(hex: "#E8607A") }
        if isVitality { return Color(hex: "#3A9457") }
        if isRain     { return Color(hex: "#7EB8D4") }
        return isNight ? Color(hex: "#D4A574") : Color(hex: "#8F643E")
    }
    
    // 大型水印文字：夜 #4A5A9E(40%)；日 secondary；雨 #4A6B8A(50%)；绿 #3A7A4E(35%)；粉 #C05070(25%)
    var watermark: Color {
        if isLove     { return Color(hex: "#C05070").opacity(0.25) }
        if isVitality { return Color(hex: "#3A7A4E").opacity(0.35) }
        if isRain     { return Color(hex: "#4A6B8A").opacity(0.50) }
        return isNight ? Color(hex: "#4A5A9E").opacity(0.4)
                       : Color(hex: "#8B4513").opacity(0.6)
    }
    
    // 主标题：夜 #E6D7C3；日 #8B4513；雨 #D6E4F0；绿 #1E4A2C；粉 #7A2A45
    var primaryText: Color {
        if isLove     { return Color(hex: "#7A2A45") }
        if isVitality { return Color(hex: "#1E4A2C") }
        if isRain     { return Color(hex: "#D6E4F0") }
        return isNight ? Color(hex: "#E6D7C3") : Color(hex: "#8B4513")
    }
    
    // 副标题：夜 #B8C5D6；日 secondary；雨 #8FA8C0；绿 #4A7C5A；粉 #A0526A
    var descriptionText: Color {
        if isLove     { return Color(hex: "#A0526A") }
        if isVitality { return Color(hex: "#4A7C5A") }
        if isRain     { return Color(hex: "#8FA8C0") }
        return isNight ? Color(hex: "#B8C5D6") : Color(hex: "#8B4513")
    }
    
    // 正文：夜 #A8B5C8；日 primary；雨 #8FA8C0；绿 #4A7C5A；粉 #A0526A
    var bodyText: Color {
        if isLove     { return Color(hex: "#A0526A") }
        if isVitality { return Color(hex: "#4A7C5A") }
        if isRain     { return Color(hex: "#8FA8C0") }
        return isNight ? Color(hex: "#A8B5C8") : Color.primary
    }
    
    var placeIcon: Color {
        if isLove     { return Color(hex: "#E8607A") }
        if isVitality { return Color(hex: "#3A9457") }
        if isRain     { return Color(hex: "#7EB8D4") }
        return isNight ? Color.accentColor : Color(hex: "#CD853F")
    }
    
    var placeIconText: Color {
        if isLove     { return Color(hex: "#C05070") }
        if isVitality { return Color(hex: "#2D6642") }
        if isRain     { return Color(hex: "#A8C8E0") }
        return isNight ? Color.accentColor : Color(hex: "#7A5A3A")
    }
    
    /// Text/tint color for content placed ON TOP of a `primaryText`-colored background
    /// (e.g. filled action buttons whose background = primaryText).
    var buttonForegroundOnPrimary: Color {
        if isLove     { return Color.white }             // white on rose-red button
        if isVitality { return Color.white }             // white on deep-green button
        if isRain     { return Color(hex: "#1A2636") }   // dark ink on rain-blue button
        return isNight ? Color.black : Color.white
    }

    // 全局强制：任何选项都返回 .dark/.light（不再随系统）
    var preferredColorScheme: ColorScheme? {
        (isNight || isRain) ? .dark : .light
    }
    
    // card/panel behind the calendar
    var panelFill: Color {
        if isLove { return Color.white.opacity(0.55) }
        return isNight ? Color.white.opacity(0.04)
                       : Color.black.opacity(0.06)
    }
    var panelStrokeHi: Color {
        if isLove { return Color(hex: "#D4899A").opacity(0.30) }
        return isNight ? Color.white.opacity(0.12)
                       : Color.black.opacity(0.18)
    }
    var panelStrokeLo: Color {
        if isLove { return Color(hex: "#D4899A").opacity(0.12) }
        return isNight ? Color.white.opacity(0.04)
                       : Color.black.opacity(0.07)
    }
    
    // 当前选择
    @Published var selected: ThemeOption = .system {
        didSet {
            // 注意：这里只“读”原来的 "light/dark/auto"，不反写这个 key，
            // 避免和 AccountDetailView 的 ThemePreference(rawValue:) 冲突。
            // 如果以后你想只用 ThemeOption 存储，可以再统一迁移。
            recomputeNight()
            reconfigureTimer()
        }
    }
    
    // 内部
    private var timerCancellable: AnyCancellable?
    private let locationManager = CLLocationManager()
    private var solarCoordinate: CLLocationCoordinate2D?
    
    // MARK: - 生命周期
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        refreshSolarLocationIfAvailable()

        // 从 UserDefaults 读取 AccountDetailView 里存的 themePreference
        if let raw = UserDefaults.standard.string(forKey: Self.preferenceKey) {
            // 兼容你现在文件里的 ThemePreference: light/dark/auto
            switch raw {
            case "light":
                selected = .day
            case "dark":
                selected = .night
            case "auto":
                // UI 上叫 System，实际上就是按时段自动
                selected = .system
            // 兼容未来如果你改成直接存 ThemeOption 的 rawValue
            case "system", "day", "night", "autoClock", "rain", "vitality", "love":
                selected = ThemeOption(rawValue: raw) ?? .system
            default:
                selected = .system
            }
        } else {
            // 从未选择过时，默认按时段
            selected = .system
        }
        
        // 根据当前选择算出 isNight，并配置定时器
        recomputeNight()
        reconfigureTimer()
    }
    
    deinit {
        timerCancellable?.cancel()
    }
    
    // 与系统外观同步：为兼容旧代码保留，但现在不再影响主题
    func setSystemColorScheme(_ scheme: ColorScheme) {
        if selected == .system || selected == .autoClock {
            recomputeNight()
        }
    }
    
    // App 回前台等场景主动刷新
    func appBecameActive() {
        refreshSolarLocationIfAvailable()
        recomputeNight()
    }
    
    // MARK: - 依据选择计算 isNight / isRain / isVitality
    private func recomputeNight() {
        switch selected {
        case .day:
            isRain     = false
            isVitality = false
            isLove     = false
            isNight    = false
            rainIsDark = false
        case .night:
            isRain     = false
            isVitality = false
            isLove     = false
            isNight    = true
            rainIsDark = false
        case .rain:
            isRain     = true
            isVitality = false
            isLove     = false
            isNight    = true   // 使用深色基底
            rainIsDark = Self.isNight(at: Date(), coordinate: solarCoordinate)
        case .vitality:
            isRain     = false
            isVitality = true
            isLove     = false
            isNight    = false  // 浅色背景
            rainIsDark = false
        case .love:
            isRain     = false
            isVitality = false
            isLove     = true
            isNight    = false  // 浅色背景
            rainIsDark = false
        case .system, .autoClock:
            isRain     = false
            isVitality = false
            isLove     = false
            rainIsDark = false
            isNight    = Self.isNight(at: Date(), coordinate: solarCoordinate)
        }
        // preferredColorScheme 由 isNight / isRain 推导
    }
    
    // MARK: - 定时器：在“按时段”模式下启用，边界时刻自动切换
    private func reconfigureTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        
        guard selected == .system || selected == .autoClock || selected == .rain || selected == .vitality || selected == .love else { return }
        
        // 5 分钟刷新一次；进入前台时也会主动刷新位置和日夜状态。
        timerCancellable = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshSolarLocationIfAvailable()
                self?.recomputeNight()
            }
    }
    
    private func refreshSolarLocationIfAvailable() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let current = locationManager.location?.coordinate {
                solarCoordinate = current
            } else {
                locationManager.requestLocation()
            }
        default:
            solarCoordinate = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            refreshSolarLocationIfAvailable()
            recomputeNight()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            solarCoordinate = coordinate
            recomputeNight()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            recomputeNight()
        }
    }

    private static func isNight(at date: Date, coordinate: CLLocationCoordinate2D?) -> Bool {
        if let coordinate,
           let events = solarEvents(for: date, coordinate: coordinate) {
            if events.sunrise >= events.sunset {
                return isNightByClock()
            }
            return date < events.sunrise || date >= events.sunset
        }
        return isNightByClock()
    }

    // 回退规则：拿不到位置时仍按时钟自动切换。
    private static func isNightByClock() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 8 || hour >= 20
    }

    private static func solarEvents(
        for date: Date,
        coordinate: CLLocationCoordinate2D
    ) -> (sunrise: Date, sunset: Date)? {
        guard let sunriseLocal = solarTimeLocal(for: date, coordinate: coordinate, isSunrise: true),
              let sunsetLocal = solarTimeLocal(for: date, coordinate: coordinate, isSunrise: false) else {
            return nil
        }
        return (sunriseLocal, sunsetLocal)
    }

    private static func solarTimeLocal(
        for date: Date,
        coordinate: CLLocationCoordinate2D,
        isSunrise: Bool
    ) -> Date? {
        let zenith = 90.833
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        // NOAA formula expects west longitudes as positive hours.
        let longitudeHour = (-coordinate.longitude) / 15.0
        let approx = Double(dayOfYear) + ((isSunrise ? 6.0 : 18.0) - longitudeHour) / 24.0

        let meanAnomaly = (0.9856 * approx) - 3.289
        var trueLongitude = meanAnomaly
            + (1.916 * sin(meanAnomaly.degreesToRadians))
            + (0.020 * sin(2 * meanAnomaly.degreesToRadians))
            + 282.634
        trueLongitude = normalizedDegrees(trueLongitude)

        var rightAscension = atan(0.91764 * tan(trueLongitude.degreesToRadians)).radiansToDegrees
        rightAscension = normalizedDegrees(rightAscension)

        let trueQuadrant = floor(trueLongitude / 90.0) * 90.0
        let ascQuadrant = floor(rightAscension / 90.0) * 90.0
        rightAscension = (rightAscension + trueQuadrant - ascQuadrant) / 15.0

        let sinDeclination = 0.39782 * sin(trueLongitude.degreesToRadians)
        let cosDeclination = cos(asin(sinDeclination))
        let cosHourAngle =
            (cos(zenith.degreesToRadians) - (sinDeclination * sin(coordinate.latitude.degreesToRadians))) /
            (cosDeclination * cos(coordinate.latitude.degreesToRadians))

        guard cosHourAngle >= -1.0, cosHourAngle <= 1.0 else { return nil }

        let hourAngleDegrees: Double
        if isSunrise {
            hourAngleDegrees = 360.0 - acos(cosHourAngle).radiansToDegrees
        } else {
            hourAngleDegrees = acos(cosHourAngle).radiansToDegrees
        }

        let localHour = hourAngleDegrees / 15.0
        let localMeanTime = localHour + rightAscension - (0.06571 * approx) - 6.622
        let utcHour = normalizedHours(localMeanTime - longitudeHour)

        let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600.0
        let localTimeHour = normalizedHours(utcHour + timeZoneOffset)

        let startOfDay = calendar.startOfDay(for: date)
        return startOfDay.addingTimeInterval(localTimeHour * 3600.0)
    }

    private static func normalizedDegrees(_ value: Double) -> Double {
        let mod = value.truncatingRemainder(dividingBy: 360.0)
        return mod >= 0 ? mod : mod + 360.0
    }

    private static func normalizedHours(_ value: Double) -> Double {
        let mod = value.truncatingRemainder(dividingBy: 24.0)
        return mod >= 0 ? mod : mod + 24.0
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180.0 }
    var radiansToDegrees: Double { self * 180.0 / .pi }
}
