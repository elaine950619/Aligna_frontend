import Foundation
import CoreLocation

public struct BirthInfo {
    public let date: Date                 // stored moment (typically UTC)
    public let latitude: Double
    public let longitude: Double
    public let timezoneOffsetMinutes: Int // minutes offset from GMT at birth (e.g., +480 for GMT+8)
    public let originalUserInput: String? // if you saved the raw text the user typed, show it verbatim

    public init(date: Date,
                latitude: Double,
                longitude: Double,
                timezoneOffsetMinutes: Int,
                originalUserInput: String? = nil) {
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
        self.originalUserInput = originalUserInput
    }
}

public enum ZodiacSign: String, CaseIterable {
    case Aries, Taurus, Gemini, Cancer, Leo, Virgo, Libra, Scorpio, Sagittarius, Capricorn, Aquarius, Pisces
}

public struct AstroCalculator {

    // MARK: - 1) Birth time display (NO conversion)
    public static func displayBirthTime(_ info: BirthInfo, format: String = "yyyy-MM-dd HH:mm") -> String {
        if let raw = info.originalUserInput, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return raw
        }
        let tz = TimeZone(secondsFromGMT: info.timezoneOffsetMinutes * 60) ?? .current
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = tz
        df.dateFormat = format
        return df.string(from: info.date)
    }

    // MARK: - 2) Helpers
    private static func deg2rad(_ d: Double) -> Double { d * .pi / 180.0 }
    private static func rad2deg(_ r: Double) -> Double { r * 180.0 / .pi }
    private static func normalize(_ deg: Double) -> Double {
        var x = deg.truncatingRemainder(dividingBy: 360.0)
        if x < 0 { x += 360.0 }
        return x
    }

    // Julian Day / centuries
    private static func julianDay(_ date: Date) -> Double {
        let jdUnixEpoch: Double = 2440587.5
        return jdUnixEpoch + date.timeIntervalSince1970 / 86400.0
    }
    private static func centuriesSinceJ2000(_ date: Date) -> Double {
        (julianDay(date) - 2451545.0) / 36525.0
    }

    // MARK: - 3) Sun ecliptic longitude (approx)
    private static func sunLongitudeDegrees(_ date: Date) -> Double {
        let T = centuriesSinceJ2000(date)
        let L0 = normalize(280.46646 + 36000.76983 * T + 0.0003032 * T*T)
        let M  = normalize(357.52911 + 35999.05029 * T - 0.0001537 * T*T)
        let Mr = deg2rad(M)
        let C  = (1.914602 - 0.004817 * T - 0.000014 * T*T) * sin(Mr)
               + (0.019993 - 0.000101 * T) * sin(2*Mr)
               + 0.000289 * sin(3*Mr)
        return normalize(L0 + C)
    }

    // MARK: - 4) Moon ecliptic longitude (approx)
    private static func moonLongitudeDegrees(_ date: Date) -> Double {
        let T = centuriesSinceJ2000(date)
        let L0 = normalize(218.3164477 + 481267.88123421 * T - 0.0015786 * T*T)
        let D  = normalize(297.8501921 + 445267.1114034 * T - 0.0018819 * T*T)
        let M  = normalize(357.5291092 + 35999.0502909 * T - 0.0001536 * T*T)
        let Mp = normalize(134.9633964 + 477198.8675055 * T + 0.0087414 * T*T)
        let F  = normalize(93.2720950  + 483202.0175233 * T - 0.0036539 * T*T)

        let Dr = deg2rad(D), Mr = deg2rad(M), Mpr = deg2rad(Mp), Fr = deg2rad(F)

        var lon = L0
        lon += -1.274 * sin(Mpr - 2*Dr)    // Evection
        lon += +0.658 * sin(2*Dr)
        lon += -0.186 * sin(Mr)
        lon += -0.059 * sin(2*Mpr - 2*Dr)
        lon += -0.057 * sin(Mpr - 2*Dr + Mr)
        lon += +0.053 * sin(Mpr + 2*Dr)
        lon += +0.046 * sin(2*Dr - Mr)
        lon += +0.041 * sin(Mpr - Mr)
        lon += -0.035 * sin(Dr)
        lon += -0.031 * sin(Mpr + Mr)
        lon += -0.015 * sin(2*Fr - 2*Dr)
        lon += +0.011 * sin(Mpr - 4*Dr)
        return normalize(lon)
    }

    // MARK: - 5) Ascendant ecliptic longitude (approx)
    private static func ascendantLongitudeDegrees(_ info: BirthInfo) -> Double {
        let utcDate = info.date.addingTimeInterval(-Double(info.timezoneOffsetMinutes * 60))
        let jd = julianDay(utcDate)
        let T  = (jd - 2451545.0) / 36525.0

        var gmst = 280.46061837
                + 360.98564736629 * (jd - 2451545.0)
                + 0.000387933 * T*T
                - (T*T*T) / 38710000.0
        gmst = normalize(gmst)

        let lst = normalize(gmst + info.longitude)
        let eps = 23.439291 - 0.0130042 * T
        let epsR = deg2rad(eps)
        let latR = deg2rad(info.latitude)
        let lstR = deg2rad(lst)

        let numerator = -cos(lstR)
        let denominator = sin(epsR) * tan(latR) + cos(epsR) * sin(lstR)
        var asc = atan2(numerator, denominator)
        var ascDeg = normalize(rad2deg(asc))
        if ascDeg < 0 { ascDeg += 360.0 }
        return ascDeg
    }

    // MARK: - 6) Map ecliptic longitude to sign
    private static func sign(fromEclipticLongitude lon: Double) -> ZodiacSign {
        let idx = Int(floor(normalize(lon) / 30.0)) % 12
        return ZodiacSign.allCases[idx]
    }

    // MARK: - Public APIs
    public static func sunSign(date: Date) -> ZodiacSign {
        sign(fromEclipticLongitude: sunLongitudeDegrees(date))
    }

    public static func moonSign(date: Date) -> ZodiacSign {
        sign(fromEclipticLongitude: moonLongitudeDegrees(date))
    }

    public static func ascendantSign(info: BirthInfo) -> ZodiacSign {
        sign(fromEclipticLongitude: ascendantLongitudeDegrees(info))
    }

    /// Optional helper if you want to warn when near a cusp (±1°).
    public static func cuspNote(eclipticLongitude lon: Double) -> String? {
        let mod = normalize(lon).truncatingRemainder(dividingBy: 30.0)
        if mod <= 1.0 || mod >= 29.0 {
            return "(Near a cusp; result may have a ±1° uncertainty)"
        }
        return nil
    }
}
