import Foundation
import UIKit

// MARK: - Top VC 获取（用于 withPresenting 预检）
extension UIApplication {
    var topViewController_aligna: UIViewController? {
        guard let window = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// MARK: - Google Sign-In 诊断 & 预检
enum GoogleSignInDiagnostics {
    struct Result {
        var hasPlist = false
        var reversedClientID: String = "N/A"
        var urlSchemes: [String] = []
        var schemeOK = false
        var hasPresenter = false
    }

    /// 读取 GoogleService-Info.plist 的 REVERSED_CLIENT_ID
    private static func readReversedClientID() -> String? {
        guard
            let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
            let reversed = dict["REVERSED_CLIENT_ID"] as? String,
            !reversed.isEmpty
        else { return nil }
        return reversed
    }

    /// 从 Info.plist 读取已注册的 URL Schemes
    private static func registeredSchemes() -> [String] {
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return urlTypes.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
    }

    /// 运行诊断：打印关键配置
    static func run(context: String = "App") -> Result {
        var r = Result()

        print("🔎 [GSID] Context=\(context) — Running Google Sign-In diagnostics...")

        if let reversed = readReversedClientID() {
            r.hasPlist = true
            r.reversedClientID = reversed
            print("🔎 [GSID] REVERSED_CLIENT_ID =", reversed)
        } else {
            print("❌ [GSID] 未找到或无法读取 GoogleService-Info.plist 的 REVERSED_CLIENT_ID")
        }

        r.urlSchemes = registeredSchemes()
        print("🔎 [GSID] URL Schemes =", r.urlSchemes)

        if r.reversedClientID != "N/A", r.urlSchemes.contains(r.reversedClientID) {
            r.schemeOK = true
            print("✅ [GSID] URL Types 已正确包含 REVERSED_CLIENT_ID")
        } else {
            print("❌ [GSID] URL Types 未包含 REVERSED_CLIENT_ID（Xcode > TARGETS(App) > Info > URL Types）")
        }

        r.hasPresenter = (UIApplication.shared.topViewController_aligna != nil)
        if r.hasPresenter {
            print("✅ [GSID] 已找到可见的呈现控制器（withPresenting 可用）")
        } else {
            print("❌ [GSID] 未找到可见呈现控制器（请在可见页面触发登录，或检查窗口层级）")
        }

        return r
    }

    /// 在点击“Continue with Google”之前做的一键预检；返回 false 时建议阻止继续登录并弹提示
    @discardableResult
    static func preflight(context: String = "RegisterPageView") -> Bool {
        let r = run(context: context)
        var ok = true
        if !r.hasPlist { ok = false }
        if !r.schemeOK { ok = false }
        if !r.hasPresenter { ok = false }
        if ok {
            print("✅ [GSID] Preflight OK — 可以安全调用 GIDSignIn.sharedInstance.signIn(withPresenting:)")
        } else {
            print("❌ [GSID] Preflight 未通过 — 请先修正以上 ❌ 项再尝试登录")
        }
        return ok
    }
}
