// Sources/App/NotificationManager.swift
import Foundation
import UserNotifications
import AgentPetCore

/// Posts native notifications when an agent needs attention, a break is due,
/// or a scheduled reminder fires.
@MainActor
final class NotificationManager: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// UserDefaults key for the in-app "show notifications" toggle.
    static let enabledKey = "agentpet.notificationsEnabled"

    static let reminderCategoryIdentifier = "AGENTPET_REMINDER_CATEGORY"
    static let actionSnooze5 = "SNOOZE_5"
    static let actionSnooze15 = "SNOOZE_15"
    static let actionMarkDone = "MARK_DONE"

    /// `UNUserNotificationCenter` needs a real bundle id; false under bare CLI.
    var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    var userEnabled: Bool {
        (UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool) ?? true
    }

    override init() {
        super.init()
        setupCategories()
    }

    private func setupCategories() {
        guard isAvailable else { return }

        let snooze5Action = UNNotificationAction(
            identifier: Self.actionSnooze5,
            title: "Snooze 5m",
            options: []
        )
        let snooze15Action = UNNotificationAction(
            identifier: Self.actionSnooze15,
            title: "Snooze 15m",
            options: []
        )
        let doneAction = UNNotificationAction(
            identifier: Self.actionMarkDone,
            title: "Mark Done",
            options: [.foreground]
        )

        let reminderCategory = UNNotificationCategory(
            identifier: Self.reminderCategoryIdentifier,
            actions: [snooze5Action, snooze15Action, doneAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([reminderCategory])
        UNUserNotificationCenter.current().delegate = self
    }

    func notify(title: String, body: String) {
        guard isAvailable, userEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func notifyReminder(reminder: DueReminder) {
        guard isAvailable, userEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.categoryIdentifier = Self.reminderCategoryIdentifier
        content.userInfo = ["ruleId": reminder.ruleId]

        let request = UNNotificationRequest(
            identifier: "reminder-\(reminder.ruleId)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        if let ruleId = userInfo["ruleId"] as? String {
            switch action {
            case Self.actionSnooze5:
                ReminderController.shared.snooze(ruleId: ruleId, minutes: 5)
            case Self.actionSnooze15:
                ReminderController.shared.snooze(ruleId: ruleId, minutes: 15)
            case Self.actionMarkDone:
                ReminderController.shared.complete(ruleId: ruleId)
            default:
                break
            }
        }
        completionHandler()
    }
}
