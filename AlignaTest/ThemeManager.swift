import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    
    // 保留四个选项，.system 与 .autoClock 都按时段
    enum ThemeOption: String, CaseIterable {
        case system, day, night, autoClock
    }
    
    // 用于读取 AccountDetailView 用 @AppStorage("themePreference") 存的值
    private static let preferenceKey = "themePreference"
    
    // === 对外暴露（与原工程保持一致）===
    @Published private(set) var isNight: Bool = false
    
    // MARK: – 文字与强调色（按你提供的映射）
    // 全局前景（如通用标题/按钮文字）：夜 #E6D9BD；日 #8F643E
    var foregroundColor: Color {
        isNight ? Color(hex: "#E6D9BD") : Color(hex: "#8F643E")
    }
    
    // 图标/高亮：夜 #D4A574；日 #8F643E
    var accent: Color {
        isNight ? Color(hex: "#D4A574") : Color(hex: "#8F643E")
    }
    
    // 大型水印文字：夜 #4A5A9E(40%)；日 secondary
    var watermark: Color {
        isNight ? Color(hex: "#4A5A9E").opacity(0.4)
                : Color(hex: "8B4513").opacity(0.6)
    }
    
    // 主标题（例如 “Green Sanctuary”）
    // 夜 #E6D7C3；日 #8F643E
    var primaryText: Color {
        isNight ? Color(hex: "#E6D7C3") : Color(hex: "#8B4513")
    }
    
    // 副标题/简短描述：夜 #B8C5D6；日 secondary
    var descriptionText: Color {
        isNight ? Color(hex: "#B8C5D6") : Color(hex: "#8B4513")
    }
    
    // 正文/长段落：夜 #A8B5C8；日 primary
    var bodyText: Color {
        isNight ? Color(hex: "#A8B5C8") : Color.primary
    }
    
    var placeIcon: Color {
        isNight ? Color.accentColor : Color(hex: "#CD853F")
    }
    
    var placeIconText: Color {
        isNight ? Color.accentColor : Color(hex: "#7A5A3A")
    }
    
    // 全局强制：任何选项都返回 .dark/.light（不再随系统）
    var preferredColorScheme: ColorScheme? {
        isNight ? .dark : .light
    }
    
    // card/panel behind the calendar
    var panelFill: Color {
        isNight ? Color.white.opacity(0.04)
                : Color.black.opacity(0.06)
    }
    var panelStrokeHi: Color {
        isNight ? Color.white.opacity(0.12)
                : Color.black.opacity(0.18)
    }
    var panelStrokeLo: Color {
        isNight ? Color.white.opacity(0.04)
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
    
    // MARK: - 生命周期
    init() {
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
            case "system", "day", "night", "autoClock":
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
        /* no-op: 强制走自定义主题 */
    }
    
    // App 回前台等场景主动刷新
    func appBecameActive() {
        recomputeNight()
    }
    
    // MARK: - 依据选择计算 isNight
    private func recomputeNight() {
        switch selected {
        case .day:
            isNight = false
        case .night:
            isNight = true
        case .system, .autoClock:
            isNight = Self.isNightByClock()
        }
        // preferredColorScheme 由 isNight 推导
    }
    
    // MARK: - 定时器：在“按时段”模式下启用，边界时刻自动切换
    private func reconfigureTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        
        guard selected == .system || selected == .autoClock else { return }
        
        // 60 秒刷新，更贴近 08:00 / 20:00 边界切换
        timerCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.recomputeNight()
            }
    }
    
    // 08:00–19:59 白天；20:00–次日 07:59 夜间
    private static func isNightByClock() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 8 || hour >= 20
    }
}
