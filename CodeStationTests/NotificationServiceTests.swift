import XCTest
@testable import CodeStation

final class NotificationServiceTests: XCTestCase {

    func testCategoryIdentifier() {
        XCTAssertEqual(NotificationService.categoryIdentifier, "statusChange")
    }

    func testPlaySoundDoesNotCrashWithInvalidName() {
        // Should not crash with a non-existent sound name
        NotificationService.playSound(named: "NonExistentSound12345")
    }

    func testPlaySoundWithValidName() {
        // Should not crash with a valid system sound
        NotificationService.playSound(named: "Funk")
    }

    func testSendWithSoundDisabledAndNotificationsDisabled() {
        let settings = NotificationSettings(
            enabled: false,
            notifyWhenDone: false,
            notifyWhenWaiting: false,
            soundEnabled: false,
            soundName: "Funk"
        )
        // Should not crash
        NotificationService.send(
            title: "Test",
            body: "Body",
            environmentID: UUID(),
            sessionID: UUID(),
            settings: settings
        )
    }

    func testSendWithSoundEnabled() {
        var settings = NotificationSettings()
        settings.soundEnabled = true
        settings.enabled = false
        // Should play sound but not send notification
        NotificationService.send(
            title: "Test",
            body: "Body",
            environmentID: UUID(),
            sessionID: UUID(),
            settings: settings
        )
    }

    func testRequestPermissionDoesNotCrash() {
        NotificationService.requestPermission()
    }
}
