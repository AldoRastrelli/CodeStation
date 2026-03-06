import XCTest
@testable import CodeStation

final class BoardViewModelTests: XCTestCase {

    private func makeSUT() -> BoardViewModel {
        let vm = BoardViewModel()
        vm.environmentID = UUID()
        return vm
    }

    // MARK: - Initial State

    func testInitialState() {
        let vm = makeSUT()
        XCTAssertTrue(vm.sessions.isEmpty)
        XCTAssertTrue(vm.canAddSession)
        XCTAssertFalse(vm.useGridLayout)
        XCTAssertEqual(vm.gridColumns, 4)
        XCTAssertEqual(vm.gridRows, 1)
        XCTAssertNil(vm.focusedSessionID)
        XCTAssertFalse(vm.hasUnseenNotification)
        XCTAssertTrue(vm.unseenNotificationSessionIDs.isEmpty)
        XCTAssertEqual(vm.columnProportions.count, 4)
        XCTAssertEqual(vm.rowProportion, 0.5)
    }

    // MARK: - Add Session

    func testAddSession() {
        let vm = makeSUT()
        let session = vm.addSession()
        XCTAssertNotNil(session)
        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(session?.gridIndex, 0)
    }

    func testAddMultipleSessions() {
        let vm = makeSUT()
        for i in 0..<4 {
            let session = vm.addSession()
            XCTAssertNotNil(session)
            XCTAssertEqual(session?.gridIndex, i)
        }
        XCTAssertEqual(vm.sessions.count, 4)
    }

    func testAddSessionCallsOnStateChanged() {
        let vm = makeSUT()
        var called = false
        vm.onStateChanged = { called = true }
        _ = vm.addSession()
        XCTAssertTrue(called)
    }

    func testCannotAddBeyondMax() {
        let vm = makeSUT()
        for _ in 0..<BoardViewModel.maxSessions {
            _ = vm.addSession()
        }
        XCTAssertFalse(vm.canAddSession)
        let extra = vm.addSession()
        XCTAssertNil(extra)
        XCTAssertEqual(vm.sessions.count, BoardViewModel.maxSessions)
    }

    func testMaxSessionsIs8() {
        XCTAssertEqual(BoardViewModel.maxSessions, 8)
    }

    // MARK: - Add Session At Position

