import Foundation
import UserNotifications

/// Centralized notification service.
/// Handles authorization, scheduling, categories, and deep-link routing
/// when users tap notifications.
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    @Published var isAuthorized = false

    // MARK: - Categories & Actions

    private enum Category: String {
        case dailyReminder = "DAILY_REMINDER"
        case onThisDay = "ON_THIS_DAY"
    }

    private enum Action: String {
        case view = "VIEW_ACTION"
        case remindLater = "REMIND_LATER_ACTION"
    }

    // MARK: - Init

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupCategories()
    }

    private func setupCategories() {
        let viewAction = UNNotificationAction(
            identifier: Action.view.rawValue,
            title: "View",
            options: [.foreground]
        )
        let remindLaterAction = UNNotificationAction(
            identifier: Action.remindLater.rawValue,
            title: "Remind Me Later",
            options: []
        )

        let dailyCategory = UNNotificationCategory(
            identifier: Category.dailyReminder.rawValue,
            actions: [viewAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )
        let onThisDayCategory = UNNotificationCategory(
            identifier: Category.onThisDay.rawValue,
            actions: [viewAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            dailyCategory,
            onThisDayCategory
        ])
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    // MARK: - Schedule Daily Reminder

    func scheduleDailyReminder(hour: Int, minute: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyBlink"])

        let content = UNMutableNotificationContent()
        content.title = "Blink today?"
        content.body = "Your year is waiting. Record a moment."
        content.sound = .default
        content.categoryIdentifier = Category.dailyReminder.rawValue

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "dailyBlink",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error)")
            }
        }
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyBlink"])
    }

    // MARK: - Schedule On This Day

    func scheduleOnThisDay(for date: Date, clipCount: Int) {
        let content = UNMutableNotificationContent()

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let dateStr = formatter.string(from: date)

        if clipCount == 1 {
            content.title = "On this day"
            content.body = "\(dateStr): Your moment from last year is waiting."
        } else {
            content.title = "On this day"
            content.body = "\(dateStr): You have \(clipCount) moments from last year."
        }

        content.sound = .default
        content.categoryIdentifier = Category.onThisDay.rawValue

        // Trigger at 9 AM on the anniversary date
        var triggerComponents = Calendar.current.dateComponents([.month, .day], from: date)
        triggerComponents.hour = 9
        triggerComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "onThisDay-\(dateStr)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule On This Day notification: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when user taps a notification.
    /// Routes tap to deep link handler.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let categoryId = response.notification.request.content.categoryIdentifier
        let actionId = response.actionIdentifier

        switch categoryId {
        case Category.dailyReminder.rawValue:
            if actionId == Action.remindLater.rawValue {
                // Reschedule for 1 hour from now
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
                let content = UNMutableNotificationContent()
                content.title = "Blink today?"
                content.body = "Your year is waiting. Record a moment."
                content.sound = .default
                content.categoryIdentifier = Category.dailyReminder.rawValue
                let request = UNNotificationRequest(
                    identifier: "dailyBlink-remindLater",
                    content: content,
                    trigger: trigger
                )
                center.add(request, withCompletionHandler: nil)
            } else {
                DeepLinkHandler.shared.pendingDeepLink = .record
            }

        case Category.onThisDay.rawValue:
            if actionId == Action.remindLater.rawValue {
                // Reschedule for tomorrow at 9 AM
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: DateComponents(hour: 9, minute: 0),
                    repeats: false
                )
                let content = UNMutableNotificationContent()
                content.title = "On this day"
                content.body = "A moment from last year is waiting."
                content.sound = .default
                content.categoryIdentifier = Category.onThisDay.rawValue
                let request = UNNotificationRequest(
                    identifier: "onThisDay-remindLater",
                    content: content,
                    trigger: trigger
                )
                center.add(request, withCompletionHandler: nil)
            } else {
                DeepLinkHandler.shared.pendingDeepLink = .onThisDay(date: nil)
            }

        default:
            break
        }

        completionHandler()
    }

    /// Forward to the system: used for notifications when app is in foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
