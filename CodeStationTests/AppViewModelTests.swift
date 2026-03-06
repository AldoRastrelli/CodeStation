import XCTest
@testable import CodeStation

final class AppViewModelTests: XCTestCase {

    // Note: AppViewModel's init() loads from disk and sets up observers.
    // We test the public API behavior after initialization.

    private func makeSUT() -> AppViewModel {
        return AppViewModel()
    }

    // MARK: - Initial State

    func testHasAtLeastOneEnvironment() {
        let vm = makeSUT()
        XCTAssertFalse(vm.environments.isEmpty)
    }

    func testHasSelectedEnvironment() {
        let vm = makeSUT()
        XCTAssertNotNil(vm.selectedEnvironmentID)
    }

    func testDefaultFontSize() {
        XCTAssertEqual(AppViewModel.defaultFontSize, 13)
    }

    func testFontSizeBounds() {
        XCTAssertEqual(AppViewModel.minFontSize, 8)
        XCTAssertEqual(AppViewModel.maxFontSize, 32)
    }

    // MARK: - Zoom

    func testZoomIn() {
        let vm = makeSUT()
        let initial = vm.fontSize
        vm.zoomIn()
        XCTAssertEqual(vm.fontSize, initial + 1)
    }

    func testZoomOut() {
        let vm = makeSUT()
        let initial = vm.fontSize
        vm.zoomOut()
        XCTAssertEqual(vm.fontSize, initial - 1)
    }

    func testZoomReset() {
        let vm = makeSUT()
        vm.zoomIn()
        vm.zoomIn()
        vm.zoomReset()
        XCTAssertEqual(vm.fontSize, AppViewModel.defaultFontSize)
    }

    func testZoomInDoesNotExceedMax() {
        let vm = makeSUT()
        vm.fontSize = AppViewModel.maxFontSize
        vm.zoomIn()
        XCTAssertEqual(vm.fontSize, AppViewModel.maxFontSize)
    }

    func testZoomOutDoesNotGoBelowMin() {
        let vm = makeSUT()
        vm.fontSize = AppViewModel.minFontSize
        vm.zoomOut()
        XCTAssertEqual(vm.fontSize, AppViewModel.minFontSize)
    }

    func testZoomInRepeatedlyReachesMax() {
        let vm = makeSUT()
        for _ in 0..<100 {
            vm.zoomIn()
        }
        XCTAssertEqual(vm.fontSize, AppViewModel.maxFontSize)
    }

    func testZoomOutRepeatedlyReachesMin() {
        let vm = makeSUT()
        for _ in 0..<100 {
            vm.zoomOut()
        }
        XCTAssertEqual(vm.fontSize, AppViewModel.minFontSize)
    }

    // MARK: - Environment CRUD

    func testAddEnvironment() {
        let vm = makeSUT()
        let initialCount = vm.environments.count
        let env = vm.addEnvironment(name: "Test Env")
        XCTAssertEqual(vm.environments.count, initialCount + 1)
        XCTAssertEqual(env.name, "Test Env")
        XCTAssertEqual(vm.selectedEnvironmentID, env.id)
    }

    func testAddEnvironmentDefaultName() {
        let vm = makeSUT()
        let count = vm.environments.count
        let env = vm.addEnvironment()
        XCTAssertTrue(env.name.contains("Environment"))
        XCTAssertEqual(vm.environments.count, count + 1)
    }

    func testAddEnvironmentSetsSelection() {
        let vm = makeSUT()
        let env = vm.addEnvironment(name: "New")
        XCTAssertEqual(vm.selectedEnvironmentID, env.id)
    }

    func testRemoveEnvironment() {
        let vm = makeSUT()
        let env = vm.addEnvironment(name: "ToRemove")
        let countBefore = vm.environments.count
        vm.removeEnvironment(env)
        XCTAssertEqual(vm.environments.count, countBefore - 1)
        XCTAssertFalse(vm.environments.contains { $0.id == env.id })
    }

    func testRemoveSelectedEnvironmentUpdatesSelection() {
        let vm = makeSUT()
        let env1 = vm.addEnvironment(name: "A")
        let _ = vm.addEnvironment(name: "B")
        vm.selectedEnvironmentID = env1.id
        vm.removeEnvironment(env1)
        XCTAssertNotEqual(vm.selectedEnvironmentID, env1.id)
    }

