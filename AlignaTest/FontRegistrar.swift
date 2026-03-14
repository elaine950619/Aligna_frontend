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
        "Merriweather-VariableFont_opsz,wdth,wght",
        "Merriweather-Italic-VariableFont_opsz,wdth,wght",
        "Gloock-Regular",
        "CormorantGaramond-Bold",
        "CormorantGaramond-SemiBold",
        "PlayfairDisplay-VariableFont_wght",
        "PlayfairDisplay-Italic-VariableFont_wght",
        "PlayfairDisplay-Bold",
        "Inter-VariableFont_opsz,wght"
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