    func testAddSessionAtPosition() {
        let vm = makeSUT()
        let session = vm.addSessionAt(row: 1, col: 2)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.gridIndex, 6) // 1 * 4 + 2
    }

    func testAddSessionAtPositionCallsOnStateChanged() {
        let vm = makeSUT()
        var called = false
        vm.onStateChanged = { called = true }
        _ = vm.addSessionAt(row: 0, col: 0)
        XCTAssertTrue(called)
    }

    // MARK: - Remove Session

    func testRemoveSession() {
        let vm = makeSUT()
        let session = vm.addSession()!
        vm.removeSession(session)
        XCTAssertTrue(vm.sessions.isEmpty)
        XCTAssertNil(vm.focusedSessionID)
    }

    func testRemoveSessionFocusesPrevious() {
        let vm = makeSUT()
        let s1 = vm.addSession()!
        let _ = vm.addSession()!
        let s3 = vm.addSession()!

        vm.removeSession(s3)
        // Should focus the session before the removed one
        XCTAssertEqual(vm.sessions.count, 2)
        // focusedSessionID should be set to one of the remaining sessions
        XCTAssertNotNil(vm.focusedSessionID)
    }

    func testRemoveSessionCallsOnStateChanged() {
        let vm = makeSUT()
        let session = vm.addSession()!
        var called = false
        vm.onStateChanged = { called = true }
        vm.removeSession(session)
        XCTAssertTrue(called)
    }

    func testRemoveSessionClearsUnseenNotification() {
        let vm = makeSUT()
        let session = vm.addSession()!
        vm.unseenNotificationSessionIDs.insert(session.id)
        XCTAssertTrue(vm.hasUnseenNotification)

        vm.removeSession(session)
        XCTAssertFalse(vm.hasUnseenNotification)
    }

    func testRemoveFirstSessionFocusesNextAvailable() {
        let vm = makeSUT()
        let s1 = vm.addSession()!
        let s2 = vm.addSession()!

        vm.removeSession(s1)
        XCTAssertEqual(vm.focusedSessionID, s2.id)
    }

    // MARK: - Restore Session

    func testRestoreSession() {
        let vm = makeSUT()
        let snapshot = SessionSnapshot(
            gridIndex: 2,
            title: "Restored",
            userEditedTitle: true,
            sessionDescription: "desc",
            currentDirectory: "/tmp"
        )

        let session = vm.addSession(restoring: snapshot)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.gridIndex, 2)
        XCTAssertEqual(session?.title, "Restored")
        XCTAssertEqual(session?.isUserEditedTitle, true)
        XCTAssertEqual(session?.sessionDescription, "desc")
        XCTAssertEqual(session?.currentDirectory, "/tmp")
    }

    func testRestorePendingSessions() {
        let vm = makeSUT()
        vm.pendingRestores = [
            SessionSnapshot(gridIndex: 0, title: "T1", userEditedTitle: false, sessionDescription: "", currentDirectory: nil),
            SessionSnapshot(gridIndex: 1, title: "T2", userEditedTitle: false, sessionDescription: "", currentDirectory: nil),
        ]

        vm.restorePendingSessions()
        XCTAssertEqual(vm.sessions.count, 2)
        XCTAssertTrue(vm.pendingRestores.isEmpty)
    }

    func testRestorePendingSessionsDoesNothingWhenEmpty() {
        let vm = makeSUT()
        vm.restorePendingSessions()
        XCTAssertTrue(vm.sessions.isEmpty)
    }

    // MARK: - Grid Layout

    func testUseGridLayoutFalseFor4OrFewer() {
        let vm = makeSUT()
        for _ in 0..<4 {
            _ = vm.addSession()
        }
        XCTAssertFalse(vm.useGridLayout)
        XCTAssertEqual(vm.gridRows, 1)
    }

    func testUseGridLayoutTrueForMoreThan4() {
        let vm = makeSUT()
        for _ in 0..<5 {
            _ = vm.addSession()
        }
        XCTAssertTrue(vm.useGridLayout)
        XCTAssertEqual(vm.gridRows, 2)
    }

    // MARK: - Grid Query

    func testSessionAtPosition() {
        let vm = makeSUT()
        let session = vm.addSessionAt(row: 0, col: 1)!
        XCTAssertEqual(vm.sessionAt(row: 0, col: 1)?.id, session.id)
        XCTAssertNil(vm.sessionAt(row: 0, col: 0))
    }

    func testIsSlotEmpty() {
        let vm = makeSUT()
        XCTAssertTrue(vm.isSlotEmpty(row: 0, col: 0))
        _ = vm.addSessionAt(row: 0, col: 0)
        XCTAssertFalse(vm.isSlotEmpty(row: 0, col: 0))
        XCTAssertTrue(vm.isSlotEmpty(row: 0, col: 1))
    }

    // MARK: - Move Session

    func testMoveSession() {
        let vm = makeSUT()
        let session = vm.addSession()!
        let originalIndex = session.gridIndex
        XCTAssertEqual(originalIndex, 0)

        let result = vm.moveSession(sourceID: session.id, toGridIndex: 3)
        XCTAssertTrue(result)
        XCTAssertEqual(session.gridIndex, 3)
    }

    func testMoveSessionCallsOnStateChanged() {
        let vm = makeSUT()
        let session = vm.addSession()!
        var called = false
        vm.onStateChanged = { called = true }
        _ = vm.moveSession(sourceID: session.id, toGridIndex: 2)
        XCTAssertTrue(called)
    }

    func testMoveNonExistentSessionReturnsFalse() {
        let vm = makeSUT()
        let result = vm.moveSession(sourceID: UUID(), toGridIndex: 0)
        XCTAssertFalse(result)
    }

    // MARK: - Swap Sessions

    func testSwapSessions() {
        let vm = makeSUT()
        let s1 = vm.addSessionAt(row: 0, col: 0)!
        let s2 = vm.addSessionAt(row: 0, col: 1)!

        let result = vm.swapSessions(sourceID: s1.id, targetGridIndex: s2.gridIndex)
        XCTAssertTrue(result)
        XCTAssertEqual(s1.gridIndex, 1)
        XCTAssertEqual(s2.gridIndex, 0)
    }

    func testSwapSessionsSameSessionReturnsFalse() {
        let vm = makeSUT()
        let session = vm.addSession()!
        let result = vm.swapSessions(sourceID: session.id, targetGridIndex: session.gridIndex)
        XCTAssertFalse(result)
    }

    func testSwapSessionsNonExistentTargetReturnsFalse() {
        let vm = makeSUT()
        let session = vm.addSession()!
        let result = vm.swapSessions(sourceID: session.id, targetGridIndex: 99)
        XCTAssertFalse(result)
    }

    func testSwapSessionsNonExistentSourceReturnsFalse() {
        let vm = makeSUT()
        _ = vm.addSession()!
        let result = vm.swapSessions(sourceID: UUID(), targetGridIndex: 0)
        XCTAssertFalse(result)
    }

    // MARK: - Unseen Notifications

    func testHasUnseenNotificationWhenEmpty() {
        let vm = makeSUT()
        XCTAssertFalse(vm.hasUnseenNotification)
    }

    func testHasUnseenNotificationWhenSessionAdded() {
        let vm = makeSUT()
        let sessionID = UUID()
        vm.unseenNotificationSessionIDs.insert(sessionID)
        XCTAssertTrue(vm.hasUnseenNotification)
    }

    func testFocusingSessionClearsItsNotification() {
        let vm = makeSUT()
        let session = vm.addSession()!
        vm.unseenNotificationSessionIDs.insert(session.id)
        XCTAssertTrue(vm.hasUnseenNotification)

        vm.focusedSessionID = session.id
        XCTAssertFalse(vm.hasUnseenNotification)
    }

    func testFocusingSessionOnlyClearsOwnNotification() {
        let vm = makeSUT()
        let s1 = vm.addSession()!
        let s2 = vm.addSession()!
        vm.unseenNotificationSessionIDs.insert(s1.id)
        vm.unseenNotificationSessionIDs.insert(s2.id)

        vm.focusedSessionID = s1.id
        XCTAssertTrue(vm.hasUnseenNotification) // s2 still has notification
        XCTAssertFalse(vm.unseenNotificationSessionIDs.contains(s1.id))
        XCTAssertTrue(vm.unseenNotificationSessionIDs.contains(s2.id))
    }

    func testSettingFocusedSessionIDToNilDoesNotCrash() {
        let vm = makeSUT()
        vm.focusedSessionID = nil
        XCTAssertNil(vm.focusedSessionID)
    }

    // MARK: - Notification Fired Callback

    func testOnNotificationFiredInsertsSessionID() {
        let vm = makeSUT()
        let session = vm.addSession()!
        let sessionVM = vm.viewModel(for: session)

        // Trigger the notification callback
        sessionVM.onNotificationFired?()

        XCTAssertTrue(vm.unseenNotificationSessionIDs.contains(session.id))
        XCTAssertTrue(vm.hasUnseenNotification)
    }

    // MARK: - Child ViewModel

    func testViewModelForSessionReturnsSameInstance() {
        let vm = makeSUT()
        let session = vm.addSession()!
        let vm1 = vm.viewModel(for: session)
        let vm2 = vm.viewModel(for: session)
        XCTAssertTrue(vm1 === vm2)
    }

    func testViewModelForSessionSetsEnvironmentID() {
        let envID = UUID()
        let vm = BoardViewModel()
        vm.environmentID = envID
        let session = vm.addSession()!
        let sessionVM = vm.viewModel(for: session)
        XCTAssertEqual(sessionVM.environmentID, envID)
    }

    func testViewModelStateChangedBubbles() {
        let vm = makeSUT()
        let session = vm.addSession()!
        var parentCalled = false
        vm.onStateChanged = { parentCalled = true }

        let sessionVM = vm.viewModel(for: session)
        sessionVM.onStateChanged?()
        XCTAssertTrue(parentCalled)
    }

    // MARK: - Next Available Index

    func testNextAvailableIndexFillsGaps() {
        let vm = makeSUT()
        _ = vm.addSession() // index 0
        let s2 = vm.addSession()! // index 1
        _ = vm.addSession() // index 2

        vm.removeSession(s2) // frees index 1

        let newSession = vm.addSession()
        XCTAssertEqual(newSession?.gridIndex, 1) // should fill the gap
    }

    // MARK: - Column / Row Proportions

    func testDefaultColumnProportions() {
        let vm = makeSUT()
        XCTAssertEqual(vm.columnProportions, [0.25, 0.25, 0.25, 0.25])
    }

    func testDefaultRowProportion() {
        let vm = makeSUT()
        XCTAssertEqual(vm.rowProportion, 0.5)
    }

    func testColumnProportionsCanBeModified() {
        let vm = makeSUT()
        vm.columnProportions = [0.3, 0.2, 0.3, 0.2]
        XCTAssertEqual(vm.columnProportions, [0.3, 0.2, 0.3, 0.2])
    }

    func testRowProportionCanBeModified() {
        let vm = makeSUT()
        vm.rowProportion = 0.7
        XCTAssertEqual(vm.rowProportion, 0.7)
    }
}
