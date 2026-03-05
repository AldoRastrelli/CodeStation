import Foundation
import UserNotifications
import AppKit

enum NotificationService {
    static let categoryIdentifier = "statusChange"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func send(title: String, body: String, environmentID: UUID, sessionID: UUID, settings: NotificationSettings) {
        // Always play sound independently — UNNotification sound is blocked when permissions are denied
        if settings.soundEnabled {
            playSound(named: settings.soundName)
        }

        if settings.enabled {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.categoryIdentifier = categoryIdentifier
            content.userInfo = [
                "environmentID": environmentID.uuidString,
                "sessionID": sessionID.uuidString
            ]

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    static func playSound(named name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}