    func testRenameEnvironment() {
        let vm = makeSUT()
        let env = vm.addEnvironment(name: "Original")
        vm.renameEnvironment(env, to: "Renamed")
        XCTAssertEqual(env.name, "Renamed")
    }

    // MARK: - Sorted Environments

    func testSortedEnvironments() {
        let vm = makeSUT()
        // Remove existing environments first
        for env in vm.environments {
            vm.removeEnvironment(env)
        }
        let e1 = vm.addEnvironment(name: "C")
        let e2 = vm.addEnvironment(name: "A")
        let e3 = vm.addEnvironment(name: "B")

        // Sort order is by sortOrder, not name
        let sorted = vm.sortedEnvironments
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].id, e1.id)
        XCTAssertEqual(sorted[1].id, e2.id)
        XCTAssertEqual(sorted[2].id, e3.id)
    }

    // MARK: - Board ViewModel

    func testBoardViewModelForEnvironment() {
        let vm = makeSUT()
        guard let env = vm.environments.first else {
            XCTFail("Should have at least one environment")
            return
        }
        let boardVM = vm.boardViewModel(for: env)
        XCTAssertNotNil(boardVM)
        XCTAssertEqual(boardVM.environmentID, env.id)
    }

    func testBoardViewModelReturnsSameInstance() {
        let vm = makeSUT()
        guard let env = vm.environments.first else {
            XCTFail()
            return
        }
        let vm1 = vm.boardViewModel(for: env)
        let vm2 = vm.boardViewModel(for: env)
        XCTAssertTrue(vm1 === vm2)
    }

    func testBoardViewModelCallbacksAreWired() {
        let vm = makeSUT()
        guard let env = vm.environments.first else {
            XCTFail()
            return
        }
        let boardVM = vm.boardViewModel(for: env)
        XCTAssertNotNil(boardVM.getNotificationSettings)
        XCTAssertNotNil(boardVM.getPromptButtons)
        XCTAssertNotNil(boardVM.onAddPromptButton)
        XCTAssertNotNil(boardVM.onUpdatePromptButton)
        XCTAssertNotNil(boardVM.onDeletePromptButton)
        XCTAssertNotNil(boardVM.onStateChanged)
    }

    // MARK: - Prompt Button Callbacks

    func testOnAddPromptButton() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)

        let initialCount = vm.promptButtons.count
        let button = PromptButton(title: "New", color: "blue", prompt: "test")
        boardVM.onAddPromptButton?(button)

        XCTAssertEqual(vm.promptButtons.count, initialCount + 1)
        XCTAssertEqual(vm.promptButtons.last?.title, "New")
    }

    func testOnUpdatePromptButton() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)

        let button = PromptButton(title: "Original", color: "blue", prompt: "test")
        vm.promptButtons.append(button)

        var updated = button
        updated.title = "Updated"
        boardVM.onUpdatePromptButton?(updated)

        XCTAssertEqual(vm.promptButtons.first(where: { $0.id == button.id })?.title, "Updated")
    }

    func testOnDeletePromptButton() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)

        let button = PromptButton(title: "ToDelete", color: "red", prompt: "test")
        vm.promptButtons.append(button)

        boardVM.onDeletePromptButton?(button.id)

        XCTAssertFalse(vm.promptButtons.contains { $0.id == button.id })
    }

    // MARK: - Terminal Navigation

    func testAddTerminalOrEnvironment() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let initialCount = boardVM.sessions.count

        vm.addTerminalOrEnvironment()
        XCTAssertEqual(boardVM.sessions.count, initialCount + 1)
    }

    func testAddTerminalOrEnvironmentCreatesNewEnvWhenFull() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)

        // Fill to max
        for _ in 0..<BoardViewModel.maxSessions {
            _ = boardVM.addSession()
        }

        let envCountBefore = vm.environments.count
        vm.addTerminalOrEnvironment()
        XCTAssertEqual(vm.environments.count, envCountBefore + 1)
    }

    // MARK: - Focus Navigation

    func testFocusEnvironmentDown() {
        let vm = makeSUT()
        let env1 = vm.environments.first!
        let env2 = vm.addEnvironment(name: "Second")
        vm.selectedEnvironmentID = env1.id

        vm.focusEnvironmentDown()
        XCTAssertEqual(vm.selectedEnvironmentID, env2.id)
    }

    func testFocusEnvironmentUp() {
        let vm = makeSUT()
        let env1 = vm.environments.first!
        let env2 = vm.addEnvironment(name: "Second")
        vm.selectedEnvironmentID = env2.id

        vm.focusEnvironmentUp()
        XCTAssertEqual(vm.selectedEnvironmentID, env1.id)
    }

    func testFocusEnvironmentDownWrapsAround() {
        let vm = makeSUT()
        // Remove extra environments
        while vm.environments.count > 1 {
            vm.removeEnvironment(vm.environments.last!)
        }
        let env1 = vm.environments.first!
        let env2 = vm.addEnvironment(name: "Second")
        vm.selectedEnvironmentID = env2.id

        vm.focusEnvironmentDown()
        XCTAssertEqual(vm.selectedEnvironmentID, env1.id)
    }

    func testFocusEnvironmentUpWrapsAround() {
        let vm = makeSUT()
        while vm.environments.count > 1 {
            vm.removeEnvironment(vm.environments.last!)
        }
        let env1 = vm.environments.first!
        let env2 = vm.addEnvironment(name: "Second")
        vm.selectedEnvironmentID = env1.id

        vm.focusEnvironmentUp()
        XCTAssertEqual(vm.selectedEnvironmentID, env2.id)
    }

    // MARK: - Close Focused Terminal

    func testFocusedTerminalTitle() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let session = boardVM.addSession()!
        boardVM.focusedSessionID = session.id

        XCTAssertEqual(vm.focusedTerminalTitle, session.title)
    }

    func testFocusedTerminalTitleNilWhenNoFocus() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        boardVM.focusedSessionID = nil

        XCTAssertNil(vm.focusedTerminalTitle)
    }

    func testCloseFocusedTerminal() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let session = boardVM.addSession()!
        boardVM.focusedSessionID = session.id

        let countBefore = boardVM.sessions.count
        vm.closeFocusedTerminal()
        XCTAssertEqual(boardVM.sessions.count, countBefore - 1)
    }

    // MARK: - Navigation

    func testNavigateToSession() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let session = boardVM.addSession()!

        vm.navigateToSession(environmentID: env.id, sessionID: session.id)
        XCTAssertEqual(vm.selectedEnvironmentID, env.id)
        XCTAssertEqual(boardVM.focusedSessionID, session.id)
    }

    // MARK: - Skip Close Confirmation

    func testSkipCloseConfirmationDefault() {
        let vm = makeSUT()
        // Default depends on persisted state, just verify it's accessible
        _ = vm.skipCloseConfirmation
    }

    func testSkipCloseConfirmationViaCallback() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)

        boardVM.onSkipCloseConfirmationChanged?(true)
        XCTAssertTrue(vm.skipCloseConfirmation)

        boardVM.onSkipCloseConfirmationChanged?(false)
        XCTAssertFalse(vm.skipCloseConfirmation)
    }

    // MARK: - Selected Environment

    func testSelectedEnvironment() {
        let vm = makeSUT()
        let env = vm.environments.first!
        vm.selectedEnvironmentID = env.id
        XCTAssertEqual(vm.selectedEnvironment?.id, env.id)
    }

    func testSelectedEnvironmentNilWhenNoMatch() {
        let vm = makeSUT()
        vm.selectedEnvironmentID = UUID()
        XCTAssertNil(vm.selectedEnvironment)
    }

    func testSelectedEnvironmentNilWhenNilID() {
        let vm = makeSUT()
        vm.selectedEnvironmentID = nil
        XCTAssertNil(vm.selectedEnvironment)
    }

    // MARK: - Focus Terminal Left/Right

    func testFocusTerminalRight() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let s1 = boardVM.addSession()!
        let s2 = boardVM.addSession()!
        boardVM.focusedSessionID = s1.id

        vm.focusTerminalRight()
        XCTAssertEqual(boardVM.focusedSessionID, s2.id)
    }

    func testFocusTerminalLeft() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let s1 = boardVM.addSession()!
        let s2 = boardVM.addSession()!
        boardVM.focusedSessionID = s2.id

        vm.focusTerminalLeft()
        XCTAssertEqual(boardVM.focusedSessionID, s1.id)
    }

    func testFocusTerminalRightWrapsAround() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let s1 = boardVM.addSession()!
        let s2 = boardVM.addSession()!
        boardVM.focusedSessionID = s2.id

        vm.focusTerminalRight()
        XCTAssertEqual(boardVM.focusedSessionID, s1.id)
    }

    func testFocusTerminalLeftWrapsAround() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let s1 = boardVM.addSession()!
        let _ = boardVM.addSession()!
        boardVM.focusedSessionID = s1.id

        vm.focusTerminalLeft()
        // Should wrap to last
        XCTAssertNotEqual(boardVM.focusedSessionID, s1.id)
    }

    func testFocusTerminalAtIndex() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let _ = boardVM.addSession()!
        let s2 = boardVM.addSession()!
        let _ = boardVM.addSession()!

        vm.focusTerminal(at: 1)
        XCTAssertEqual(boardVM.focusedSessionID, s2.id)
    }

    func testFocusTerminalAtOutOfBoundsIndex() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let s1 = boardVM.addSession()!
        boardVM.focusedSessionID = s1.id

        vm.focusTerminal(at: 99)
        // Should not change
        XCTAssertEqual(boardVM.focusedSessionID, s1.id)
    }

    func testFocusTerminalWithNoSelectedEnv() {
        let vm = makeSUT()
        vm.selectedEnvironmentID = nil
        // Should not crash
        vm.focusTerminalRight()
        vm.focusTerminalLeft()
        vm.focusTerminal(at: 0)
    }

    func testFocusEnvironmentWithEmptyEnvironments() {
        let vm = makeSUT()
        for env in vm.environments {
            vm.removeEnvironment(env)
        }
        // Should not crash
        vm.focusEnvironmentUp()
        vm.focusEnvironmentDown()
    }

    // MARK: - Close Terminal Requested

    func testCloseTerminalRequestedDefault() {
        let vm = makeSUT()
        XCTAssertFalse(vm.closeTerminalRequested)
    }

    func testIsModalOpenDefault() {
        let vm = makeSUT()
        XCTAssertFalse(vm.isModalOpen)
    }

    // MARK: - Add Terminal Or Environment With No Selection

    func testAddTerminalOrEnvironmentWithNoSelection() {
        let vm = makeSUT()
        vm.selectedEnvironmentID = nil
        let envCount = vm.environments.count
        vm.addTerminalOrEnvironment()
        // Should not add anything
        XCTAssertEqual(vm.environments.count, envCount)
    }

    // MARK: - Navigate To Non-Existent Session

    func testNavigateToNonExistentEnvironment() {
        let vm = makeSUT()
        let fakeEnvID = UUID()
        let fakeSessionID = UUID()
        vm.navigateToSession(environmentID: fakeEnvID, sessionID: fakeSessionID)
        XCTAssertEqual(vm.selectedEnvironmentID, fakeEnvID)
    }

    // MARK: - Notification Settings Via Board VM

    func testGetNotificationSettingsViaCallback() {
        let vm = makeSUT()
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let settings = boardVM.getNotificationSettings?()
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings, vm.notificationSettings)
    }

    func testGetPromptButtonsViaCallback() {
        let vm = makeSUT()
        vm.promptButtons = [PromptButton(title: "X", color: "red", prompt: "y")]
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        let buttons = boardVM.getPromptButtons?()
        XCTAssertEqual(buttons?.count, 1)
        XCTAssertEqual(buttons?.first?.title, "X")
    }

    func testGetSkipCloseConfirmationViaCallback() {
        let vm = makeSUT()
        vm.skipCloseConfirmation = true
        guard let env = vm.environments.first else { XCTFail(); return }
        let boardVM = vm.boardViewModel(for: env)
        XCTAssertTrue(boardVM.getSkipCloseConfirmation?() ?? false)
    }

    // MARK: - Schedule Save

    func testScheduleSaveDoesNotCrash() {
        let vm = makeSUT()
        vm.scheduleSave()
    }

    // MARK: - Move Environment

    func testMoveEnvironment() {
        let vm = makeSUT()
        // Clean slate
        while vm.environments.count > 1 {
            vm.removeEnvironment(vm.environments.last!)
        }
        let _ = vm.addEnvironment(name: "B")
        let _ = vm.addEnvironment(name: "C")

        let sortedBefore = vm.sortedEnvironments.map { $0.name }
        XCTAssertEqual(sortedBefore.count, 3)

        // Move last to first position
        vm.moveEnvironment(from: IndexSet(integer: 2), to: 0)

        let sortedAfter = vm.sortedEnvironments
        XCTAssertEqual(sortedAfter.count, 3)
        XCTAssertEqual(sortedAfter[0].name, "C")
    }
}
