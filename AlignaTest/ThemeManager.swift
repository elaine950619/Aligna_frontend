import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var isNight: Bool = false

    var foregroundColor: Color {
        isNight ? Color(hex: "#E6D9BD") : Color(hex: "#8F643E")
    }

    init() {
        updateTheme()
    }

    func updateTheme() {
        let hour = Calendar.current.component(.hour, from: Date())
        isNight = hour < 7 || hour >= 22 
    }
    
//    // MARK: – Backgrounds
//    var background: Color {
//        isNight
//            ? Color(hex: "#1a1a2e")  // top of your night gradient
//            : Color(hex: "#E6D9BD")
//    }

    // MARK: – Accent (icons, highlights)
    var accent: Color {
        isNight
            ? Color(hex: "#D4A574")
            : Color(hex: "#8F643E")
    }

    // MARK: – Watermark / big “Place” text
    var watermark: Color {
        isNight
            ? Color(hex: "#4A5A9E").opacity(0.4)
            : Color.secondary
    }

    // MARK: – Main title (“Green Sanctuary”)
    var primaryText: Color {
        isNight
            ? Color(hex: "#E6D7C3")
            : Color(hex: "#8F643E")
    }

    // MARK: – Short description under title
    var descriptionText: Color {
        isNight
            ? Color(hex: "#B8C5D6")
            : Color.secondary
    }

    // MARK: – Body / long paragraph
    var bodyText: Color {
        isNight
            ? Color(hex: "#A8B5C8")
            : Color.primary
    }
}
