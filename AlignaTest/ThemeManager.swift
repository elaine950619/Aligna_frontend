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
        isNight = hour < 7 
    }
}
