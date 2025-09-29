import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {

    // 保留四个选项，.system 与 .autoClock 都按时段
    enum ThemeOption: String, CaseIterable { case system, day, night, autoClock }

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
        isNight ? Color(hex: "#4A5A9E").opacity(0.4) : Color.secondary
    }

    // 主标题（例如 “Green Sanctuary”）
    // 夜 #E6D7C3；日 #8F643E
    var primaryText: Color {
        isNight ? Color(hex: "#E6D7C3") : Color(hex: "#8F643E")
    }

    // 副标题/简短描述：夜 #B8C5D6；日 secondary
    var descriptionText: Color {
        isNight ? Color(hex: "#B8C5D6") : Color.secondary
    }

    // 正文/长段落：夜 #A8B5C8；日 primary
    var bodyText: Color {
        isNight ? Color(hex: "#A8B5C8") : Color.primary
    }

    // 全局强制：任何选项都返回 .dark/.light（不再随系统）
    var preferredColorScheme: ColorScheme? {
        isNight ? .dark : .light
    }

    // 当前选择
    @Published var selected: ThemeOption = .system {
        didSet {
            recomputeNight()
            reconfigureTimer()
        }
    }

    // 内部
    private var timerCancellable: AnyCancellable?

    // MARK: - 生命周期
    init() {
        recomputeNight()
        reconfigureTimer()
    }

    deinit { timerCancellable?.cancel() }

    // 与系统外观同步：为兼容旧代码保留，但现在不再影响主题
    func setSystemColorScheme(_ scheme: ColorScheme) { /* no-op: 强制走自定义主题 */ }

    // App 回前台等场景主动刷新
    func appBecameActive() { recomputeNight() }

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
            .sink { [weak self] _ in self?.recomputeNight() }
    }

    // 08:00–19:59 白天；20:00–次日 07:59 夜间
    private static func isNightByClock() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 8 || hour >= 20
    }
}
