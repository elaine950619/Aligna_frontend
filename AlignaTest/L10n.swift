import Foundation

// MARK: - Category Display Names
// Maps the English API key (used in recommendations dict) to a localized display name.
func categoryDisplayName(for key: String) -> String {
    switch key.lowercased() {
    case "place":        return String(localized: "category.place")
    case "color":        return String(localized: "category.color")
    case "sound":        return String(localized: "category.sound")
    case "scent":        return String(localized: "category.scent")
    case "activity":     return String(localized: "category.activity")
    case "relationship": return String(localized: "category.relationship")
    case "career":       return String(localized: "category.career")
    case "gemstone":     return String(localized: "category.gemstone")
    default:             return key
    }
}

// MARK: - Moon Phase Display Names
// Maps the English moon phase string (returned by moonPhaseLabel()) to a localized name.
func moonPhaseDisplayName(for phase: String) -> String {
    switch phase {
    case "New Moon":        return String(localized: "moon_phase.new_moon")
    case "Waxing Crescent": return String(localized: "moon_phase.waxing_crescent")
    case "First Quarter":   return String(localized: "moon_phase.first_quarter")
    case "Waxing Gibbous":  return String(localized: "moon_phase.waxing_gibbous")
    case "Full Moon":       return String(localized: "moon_phase.full_moon")
    case "Waning Gibbous":  return String(localized: "moon_phase.waning_gibbous")
    case "Third Quarter":   return String(localized: "moon_phase.third_quarter")
    case "Waning Crescent": return String(localized: "moon_phase.waning_crescent")
    default:                return phase
    }
}
