import Foundation
import UserNotifications

enum MantraNotificationManager {
    static let dailyIdentifier = "daily_mantra"

    static func scheduleDaily(mantra: String, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [dailyIdentifier])

        let trimmedMantra = mantra.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyText = trimmedMantra.isEmpty
            ? "Your daily mantra is ready."
            : trimmedMantra

        let content = UNMutableNotificationContent()
        content.title = "Daily Mantra"
        content.body = bodyText
        content.sound = .default
        content.userInfo = ["destination": "main_expanded"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: dailyIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    static func cancelDaily() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [dailyIdentifier])
    }
}
