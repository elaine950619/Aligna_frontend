import Foundation
import UserNotifications
import CoreLocation

enum MantraNotificationManager {
    static let morningIdentifier = "alynna_morning_sunrise"
    static let eveningIdentifier = "alynna_evening_sunset"

    // MARK: - Public API

    /// Schedule two daily notifications with personalised content.
    /// - Morning: shows the mantra preview (first ~40 chars).
    /// - Evening: adapts based on score, keywords and moon sign.
    /// Call whenever mantra or score/keywords change.
    static func scheduleFixed(
        mantra: String,
        isChinese: Bool,
        score: Int = 0,
        keywords: [String] = [],
        moonSign: String = ""
    ) {
        let center = UNUserNotificationCenter.current()
        let times = notificationTimes()

        // ── Morning ──────────────────────────────────────────────
        let morningTitle = isChinese ? "今日心语" : "Today's Mantra"
        let morningBody  = morningBody(mantra: mantra, isChinese: isChinese)
        schedule(identifier: morningIdentifier,
                 title: morningTitle, body: morningBody,
                 hour: times.morningHour, minute: times.morningMinute,
                 center: center)

        // ── Evening ───────────────────────────────────────────────
        let (eveningTitle, eveningBody) = eveningContent(
            score: score, keywords: keywords,
            moonSign: moonSign, isChinese: isChinese
        )
        schedule(identifier: eveningIdentifier,
                 title: eveningTitle, body: eveningBody,
                 hour: times.eveningHour, minute: times.eveningMinute,
                 center: center)
    }

    // MARK: - Moon Ritual Notifications

    /// Schedule an 8 AM notification on a new-moon or full-moon day.
    static func scheduleMoonRitual(phase: MoonPhase, isChinese: Bool) {
        let center = UNUserNotificationCenter.current()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dayKey = df.string(from: Date())
        let identifier = "moon_ritual_\(phase.rawValue)_\(dayKey)"

        center.getPendingNotificationRequests { requests in
            guard !requests.contains(where: { $0.identifier == identifier }) else { return }

            let content = UNMutableNotificationContent()
            switch phase {
            case .new:
                content.title = isChinese ? "🌑 新月" : "🌑 New Moon"
                content.body  = isChinese
                    ? "今天是新月。写下本月最想实现的三件事——意图，在被看见的那一刻开始生长。"
                    : "New moon today. Write down 3 intentions for this month — seeds planted in the dark."
            case .full:
                content.title = isChinese ? "🌕 满月" : "🌕 Full Moon"
                content.body  = isChinese
                    ? "今天是满月。写下你准备放下的三件事——满月是结束，也是空间。"
                    : "Full moon tonight. Write down 3 things you're ready to release — endings make room."
            default:
                return
            }
            content.sound = .default
            content.userInfo = ["destination": "moon_ritual_\(phase.rawValue)"]

            var comps = DateComponents()
            comps.hour = 8
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    /// Cancel both daily notifications.
    static func cancelFixed() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningIdentifier, eveningIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [morningIdentifier, eveningIdentifier])
    }

    // MARK: - Solar time helpers

    static func notificationTimes() -> (morningHour: Int, morningMinute: Int,
                                        eveningHour: Int, eveningMinute: Int) {
        let defaults = UserDefaults.standard
        let lat = defaults.double(forKey: "lastKnownLatitude")
        let lon = defaults.double(forKey: "lastKnownLongitude")

        guard lat != 0 || lon != 0 else { return (9, 0, 20, 0) }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        guard let sunrise = solarTime(for: Date(), coordinate: coordinate, isSunrise: true),
              let sunset  = solarTime(for: Date(), coordinate: coordinate, isSunrise: false) else {
            return (9, 0, 20, 0)
        }

        let morningDate = sunrise.addingTimeInterval(15 * 60)
        let cal = Calendar.current
        return (
            cal.component(.hour,   from: morningDate),
            cal.component(.minute, from: morningDate),
            cal.component(.hour,   from: sunset),
            cal.component(.minute, from: sunset)
        )
    }

    // MARK: - Content builders

