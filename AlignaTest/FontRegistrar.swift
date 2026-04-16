import CoreText
import UIKit

enum FontRegistrar {
    private static let expectedPostScriptNames: [String] = [
        "Merriweather-Regular",
        "Merriweather-Italic",
        "Merriweather-Light",
        "Merriweather-LightItalic",
        "Merriweather-Bold",
        "Merriweather-Black",
        "Gloock-Regular",
        "CormorantGaramond-Bold",
        "CormorantGaramond-SemiBold",
        "PlayfairDisplay-Bold",
        // 思源宋体（主文本/引导语）
        "SourceHanSerifSCVF-ExtraLight",
        // 思源黑体（UI/按钮/设置）
        "SourceHanSansSCVF-Regular",
        "SourceHanSansSCVF-Light",
        "SourceHanSansSCVF-Medium",
        // 霞鹜文楷（标题/mantra 强化）
        "LXGWWenKaiTC-Regular",
        "LXGWWenKaiTC-Light",
        "LXGWWenKaiTC-Bold",
        // 展库文艺体
        "zcoolwenyiti",
        // 爱点峰雅黑
        "AidianFengYaHei"
    ]

    static func registerAllFonts() {
        // If Info.plist UIAppFonts already registered everything, skip to avoid duplicate GSFont logs.
        let allAvailable = expectedPostScriptNames.allSatisfy { UIFont(name: $0, size: 12) != nil }
        if allAvailable {
            return
        }

        let bundle = Bundle.main
        let fontURLs =
            (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []) +
            (bundle.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? []) +
            (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []) +
            (bundle.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [])

        let uniqueURLs = Array(Set(fontURLs))
        guard !uniqueURLs.isEmpty else {
            print("⚠️ No font files found in bundle (checked Fonts/ and root).")
            return
        }

        for url in uniqueURLs {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }

        #if DEBUG
        for name in expectedPostScriptNames where UIFont(name: name, size: 12) == nil {
            print("⚠️ Missing registered font: \(name)")
        }
        #endif
    }
}
