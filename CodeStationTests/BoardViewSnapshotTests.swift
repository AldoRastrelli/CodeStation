import XCTest
import SnapshotTesting
import SwiftUI
@testable import CodeStation

final class BoardViewSnapshotTests: XCTestCase {
    func testEmptyState() {
        let boardVM = BoardViewModel()
        let view = BoardView(viewModel: boardVM, environmentName: "Test Environment", onRename: { _ in })
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        assertSnapshot(of: controller, as: .image)
    }

    func testToolbarWithSessions() {
        let boardVM = BoardViewModel()
        boardVM.addSession()
        boardVM.addSession()
        let view = BoardView(viewModel: boardVM, environmentName: "My Project", onRename: { _ in })
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        assertSnapshot(of: controller, as: .image)
    }

    func testLongEnvironmentName() {
        let boardVM = BoardViewModel()
        boardVM.addSession()
        let view = BoardView(
            viewModel: boardVM,
            environmentName: "Very Long Environment Name That Might Overflow",
            onRename: { _ in }
        )
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        assertSnapshot(of: controller, as: .image)
    }
}
