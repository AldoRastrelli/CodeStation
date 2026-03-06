import XCTest
@testable import CodeStation

final class NotificationSettingsTests: XCTestCase {

    // MARK: - Defaults

    func testDefaultValues() {
        let settings = NotificationSettings()
        XCTAssertTrue(settings.enabled)
        XCTAssertTrue(settings.notifyWhenDone)
        XCTAssertTrue(settings.notifyWhenWaiting)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertEqual(settings.soundName, "Funk")
    }

    // MARK: - Available Sounds

    func testAvailableSoundsIsNotEmpty() {
        XCTAssertFalse(NotificationSettings.availableSounds.isEmpty)
    }

    func testAvailableSoundsContainsDefaultSound() {
        XCTAssertTrue(NotificationSettings.availableSounds.contains("Funk"))
    }

    func testAvailableSoundsCount() {
        XCTAssertEqual(NotificationSettings.availableSounds.count, 14)
    }

    func testAvailableSoundsAreUnique() {
        let sounds = NotificationSettings.availableSounds
        XCTAssertEqual(Set(sounds).count, sounds.count)
    }

    // MARK: - Codable

    func testEncodeDecode() throws {
        var settings = NotificationSettings()
        settings.enabled = false
        settings.notifyWhenDone = false
        settings.notifyWhenWaiting = false
        settings.soundEnabled = false
        settings.soundName = "Ping"

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(NotificationSettings.self, from: data)

        XCTAssertEqual(settings, decoded)
    }

    func testDecodeFromDefaultsIsEqual() throws {
        let original = NotificationSettings()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotificationSettings.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Equatable

    func testEquality() {
        let a = NotificationSettings()
        var b = NotificationSettings()
        XCTAssertEqual(a, b)

        b.enabled = false
        XCTAssertNotEqual(a, b)
    }

    func testEqualityAllFields() {
        var a = NotificationSettings()
        var b = NotificationSettings()

        a.soundName = "Basso"
        b.soundName = "Basso"
        XCTAssertEqual(a, b)

        b.soundName = "Pop"
        XCTAssertNotEqual(a, b)
    }
}
