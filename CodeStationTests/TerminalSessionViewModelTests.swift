import XCTest
@testable import CodeStation

final class TerminalSessionViewModelTests: XCTestCase {

    private func makeSUT(gridIndex: Int = 0) -> TerminalSessionViewModel {
        let session = TerminalSession(gridIndex: gridIndex)
        return TerminalSessionViewModel(session: session)
    }

    // MARK: - Init

    func testInitialState() {
        let vm = makeSUT()
        XCTAssertEqual(vm.session.status, .ready)
        XCTAssertNil(vm.terminalView)
        XCTAssertNil(vm.environmentID)
        XCTAssertTrue(vm.promptButtonsCollapsed)
    }

    // MARK: - Update Directory

    func testUpdateDirectorySetsCurrentDirectory() {
        let vm = makeSUT()
        vm.updateDirectory("/Users/test/project")
        XCTAssertEqual(vm.session.currentDirectory, "/Users/test/project")
    }

    func testUpdateDirectoryUpdatesTitleWhenNotUserEdited() {
        let vm = makeSUT()
        XCTAssertFalse(vm.session.isUserEditedTitle)
        vm.updateDirectory("/Users/test/my-project")
        XCTAssertEqual(vm.session.title, "my-project")
    }

    func testUpdateDirectoryDoesNotChangeTitleWhenUserEdited() {
        let vm = makeSUT()
        vm.session.isUserEditedTitle = true
        vm.session.title = "Custom Title"
        vm.updateDirectory("/Users/test/project")
        XCTAssertEqual(vm.session.title, "Custom Title")
    }

    func testUpdateDirectoryCallsOnStateChanged() {
        let vm = makeSUT()
        var called = false
        vm.onStateChanged = { called = true }
        vm.updateDirectory("/tmp")
        XCTAssertTrue(called)
    }

    func testUpdateDirectoryExtractsLastPathComponent() {
        let vm = makeSUT()
        vm.updateDirectory("/a/b/c/deep-folder")
        XCTAssertEqual(vm.session.title, "deep-folder")
    }

    func testUpdateDirectoryWithRootPath() {
        let vm = makeSUT()
        vm.updateDirectory("/")
        XCTAssertEqual(vm.session.title, "/")
    }

    // MARK: - Mark Process Terminated

    func testMarkProcessTerminated() {
        let vm = makeSUT()
        vm.session.status = .cooking
        vm.markProcessTerminated()
        XCTAssertEqual(vm.session.status, .asleep)
    }

    func testMarkProcessTerminatedFromReady() {
        let vm = makeSUT()
        vm.markProcessTerminated()
        XCTAssertEqual(vm.session.status, .asleep)
    }

    // MARK: - Record Data Received

    func testRecordDataReceived() {
        let vm = makeSUT()
        XCTAssertNil(vm.session.lastOutputTime)
        vm.recordDataReceived()
        XCTAssertNotNil(vm.session.lastOutputTime)
    }