    /// Morning body: mantra text trimmed to ~40 chars, or a gentle fallback.
    private static func morningBody(mantra: String, isChinese: Bool) -> String {
        let trimmed = mantra.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return isChinese ? "今天的心语已准备好，点击查看。" : "Your mantra for today is ready."
        }
        let limit = 42
        if trimmed.count <= limit { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return String(trimmed[..<idx]) + "…"
    }

    /// Evening content: adapts to score, keywords and moon sign.
    private static func eveningContent(
        score: Int,
        keywords: [String],
        moonSign: String,
        isChinese: Bool
    ) -> (title: String, body: String) {

        let kw = keywords.prefix(2).joined(separator: isChinese ? "、" : " & ")

        // High alignment (≥ 70)
        if score >= 70 {
            let title = isChinese ? "今日和度 \(starString(score))" : "Today's Alignment \(starString(score))"
            let body: String
            if kw.isEmpty {
                body = isChinese
                    ? "今天的状态很好。让它记住你，而不是你追着它跑。"
                    : "You were aligned today. Let it settle — don't chase it, just notice."
            } else {
                body = isChinese
                    ? "今天你感受到了 \(kw)。带着这份记忆去休息。"
                    : "Today held \(kw). Carry that into your rest."
            }
            return (title, body)
        }

        // Low alignment (1–69) — compassionate + keyword
        if score > 0 {
            let title = isChinese ? "今日心语回顾" : "Evening Reflection"
            let body: String
            if kw.isEmpty {
                body = isChinese
                    ? "今天有些阻力。睡前放慢三次呼吸——明天是新的起点。"
                    : "Some resistance today. Three slow breaths before sleep — tomorrow starts fresh."
            } else {
                body = isChinese
                    ? "今天有 \(kw) 的影子。不需要解决，只需要看见它。"
                    : "There was \(kw) today. You don't have to fix it — just name it."
            }
            return (title, body)
        }

        // No score yet — use moon sign hint if available
        let moon = moonSign.lowercased().trimmingCharacters(in: .whitespaces)
        if !moon.isEmpty, let hint = moonSignHint(moon, isChinese: isChinese) {
            let title = isChinese ? "今晚的月亮提示" : "Tonight's Moon Note"
            return (title, hint)
        }

        // Fallback
        let title = isChinese ? "今日心语提醒" : "Evening Reflection"
        let body  = isChinese
            ? "今天过得怎么样？点击记录一条感受。"
            : "How was today? Tap to leave a note for yourself."
        return (title, body)
    }

    /// ★ string based on score (0-100 → 0-5 filled stars).
    private static func starString(_ score: Int) -> String {
        let filled = min(5, max(0, Int((Double(score) / 20.0).rounded())))
        return String(repeating: "★", count: filled) + String(repeating: "☆", count: 5 - filled)
    }

