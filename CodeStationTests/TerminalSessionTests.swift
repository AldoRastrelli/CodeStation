import XCTest
@testable import CodeStation

final class TerminalSessionTests: XCTestCase {

    // MARK: - Init

    func testDefaultInit() {
        let session = TerminalSession(gridIndex: 0)
        XCTAssertEqual(session.gridIndex, 0)
        XCTAssertEqual(session.title, Strings.Terminals.defaultTitle(0))
        XCTAssertEqual(session.sessionDescription, "")
        XCTAssertEqual(session.status, .ready)
        XCTAssertFalse(session.isUserEditedTitle)
        XCTAssertNil(session.lastOutputTime)
        XCTAssertNil(session.lastHookEventTime)
        XCTAssertNil(session.currentDirectory)
    }

    func testInitWithCustomTitle() {
        let session = TerminalSession(gridIndex: 2, title: "My Terminal")
        XCTAssertEqual(session.gridIndex, 2)
        XCTAssertEqual(session.title, "My Terminal")
    }

    func testInitWithNilTitleUsesDefault() {
        let session = TerminalSession(gridIndex: 3, title: nil)
        XCTAssertEqual(session.title, Strings.Terminals.defaultTitle(3))
    }

    func testDefaultTitleFormat() {
        let session0 = TerminalSession(gridIndex: 0)
        XCTAssertEqual(session0.title, "Terminal 1")

        let session4 = TerminalSession(gridIndex: 4)
        XCTAssertEqual(session4.title, "Terminal 5")
    }

    // MARK: - Identifiable

    func testUniqueIDs() {
        let session1 = TerminalSession(gridIndex: 0)
        let session2 = TerminalSession(gridIndex: 0)
        XCTAssertNotEqual(session1.id, session2.id)
    }

    // MARK: - Mutable Properties

    func testStatusCanBeChanged() {
        let session = TerminalSession(gridIndex: 0)
        XCTAssertEqual(session.status, .ready)

        session.status = .cooking
        XCTAssertEqual(session.status, .cooking)

        session.status = .asleep
        XCTAssertEqual(session.status, .asleep)

        session.status = .waiting
        XCTAssertEqual(session.status, .waiting)
    }

    func testGridIndexCanBeChanged() {
        let session = TerminalSession(gridIndex: 0)
        session.gridIndex = 5
        XCTAssertEqual(session.gridIndex, 5)
    }

    func testCurrentDirectoryCanBeSet() {
        let session = TerminalSession(gridIndex: 0)
        XCTAssertNil(session.currentDirectory)
        session.currentDirectory = "/Users/test"
        XCTAssertEqual(session.currentDirectory, "/Users/test")
    }

    func testLastOutputTimeCanBeSet() {
        let session = TerminalSession(gridIndex: 0)
        let now = Date()
        session.lastOutputTime = now
        XCTAssertEqual(session.lastOutputTime, now)
    }

    func testUserEditedTitle() {
        let session = TerminalSession(gridIndex: 0)
        XCTAssertFalse(session.isUserEditedTitle)
        session.isUserEditedTitle = true
        XCTAssertTrue(session.isUserEditedTitle)
    }

    func testSessionDescription() {
        let session = TerminalSession(gridIndex: 0)
        XCTAssertEqual(session.sessionDescription, "")
        session.sessionDescription = "Running tests"
        XCTAssertEqual(session.sessionDescription, "Running tests")
    }
}
