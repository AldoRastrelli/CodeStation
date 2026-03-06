import XCTest
@testable import CodeStation

final class StringsTests: XCTestCase {

    // MARK: - App

    func testAppName() {
        XCTAssertEqual(Strings.App.name, "CodeStation")
    }

    // MARK: - Environments

    func testEnvironmentsDefaultName() {
        XCTAssertEqual(Strings.Environments.defaultName, "Environment")
    }

    func testEnvironmentsNewName() {
        XCTAssertEqual(Strings.Environments.newName(1), "Environment 1")
        XCTAssertEqual(Strings.Environments.newName(5), "Environment 5")
    }

    // MARK: - Terminals

    func testTerminalsDefaultTitle() {
        XCTAssertEqual(Strings.Terminals.defaultTitle(0), "Terminal 1")
        XCTAssertEqual(Strings.Terminals.defaultTitle(7), "Terminal 8")
    }

    func testTerminalsSessionCount() {
        XCTAssertEqual(Strings.Terminals.sessionCount(3, max: 8), "3/8")
    }

    func testTerminalsCloseConfirmation() {
        let msg = Strings.Terminals.closeConfirmation("MyTerm")
        XCTAssertTrue(msg.contains("MyTerm"))
    }

    // MARK: - Status Strings

    func testStatusStrings() {
        XCTAssertEqual(Strings.Status.cooking, "Cooking")
        XCTAssertEqual(Strings.Status.ready, "Ready")
        XCTAssertEqual(Strings.Status.asleep, "Asleep")
        XCTAssertEqual(Strings.Status.waiting, "Waiting")
    }

    func testStatusEmojis() {
        XCTAssertFalse(Strings.Status.cookingEmoji.isEmpty)
        XCTAssertFalse(Strings.Status.readyEmoji.isEmpty)
        XCTAssertFalse(Strings.Status.asleepEmoji.isEmpty)
        XCTAssertFalse(Strings.Status.waitingEmoji.isEmpty)
    }

    // MARK: - Persistence

    func testPersistenceConstants() {
        XCTAssertEqual(Strings.Persistence.appSupportDir, "CodeStation")
        XCTAssertEqual(Strings.Persistence.filename, "environments.json")
    }

    // MARK: - Shell

    func testShellConstants() {
        XCTAssertEqual(Strings.Shell.fallbackShell, "/bin/zsh")
        XCTAssertEqual(Strings.Shell.termValue, "xterm-256color")
        XCTAssertEqual(Strings.Shell.colorTermValue, "truecolor")
        XCTAssertEqual(Strings.Shell.sessionEnvVar, "CODESTATION_SESSION_ID")
    }

    // MARK: - Notifications

    func testNotificationsDoneBody() {
        let body = Strings.Notifications.doneBody("MyTerm")
        XCTAssertTrue(body.contains("MyTerm"))
    }

    func testNotificationsWaitingBody() {
        let body = Strings.Notifications.waitingBody("MyTerm")
        XCTAssertTrue(body.contains("MyTerm"))
    }

    // MARK: - Hooks

    func testHooksStateDirectory() {
        XCTAssertEqual(Strings.Hooks.stateDirectory, "/tmp/codestation")
    }

    // MARK: - Icons

    func testIconsAreNonEmpty() {
        XCTAssertFalse(Strings.Icons.plus.isEmpty)
        XCTAssertFalse(Strings.Icons.plusCircle.isEmpty)
        XCTAssertFalse(Strings.Icons.xmark.isEmpty)
        XCTAssertFalse(Strings.Icons.terminal.isEmpty)
        XCTAssertFalse(Strings.Icons.grid.isEmpty)
        XCTAssertFalse(Strings.Icons.gear.isEmpty)
    }
}
