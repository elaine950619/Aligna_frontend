import Foundation

func currentRecommendationLanguageCode() -> String {
    let storedLanguage = (UserDefaults.standard.string(forKey: "appLanguage") ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    if storedLanguage.hasPrefix("zh") {
        return "zh-Hans"
    }

    let preferredLanguage = (Locale.preferredLanguages.first ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    if preferredLanguage.hasPrefix("zh") {
        return "zh-Hans"
    }

    return "en"
}

func attachRecommendationLanguage(to payload: inout [String: Any]) {
    payload["language_code"] = currentRecommendationLanguageCode()
    payload["locale_identifier"] = Locale.current.identifier
}

// MARK: - Seeded Focus Display Names
// Maps the English focus name key to a localized display name and description.
// The raw `name` (e.g. "daily") is kept as-is for the backend focus_tag payload.
func focusLocalizedName(for nameKey: String) -> String {
    switch nameKey.lowercased() {
    case "daily":       return String(localized: "focus.name.daily")
    case "fertility":   return String(localized: "focus.name.fertility")
    case "connection":  return String(localized: "focus.name.connection")
    case "transition":  return String(localized: "focus.name.transition")
    case "caregiving":  return String(localized: "focus.name.caregiving")
    case "recovery":    return String(localized: "focus.name.recovery")
    case "clarity":     return String(localized: "focus.name.clarity")
    case "grief":       return String(localized: "focus.name.grief")
    default:            return nameKey
    }
}

func focusLocalizedDescription(for nameKey: String, fallback: String) -> String {
    switch nameKey.lowercased() {
    case "daily":       return String(localized: "focus.desc.daily")
    case "fertility":   return String(localized: "focus.desc.fertility")
    case "connection":  return String(localized: "focus.desc.connection")
    case "transition":  return String(localized: "focus.desc.transition")
    case "caregiving":  return String(localized: "focus.desc.caregiving")
    case "recovery":    return String(localized: "focus.desc.recovery")
    case "clarity":     return String(localized: "focus.desc.clarity")
    case "grief":       return String(localized: "focus.desc.grief")
    default:            return fallback
    }
}

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

// MARK: - Zodiac Sign Display Names
// Maps English zodiac sign names (as returned by AstroCalculator rawValues and server responses)
// to localized display names. Input is case-insensitive.
func zodiacLocalizedName(for sign: String) -> String {
    switch sign.lowercased() {
    case "aries":       return String(localized: "zodiac.aries")
    case "taurus":      return String(localized: "zodiac.taurus")
    case "gemini":      return String(localized: "zodiac.gemini")
    case "cancer":      return String(localized: "zodiac.cancer")
    case "leo":         return String(localized: "zodiac.leo")
    case "virgo":       return String(localized: "zodiac.virgo")
    case "libra":       return String(localized: "zodiac.libra")
    case "scorpio":     return String(localized: "zodiac.scorpio")
    case "sagittarius": return String(localized: "zodiac.sagittarius")
    case "capricorn":   return String(localized: "zodiac.capricorn")
    case "aquarius":    return String(localized: "zodiac.aquarius")
    case "pisces":      return String(localized: "zodiac.pisces")
    default:            return sign
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
