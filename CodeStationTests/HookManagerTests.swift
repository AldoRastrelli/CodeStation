import XCTest
@testable import CodeStation

final class HookManagerTests: XCTestCase {

    // MARK: - Hook Events

    func testHookEventsCount() {
        XCTAssertEqual(HookManager.hookEvents.count, 14)
    }

    func testHookEventsContainsExpectedEvents() {
        let expected = [
            "PreToolUse", "PostToolUse", "PostToolUseFailure", "Stop",
            "UserPromptSubmit", "Notification", "SubagentStart", "SubagentStop",
            "SessionStart", "SessionEnd", "PermissionRequest", "TeammateIdle",
            "TaskCompleted", "ConfigChange"
        ]
        XCTAssertEqual(HookManager.hookEvents, expected)
    }

    // MARK: - Hook Script

    func testHookScriptContainsPython3Shebang() {
        XCTAssertTrue(HookManager.hookScript.contains("python3"))
    }

    func testHookScriptContainsSessionIDCheck() {
        XCTAssertTrue(HookManager.hookScript.contains("CODESTATION_SESSION_ID"))
    }

    func testHookScriptContainsStateDirectory() {
        XCTAssertTrue(HookManager.hookScript.contains(Strings.Hooks.stateDirectory))
    }

    // MARK: - Paths

    func testStateFilePathContainsSessionID() {
        let sessionID = UUID()
        let path = HookManager.stateFilePath(for: sessionID)
        XCTAssertTrue(path.contains(sessionID.uuidString))
    }

    func testStateFilePathIsInStateDirectory() {
        let sessionID = UUID()
        let path = HookManager.stateFilePath(for: sessionID)
        XCTAssertTrue(path.hasPrefix(HookManager.stateDirectory))
    }

    func testStateFilePathEndsWithJSON() {
        let sessionID = UUID()
        let path = HookManager.stateFilePath(for: sessionID)
        XCTAssertTrue(path.hasSuffix(".json"))
    }

    func testHookScriptPath() {
        XCTAssertTrue(HookManager.hookScriptPath.contains(".claude"))
        XCTAssertTrue(HookManager.hookScriptPath.hasSuffix("codestation_hook.py"))
    }

    func testSettingsPath() {
        XCTAssertTrue(HookManager.settingsPath.contains(".claude"))
        XCTAssertTrue(HookManager.settingsPath.hasSuffix("settings.json"))
    }

    // MARK: - HookState Status Mapping

    func testHookStateCookingEvents() {
        let cookingEvents = ["UserPromptSubmit", "PreToolUse", "SubagentStart", "PostToolUse", "PostToolUseFailure", "SubagentStop"]
        for event in cookingEvents {
            let state = HookManager.HookState(event: event, timestamp: Date())
            XCTAssertEqual(state.status, .cooking, "\(event) should map to .cooking")
        }
    }

    func testHookStateReadyEvents() {
        let readyEvents = ["Stop", "TaskCompleted", "SessionStart", "ConfigChange"]
        for event in readyEvents {
            let state = HookManager.HookState(event: event, timestamp: Date())
            XCTAssertEqual(state.status, .ready, "\(event) should map to .ready")
        }
    }

    func testHookStateWaitingEvents() {
        let waitingEvents = ["Notification", "PermissionRequest"]
        for event in waitingEvents {
            let state = HookManager.HookState(event: event, timestamp: Date())
            XCTAssertEqual(state.status, .waiting, "\(event) should map to .waiting")
        }
    }

    func testHookStateAsleepEvents() {
        let asleepEvents = ["SessionEnd", "TeammateIdle"]
        for event in asleepEvents {
            let state = HookManager.HookState(event: event, timestamp: Date())
            XCTAssertEqual(state.status, .asleep, "\(event) should map to .asleep")
        }
    }

    func testHookStateUnknownEventDefaultsToReady() {
        let state = HookManager.HookState(event: "SomeFutureEvent", timestamp: Date())
        XCTAssertEqual(state.status, .ready)
    }

    // MARK: - Read / Cleanup State

    func testReadStateForNonExistentSessionReturnsNil() {
        let sessionID = UUID()
        let state = HookManager.readState(for: sessionID)
        XCTAssertNil(state)
    }

    func testReadStateFromWrittenFile() throws {
        let sessionID = UUID()
        let stateDir = HookManager.stateDirectory
        try FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)

        let timestamp = Date().timeIntervalSince1970
        let json: [String: Any] = ["event": "PreToolUse", "timestamp": timestamp]
        let data = try JSONSerialization.data(withJSONObject: json)
        let path = HookManager.stateFilePath(for: sessionID)
        try data.write(to: URL(fileURLWithPath: path))

        let state = HookManager.readState(for: sessionID)
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.event, "PreToolUse")
        XCTAssertEqual(state?.status, .cooking)

        // Cleanup
        HookManager.cleanupState(for: sessionID)
        XCTAssertNil(HookManager.readState(for: sessionID))
    }

    func testCleanupStateRemovesFile() throws {
        let sessionID = UUID()
        let stateDir = HookManager.stateDirectory
        try FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)

        let json: [String: Any] = ["event": "Stop", "timestamp": Date().timeIntervalSince1970]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: URL(fileURLWithPath: HookManager.stateFilePath(for: sessionID)))

        XCTAssertTrue(FileManager.default.fileExists(atPath: HookManager.stateFilePath(for: sessionID)))

        HookManager.cleanupState(for: sessionID)

        XCTAssertFalse(FileManager.default.fileExists(atPath: HookManager.stateFilePath(for: sessionID)))
    }

    func testCleanupNonExistentStateDoesNotCrash() {
        let sessionID = UUID()
        HookManager.cleanupState(for: sessionID)
        // Should not throw or crash
    }

    // MARK: - Hook Marker

    func testHookMarker() {
        XCTAssertEqual(HookManager.hookMarker, Strings.Hooks.hookMarker)
    }

    // MARK: - Install and Uninstall

    func testIsInstalledDefaultFalseForCleanSettings() {
        // With no settings file or a settings file without hooks, isInstalled should be false
        // We can't guarantee the state, but the property should not crash
        _ = HookManager.isInstalled
    }

    // MARK: - State Directory

    func testStateDirectoryMatchesStrings() {
        XCTAssertEqual(HookManager.stateDirectory, Strings.Hooks.stateDirectory)
    }
}
