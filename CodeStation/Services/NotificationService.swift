import Foundation
import UserNotifications
import AppKit

enum NotificationService {
    static let categoryIdentifier = "statusChange"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[Notifications] Permission error: \(error.localizedDescription)")
            } else {
                print("[Notifications] Permission granted: \(granted)")
            }
        }
    }

    static func send(title: String, body: String, environmentID: UUID, sessionID: UUID, settings: NotificationSettings) {
        if settings.enabled {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = settings.soundEnabled ? UNNotificationSound(named: UNNotificationSoundName(rawValue: settings.soundName + ".aiff")) : nil
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

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Notifications] Send error: \(error.localizedDescription)")
                }
            }
        } else if settings.soundEnabled {
            playSound(named: settings.soundName)
        }
    }

    static func playSound(named name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}