    // MARK: - Moon sign evening hints (12 signs × ZH + EN)
    // One gentle, actionable line per sign for the evening slot.
    private static func moonSignHint(_ sign: String, isChinese: Bool) -> String? {
        if isChinese {
            switch sign {
            case "aries":       return "今晚月在牡羊——把多余的能量写下来，别带着它进入睡眠。"
            case "taurus":      return "今晚月在金牛——用一顿安静的晚饭或一件喜欢的事犒赏自己。"
            case "gemini":      return "今晚月在双子——脑子转得快，写一句话把今天整理清楚。"
            case "cancer":      return "今晚月在巨蟹——感受比平时细腻，允许自己今晚更柔软一点。"
            case "leo":         return "今晚月在狮子——你今天给出去很多，记得也留一点给自己。"
            case "virgo":       return "今晚月在处女——今天做到的事值得记下来，不只是没做到的。"
            case "libra":       return "今晚月在天秤——放下今天没解决的平衡，明天有新的角度。"
            case "scorpio":     return "今晚月在天蝎——如果今天有什么压着你，可以写下来再放下。"
            case "sagittarius": return "今晚月在射手——让思绪在睡前落地，明天再出发。"
            case "capricorn":   return "今晚月在摩羯——你已经够努力了，休息也是一种工作。"
            case "aquarius":    return "今晚月在水瓶——让大脑先下线，感受一会儿当下的安静。"
            case "pisces":      return "今晚月在双鱼——今天的感受都是真实的，不需要解释它们。"
            default:            return nil
            }
        } else {
            switch sign {
            case "aries":       return "Moon in Aries tonight — write out any restless energy before bed."
            case "taurus":      return "Moon in Taurus — treat yourself to something simple and grounding."
            case "gemini":      return "Moon in Gemini — one sentence to close the day; let the rest go."
            case "cancer":      return "Moon in Cancer — feelings run deeper tonight. Be gentle with yourself."
            case "leo":         return "Moon in Leo — you gave a lot today. Save some warmth for yourself."
            case "virgo":       return "Moon in Virgo — write one thing you did well, not just what's left."
            case "libra":       return "Moon in Libra — you don't have to resolve everything tonight."
            case "scorpio":     return "Moon in Scorpio — if something is weighing on you, name it and set it down."
            case "sagittarius": return "Moon in Sagittarius — let your thoughts land before sleep."
            case "capricorn":   return "Moon in Capricorn — rest is part of the work. You've done enough today."
            case "aquarius":    return "Moon in Aquarius — step away from the big picture and just breathe."
            case "pisces":      return "Moon in Pisces — your feelings tonight are valid. No explanation needed."
            default:            return nil
            }
        }
    }

    // MARK: - Private: NOAA solar calculation

    private static func solarTime(
        for date: Date,
        coordinate: CLLocationCoordinate2D,
        isSunrise: Bool
    ) -> Date? {
        let zenith = 90.833
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let longitudeHour = (-coordinate.longitude) / 15.0
        let approx = Double(dayOfYear) + ((isSunrise ? 6.0 : 18.0) - longitudeHour) / 24.0

        let meanAnomaly = (0.9856 * approx) - 3.289
        var trueLongitude = meanAnomaly
            + (1.916 * sin(meanAnomaly * .pi / 180))
            + (0.020 * sin(2 * meanAnomaly * .pi / 180))
            + 282.634
        trueLongitude = normalizedDegrees(trueLongitude)

        var rightAscension = atan(0.91764 * tan(trueLongitude * .pi / 180)) * 180 / .pi
        rightAscension = normalizedDegrees(rightAscension)

        let trueQuadrant = floor(trueLongitude / 90.0) * 90.0
        let ascQuadrant  = floor(rightAscension / 90.0) * 90.0
        rightAscension = (rightAscension + trueQuadrant - ascQuadrant) / 15.0

        let sinDeclination = 0.39782 * sin(trueLongitude * .pi / 180)
        let cosDeclination = cos(asin(sinDeclination))
        let cosHourAngle =
            (cos(zenith * .pi / 180) - (sinDeclination * sin(coordinate.latitude * .pi / 180))) /
            (cosDeclination * cos(coordinate.latitude * .pi / 180))

        guard cosHourAngle >= -1.0, cosHourAngle <= 1.0 else { return nil }

        let hourAngleDegrees = isSunrise
            ? 360.0 - acos(cosHourAngle) * 180 / .pi
            :          acos(cosHourAngle) * 180 / .pi

        let localHour = hourAngleDegrees / 15.0
        let localMeanTime = localHour + rightAscension - (0.06571 * approx) - 6.622
        let utcHour = normalizedHours(localMeanTime - longitudeHour)
        let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600.0
        let localTimeHour = normalizedHours(utcHour + timeZoneOffset)

        return calendar.startOfDay(for: date).addingTimeInterval(localTimeHour * 3600.0)
    }

    private static func normalizedDegrees(_ v: Double) -> Double {
        let m = v.truncatingRemainder(dividingBy: 360.0); return m >= 0 ? m : m + 360.0
    }
    private static func normalizedHours(_ v: Double) -> Double {
        let m = v.truncatingRemainder(dividingBy: 24.0); return m >= 0 ? m : m + 24.0
    }

    // MARK: - Private: scheduling

    private static func schedule(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        center: UNUserNotificationCenter
    ) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["destination": "main_expanded"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
