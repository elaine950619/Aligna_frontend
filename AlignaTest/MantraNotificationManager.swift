import Foundation
import UserNotifications
import CoreLocation

enum MantraNotificationManager {
    static let morningIdentifier = "alynna_morning_sunrise"
    static let eveningIdentifier = "alynna_evening_sunset"

    // MARK: - Public API

    /// Schedule two daily notifications: sunrise+15 min (morning) and sunset (evening).
    /// Falls back to 9 AM / 8 PM when no location is available.
    /// Call whenever the mantra content changes so both carry the latest text.
    static func scheduleFixed(mantra: String, isChinese: Bool) {
        let center = UNUserNotificationCenter.current()

        let trimmed = mantra.trimmingCharacters(in: .whitespacesAndNewlines)
        let morningTitle = isChinese ? "早安，今日心语" : "Good Morning"
        let eveningTitle = isChinese ? "今日心语提醒" : "Evening Reflection"
        let fallbackBody = isChinese ? "今天的心语已准备好，点击查看。" : "Today's mantra is ready. Tap to open."
        let body = trimmed.isEmpty ? fallbackBody : trimmed

        let times = notificationTimes()
        schedule(identifier: morningIdentifier, title: morningTitle, body: body,
                 hour: times.morningHour, minute: times.morningMinute, center: center)
        schedule(identifier: eveningIdentifier, title: eveningTitle, body: body,
                 hour: times.eveningHour, minute: times.eveningMinute, center: center)
    }

    // MARK: - Moon Ritual Notifications

    /// Schedule an 8 AM notification on a new-moon or full-moon day.
    /// Uses a date-stamped identifier so it fires only once per event.
    static func scheduleMoonRitual(phase: MoonPhase, isChinese: Bool) {
        let center = UNUserNotificationCenter.current()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dayKey = df.string(from: Date())
        let identifier = "moon_ritual_\(phase.rawValue)_\(dayKey)"

        // Don't schedule if already pending for today
        center.getPendingNotificationRequests { requests in
            guard !requests.contains(where: { $0.identifier == identifier }) else { return }

            let content = UNMutableNotificationContent()
            switch phase {
            case .new:
                content.title = isChinese ? "新月仪式" : "New Moon Ritual"
                content.body  = isChinese ? "今天是新月。写下本月最想实现的三个意图。" : "It's a new moon. Write down 3 intentions for this month."
            case .full:
                content.title = isChinese ? "满月仪式" : "Full Moon Ritual"
                content.body  = isChinese ? "今天是满月。写下你准备放下的三件事。" : "It's a full moon. Write down 3 things you're ready to release."
            default:
                return
            }
            content.sound = .default
            content.userInfo = ["destination": "moon_ritual_\(phase.rawValue)"]

            var comps = DateComponents()
            comps.hour = 8
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// Cancel both notifications.
    static func cancelFixed() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningIdentifier, eveningIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [morningIdentifier, eveningIdentifier])
    }

    // MARK: - Solar time helpers

    /// Returns (morningHour, morningMinute, eveningHour, eveningMinute).
    /// Morning = sunrise + 15 min; Evening = sunset. Falls back to 9:00 / 20:00.
    static func notificationTimes() -> (morningHour: Int, morningMinute: Int,
                                        eveningHour: Int, eveningMinute: Int) {
        let defaults = UserDefaults.standard
        let lat = defaults.double(forKey: "lastKnownLatitude")
        let lon = defaults.double(forKey: "lastKnownLongitude")

        // 0,0 is a sentinel for "no stored location"
        guard lat != 0 || lon != 0 else {
            return (9, 0, 20, 0)
        }

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

    // MARK: - Private: NOAA solar calculation (mirrors ThemeManager)

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
        let m = v.truncatingRemainder(dividingBy: 24.0);  return m >= 0 ? m : m + 24.0
    }

    // MARK: - Private: notification scheduling

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

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }
}
