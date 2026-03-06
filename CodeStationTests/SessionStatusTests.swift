import XCTest
@testable import CodeStation

final class SessionStatusTests: XCTestCase {

    // MARK: - CaseIterable

    func testAllCases() {
        let cases = SessionStatus.allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertTrue(cases.contains(.cooking))
        XCTAssertTrue(cases.contains(.ready))
        XCTAssertTrue(cases.contains(.asleep))
        XCTAssertTrue(cases.contains(.waiting))
    }

    // MARK: - Emoji

    func testEmoji() {
        XCTAssertEqual(SessionStatus.cooking.emoji, Strings.Status.cookingEmoji)
        XCTAssertEqual(SessionStatus.ready.emoji, Strings.Status.readyEmoji)
        XCTAssertEqual(SessionStatus.asleep.emoji, Strings.Status.asleepEmoji)
        XCTAssertEqual(SessionStatus.waiting.emoji, Strings.Status.waitingEmoji)
    }

    func testEmojisAreNonEmpty() {
        for status in SessionStatus.allCases {
            XCTAssertFalse(status.emoji.isEmpty, "\(status) emoji should not be empty")
        }
    }

    // MARK: - Label

    func testLabel() {
        XCTAssertEqual(SessionStatus.cooking.label, Strings.Status.cooking)
        XCTAssertEqual(SessionStatus.ready.label, Strings.Status.ready)
        XCTAssertEqual(SessionStatus.asleep.label, Strings.Status.asleep)
        XCTAssertEqual(SessionStatus.waiting.label, Strings.Status.waiting)
    }

    func testLabelsAreNonEmpty() {
        for status in SessionStatus.allCases {
            XCTAssertFalse(status.label.isEmpty, "\(status) label should not be empty")
        }
    }

    // MARK: - Badge Color

    func testBadgeColor() {
        XCTAssertEqual(SessionStatus.cooking.badgeColor, "red")
        XCTAssertEqual(SessionStatus.ready.badgeColor, "green")
        XCTAssertEqual(SessionStatus.asleep.badgeColor, "gray")
        XCTAssertEqual(SessionStatus.waiting.badgeColor, "orange")
    }

    func testBadgeColorsAreUnique() {
        let colors = SessionStatus.allCases.map { $0.badgeColor }
        XCTAssertEqual(Set(colors).count, colors.count, "Badge colors should be unique")
    }

    // MARK: - Raw Value

    func testRawValues() {
        XCTAssertEqual(SessionStatus.cooking.rawValue, "cooking")
        XCTAssertEqual(SessionStatus.ready.rawValue, "ready")
        XCTAssertEqual(SessionStatus.asleep.rawValue, "asleep")
        XCTAssertEqual(SessionStatus.waiting.rawValue, "waiting")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(SessionStatus(rawValue: "cooking"), .cooking)
        XCTAssertEqual(SessionStatus(rawValue: "ready"), .ready)
        XCTAssertEqual(SessionStatus(rawValue: "asleep"), .asleep)
        XCTAssertEqual(SessionStatus(rawValue: "waiting"), .waiting)
        XCTAssertNil(SessionStatus(rawValue: "invalid"))
    }
}