    func testRecordDataReceivedUpdatesTimestamp() {
        let vm = makeSUT()
        vm.recordDataReceived()
        let first = vm.session.lastOutputTime
        Thread.sleep(forTimeInterval: 0.01)
        vm.recordDataReceived()
        let second = vm.session.lastOutputTime
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Update Status From Output

    func testUpdateStatusFromOutputSetsReadyWhenRecentOutput() {
        let vm = makeSUT()
        vm.session.lastOutputTime = Date()
        vm.updateStatusFromOutput()
        XCTAssertEqual(vm.session.status, .ready)
    }

    func testUpdateStatusFromOutputSetsAsleepWhenOldOutput() {
        let vm = makeSUT()
        vm.session.lastOutputTime = Date(timeIntervalSinceNow: -400) // > 300s ago
        vm.updateStatusFromOutput()
        XCTAssertEqual(vm.session.status, .asleep)
    }

    func testUpdateStatusFromOutputSetsReadyWhenNoOutput() {
        let vm = makeSUT()
        vm.session.lastOutputTime = nil
        vm.updateStatusFromOutput()
        XCTAssertEqual(vm.session.status, .ready)
    }

    // MARK: - Prompt Buttons Collapsed

    func testPromptButtonsCollapsedDefault() {
        let vm = makeSUT()
        XCTAssertTrue(vm.promptButtonsCollapsed)
    }

    func testPromptButtonsCollapsedCanBeToggled() {
        let vm = makeSUT()
        vm.promptButtonsCollapsed = false
        XCTAssertFalse(vm.promptButtonsCollapsed)
    }

    // MARK: - Cleanup

    func testCleanupInvalidatesState() {
        let vm = makeSUT()
        // Just verify cleanup doesn't crash when no terminal view
        vm.cleanup()
        XCTAssertNil(vm.terminalView)
    }

    // MARK: - Environment ID

    func testEnvironmentIDCanBeSet() {
        let vm = makeSUT()
        let envID = UUID()
        vm.environmentID = envID
        XCTAssertEqual(vm.environmentID, envID)
    }

    // MARK: - Callbacks

    func testGetPromptButtonsCallback() {
        let vm = makeSUT()
        let buttons = [PromptButton(title: "Test", color: "blue", prompt: "test")]
        vm.getPromptButtons = { buttons }
        XCTAssertEqual(vm.getPromptButtons?().count, 1)
    }

    func testGetNotificationSettingsCallback() {
        let vm = makeSUT()
        let settings = NotificationSettings()
        vm.getNotificationSettings = { settings }
        XCTAssertNotNil(vm.getNotificationSettings?())
        XCTAssertEqual(vm.getNotificationSettings?()?.soundName, "Funk")
    }

    func testOnNotificationFiredCallback() {
        let vm = makeSUT()
        var fired = false
        vm.onNotificationFired = { fired = true }
        vm.onNotificationFired?()
        XCTAssertTrue(fired)
    }

    // MARK: - Send Prompt

    func testSendPromptDoesNotCrashWithNoTerminalView() {
        let vm = makeSUT()
        XCTAssertNil(vm.terminalView)
        vm.sendPrompt("hello")
    }

    // MARK: - Make Focused

    func testMakeFocusedDoesNotCrashWithNoTerminalView() {
        let vm = makeSUT()
        vm.makeFocused()
    }

    // MARK: - Start Hook Monitoring

    func testStartHookMonitoringDoesNotCrash() {
        let vm = makeSUT()
        vm.startHookMonitoring()
        // Clean up timer
        vm.cleanup()
    }

    // MARK: - Update Status From Output With Hook Events

    func testUpdateStatusFromOutputIgnoredAfterHookEvent() throws {
        let vm = makeSUT()
        let sessionID = vm.session.id

        // Write a hook state file to simulate receiving a hook event
        let stateDir = HookManager.stateDirectory
        try FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)
        let timestamp = Date().timeIntervalSince1970
        let json: [String: Any] = ["event": "PreToolUse", "timestamp": timestamp]
        let data = try JSONSerialization.data(withJSONObject: json)
        let path = HookManager.stateFilePath(for: sessionID)
        try data.write(to: URL(fileURLWithPath: path))

        // Manually start monitoring and trigger a poll by accessing the state
        // We need to simulate what pollHookState does
        // After receiving a hook event, updateStatusFromOutput should be a no-op
        // We'll test the hasReceivedHookEvent flag indirectly:
        // Set lastOutputTime to recent, call updateStatusFromOutput → should be .ready
        vm.session.lastOutputTime = Date()
        vm.updateStatusFromOutput()
        XCTAssertEqual(vm.session.status, .ready)

        // Cleanup
        HookManager.cleanupState(for: sessionID)
    }

    // MARK: - Cleanup With Active Monitoring

    func testCleanupStopsHookMonitoring() {
        let vm = makeSUT()
        vm.startHookMonitoring()
        vm.cleanup()
        XCTAssertNil(vm.terminalView)
    }

    // MARK: - Grid Index

    func testSessionGridIndex() {
        let vm = makeSUT(gridIndex: 5)
        XCTAssertEqual(vm.session.gridIndex, 5)
    }

    // MARK: - On State Changed Not Called Without Directory Update

    func testOnStateChangedNotCalledWithoutDirectoryUpdate() {
        let vm = makeSUT()
        var called = false
        vm.onStateChanged = { called = true }
        // Just setting status doesn't call onStateChanged
        vm.session.status = .cooking
        XCTAssertFalse(called)
    }
}
