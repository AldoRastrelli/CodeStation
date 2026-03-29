import XCTest
import WebKit
@testable import CodeStation

final class MessageHandlerRelayTests: XCTestCase {

    // MARK: - Initial state

    func testRelayInitialCoordinatorIsNil() {
        let relay = MessageHandlerRelay()
        XCTAssertNil(relay.coordinator)
    }

    // MARK: - Weak coordinator reference

    func testRelayCoordinatorIsWeak() {
        let relay = MessageHandlerRelay()
        var coordinator: TerminalSessionView.Coordinator? = TerminalSessionView.Coordinator()
        relay.coordinator = coordinator
        XCTAssertNotNil(relay.coordinator)
        coordinator = nil
        XCTAssertNil(relay.coordinator)
    }

    func testRelayCoordinatorCanBeReassigned() {
        let relay = MessageHandlerRelay()
        let c1 = TerminalSessionView.Coordinator()
        let c2 = TerminalSessionView.Coordinator()
        relay.coordinator = c1
        XCTAssertTrue(relay.coordinator === c1)
        relay.coordinator = c2
        XCTAssertTrue(relay.coordinator === c2)
    }
}

final class TerminalWebViewTests: XCTestCase {

    private func makeWebView() -> TerminalWebView {
        TerminalWebView(frame: .zero, configuration: WKWebViewConfiguration())
    }

    // MARK: - Instantiation

    func testTerminalWebViewCanBeInstantiated() {
        let webView = makeWebView()
        XCTAssertNotNil(webView)
    }

    func testTerminalWebViewIsWKWebView() {
        let webView = makeWebView()
        XCTAssertTrue(webView is WKWebView)
    }

    // MARK: - performKeyEquivalent with non-arrow keys

    func testPerformKeyEquivalentWithNonArrowKeyDoesNotCrash() {
        let webView = makeWebView()
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        ) else { return }
        _ = webView.performKeyEquivalent(with: event)
    }

    func testPerformKeyEquivalentWithCommandOnlyDoesNotCrash() {
        let webView = makeWebView()
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "n",
            charactersIgnoringModifiers: "n",
            isARepeat: false,
            keyCode: 45
        ) else { return }
        _ = webView.performKeyEquivalent(with: event)
    }

    // MARK: - performKeyEquivalent with Cmd+Shift+Arrow

    func testPerformKeyEquivalentWithCmdShiftLeftArrowDoesNotCrash() {
        let webView = makeWebView()
        let leftArrowChar = String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: leftArrowChar,
            charactersIgnoringModifiers: leftArrowChar,
            isARepeat: false,
            keyCode: 123
        ) else { return }
        _ = webView.performKeyEquivalent(with: event)
    }

    func testPerformKeyEquivalentWithCmdShiftRightArrowDoesNotCrash() {
        let webView = makeWebView()
        let rightArrowChar = String(UnicodeScalar(NSRightArrowFunctionKey)!)
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: rightArrowChar,
            charactersIgnoringModifiers: rightArrowChar,
            isARepeat: false,
            keyCode: 124
        ) else { return }
        _ = webView.performKeyEquivalent(with: event)
    }

    func testPerformKeyEquivalentWithCmdShiftUpArrowDoesNotCrash() {
        let webView = makeWebView()
        let upArrowChar = String(UnicodeScalar(NSUpArrowFunctionKey)!)
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: upArrowChar,
            charactersIgnoringModifiers: upArrowChar,
            isARepeat: false,
            keyCode: 126
        ) else { return }
        _ = webView.performKeyEquivalent(with: event)
    }

    func testPerformKeyEquivalentWithCmdShiftDownArrowDoesNotCrash() {
        let webView = makeWebView()
        let downArrowChar = String(UnicodeScalar(NSDownArrowFunctionKey)!)
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: downArrowChar,
            charactersIgnoringModifiers: downArrowChar,
            isARepeat: false,
            keyCode: 125
        ) else { return }
        _ = webView.performKeyEquivalent(with: event)
    }
}

final class TerminalSessionViewCoordinatorTests: XCTestCase {

    // MARK: - Coordinator init

    func testCoordinatorCanBeInstantiated() {
        let coordinator = TerminalSessionView.Coordinator()
        XCTAssertNotNil(coordinator)
    }

    func testCoordinatorInitialWebViewIsNil() {
        let coordinator = TerminalSessionView.Coordinator()
        XCTAssertNil(coordinator.webView)
    }

    func testCoordinatorInitialViewModelIsNil() {
        let coordinator = TerminalSessionView.Coordinator()
        XCTAssertNil(coordinator.viewModel)
    }

    // MARK: - adoptExistingPTY

    func testAdoptExistingPTYWithNilDoesNotCrash() {
        let coordinator = TerminalSessionView.Coordinator()
        coordinator.adoptExistingPTY(nil)
    }

    func testAdoptExistingPTYUpdatesPTYCallbacks() {
        let coordinator = TerminalSessionView.Coordinator()
        let session = TerminalSession(gridIndex: 0)
        let vm = TerminalSessionViewModel(session: session)
        coordinator.viewModel = vm

        let pty = TerminalPTY()
        coordinator.adoptExistingPTY(pty)
        // After adoption, the PTY has new callbacks - verify no crash when triggered
        pty.onOutput?(Data("test".utf8))
        pty.onTerminated?(0)
    }
}
