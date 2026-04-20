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
    // Legacy key — treated as presence
    case "daily":        return String(localized: "focus.name.presence")
    // Active keys
    case "presence":         return String(localized: "focus.name.presence")
    case "rest":             return String(localized: "focus.name.rest")
    case "focus_work":       return String(localized: "focus.name.focus_work")
    case "creativity":       return String(localized: "focus.name.creativity")
    case "connection":       return String(localized: "focus.name.connection")
    case "family":           return String(localized: "focus.name.family")
    case "conflict":         return String(localized: "focus.name.conflict")
    case "parenting":        return String(localized: "focus.name.parenting")
    case "heartbreak":       return String(localized: "focus.name.heartbreak")
    case "friendship":       return String(localized: "focus.name.friendship")
    case "singlehood":       return String(localized: "focus.name.singlehood")
    case "long_distance":    return String(localized: "focus.name.long_distance")
    case "recovery":         return String(localized: "focus.name.recovery")
    case "quitting":         return String(localized: "focus.name.quitting")
    case "chronic":          return String(localized: "focus.name.chronic")
    case "fertility":        return String(localized: "focus.name.fertility")
    case "menstrual":        return String(localized: "focus.name.menstrual")
    case "menopause":        return String(localized: "focus.name.menopause")
    case "transition":       return String(localized: "focus.name.transition")
    case "grief":            return String(localized: "focus.name.grief")
    case "caregiving":       return String(localized: "focus.name.caregiving")
    case "end_of_life":      return String(localized: "focus.name.end_of_life")
    case "graduation":       return String(localized: "focus.name.graduation")
    case "empty_nest":       return String(localized: "focus.name.empty_nest")
    case "clarity":          return String(localized: "focus.name.clarity")
    case "anxiety":          return String(localized: "focus.name.anxiety")
    case "identity":         return String(localized: "focus.name.identity")
    case "purpose":          return String(localized: "focus.name.purpose")
    case "loneliness":       return String(localized: "focus.name.loneliness")
    case "career":           return String(localized: "focus.name.career")
    case "research":         return String(localized: "focus.name.research")
    case "finance":          return String(localized: "focus.name.finance")
    case "relocation":       return String(localized: "focus.name.relocation")
    case "job_search":       return String(localized: "focus.name.job_search")
    case "exam":             return String(localized: "focus.name.exam")
    case "entrepreneurship": return String(localized: "focus.name.entrepreneurship")
    case "gratitude":        return String(localized: "focus.name.gratitude")
    case "birthday":         return String(localized: "focus.name.birthday")
    case "anniversary":      return String(localized: "focus.name.anniversary")
    case "solar_term":       return String(localized: "focus.name.solar_term")
    case "digital_detox":    return String(localized: "focus.name.digital_detox")
    default:                 return nameKey
    }
}

func focusLocalizedDescription(for nameKey: String, fallback: String) -> String {
    switch nameKey.lowercased() {
    case "daily":        return String(localized: "focus.desc.presence")
    case "presence":     return String(localized: "focus.desc.presence")
    case "rest":         return String(localized: "focus.desc.rest")
    case "focus_work":   return String(localized: "focus.desc.focus_work")
    case "creativity":   return String(localized: "focus.desc.creativity")
    case "connection":   return String(localized: "focus.desc.connection")
    case "family":       return String(localized: "focus.desc.family")
    case "conflict":     return String(localized: "focus.desc.conflict")
    case "parenting":    return String(localized: "focus.desc.parenting")
    case "recovery":     return String(localized: "focus.desc.recovery")
    case "quitting":     return String(localized: "focus.desc.quitting")
    case "chronic":      return String(localized: "focus.desc.chronic")
    case "fertility":    return String(localized: "focus.desc.fertility")
    case "transition":   return String(localized: "focus.desc.transition")
    case "grief":        return String(localized: "focus.desc.grief")
    case "caregiving":   return String(localized: "focus.desc.caregiving")
    case "end_of_life":  return String(localized: "focus.desc.end_of_life")
    case "clarity":      return String(localized: "focus.desc.clarity")
    case "anxiety":      return String(localized: "focus.desc.anxiety")
    case "identity":     return String(localized: "focus.desc.identity")
    case "purpose":      return String(localized: "focus.desc.purpose")
    case "career":       return String(localized: "focus.desc.career")
    case "research":     return String(localized: "focus.desc.research")
    case "finance":      return String(localized: "focus.desc.finance")
    case "relocation":   return String(localized: "focus.desc.relocation")
    default:             return fallback
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
