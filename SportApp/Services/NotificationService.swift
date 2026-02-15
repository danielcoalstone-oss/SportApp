import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Best-effort for MVP.
        }
    }

    func scheduleMatchReminder(matchId: UUID, title: String, startTime: Date, userId: UUID, minutesBefore: Int = 60) {
        let reminderDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: startTime) ?? startTime
        guard reminderDate > Date() else { return }

        let identifier = reminderIdentifier(matchId: matchId, userId: userId)
        let content = UNMutableNotificationContent()
        content.title = "Match Reminder"
        content.body = "\(title) starts at \(DateFormatterService.tournamentDateTime.string(from: startTime))."
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().add(request)
    }

    func cancelMatchReminder(matchId: UUID, userId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminderIdentifier(matchId: matchId, userId: userId)]
        )
    }

    private func reminderIdentifier(matchId: UUID, userId: UUID) -> String {
        "sportapp.match.reminder.\(matchId.uuidString.lowercased()).\(userId.uuidString.lowercased())"
    }
}
