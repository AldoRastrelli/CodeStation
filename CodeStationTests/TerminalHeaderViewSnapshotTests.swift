import XCTest
import SnapshotTesting
import SwiftUI
@testable import CodeStation

final class TerminalHeaderViewSnapshotTests: XCTestCase {
    private func makeViewModel(status: SessionStatus, title: String = "Terminal 1") -> TerminalSessionViewModel {
        let session = TerminalSession(gridIndex: 0, title: title)
        session.status = status
        return TerminalSessionViewModel(session: session)
    }

    func testReadyStatus() {
        let vm = makeViewModel(status: .ready)
        let view = TerminalHeaderView(viewModel: vm, terminalNumber: 1, onClose: {})
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 80)
        assertSnapshot(of: controller, as: .image)
    }

    func testCookingStatus() {
        let vm = makeViewModel(status: .cooking)
        let view = TerminalHeaderView(viewModel: vm, terminalNumber: 2, onClose: {})
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 80)
        assertSnapshot(of: controller, as: .image)
    }

    func testAsleepStatus() {
        let vm = makeViewModel(status: .asleep)
        let view = TerminalHeaderView(viewModel: vm, terminalNumber: 3, onClose: {})
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 80)
        assertSnapshot(of: controller, as: .image)
    }

    func testWaitingStatus() {
        let vm = makeViewModel(status: .waiting)
        let view = TerminalHeaderView(viewModel: vm, terminalNumber: 4, onClose: {})
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 80)
        assertSnapshot(of: controller, as: .image)
    }

    func testWithDescription() {
        let vm = makeViewModel(status: .ready, title: "Backend Server")
        vm.session.sessionDescription = "Running on port 3000"
        let view = TerminalHeaderView(viewModel: vm, terminalNumber: 1, onClose: {})
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 80)
        assertSnapshot(of: controller, as: .image)
    }

    func testCompactWidth() {
        let vm = makeViewModel(status: .cooking, title: "Terminal 1")
        let view = TerminalHeaderView(viewModel: vm, terminalNumber: 1, onClose: {})
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 250, height: 80)
        assertSnapshot(of: controller, as: .image)
    }

    func testWithPromptButtons() {
        let vm = makeViewModel(status: .ready)
        vm.promptButtonsCollapsed = false
        vm.getPromptButtons = {
            [
                PromptButton(title: "Build", color: "blue", prompt: "npm run build"),
                PromptButton(title: "Test", color: "green", prompt: "npm test"),
                PromptButton(title: "Deploy", color: "red", prompt: "npm run deploy"),
            ]
        }
        let view = TerminalHeaderView(viewModel: vm, terminalNumber: 1, onClose: {})
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 120)
        assertSnapshot(of: controller, as: .image)
    }

    func testWithoutTerminalNumber() {
        let vm = makeViewModel(status: .ready)
        let view = TerminalHeaderView(viewModel: vm, onClose: {})
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 80)
        assertSnapshot(of: controller, as: .image)
    }
}
