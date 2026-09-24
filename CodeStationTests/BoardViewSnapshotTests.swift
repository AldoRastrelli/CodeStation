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

    // MARK: - Drop targets across stacked boards

    private func containsDropTarget(_ view: NSView) -> Bool {
        !view.registeredDraggedTypes.isEmpty || view.subviews.contains(where: containsDropTarget)
    }

    private func containsTerminalWebView(_ view: NSView) -> Bool {
        view is TerminalWebView || view.subviews.contains(where: containsTerminalWebView)
    }

    func testSelectedBoardDropTargetsSitAboveHiddenBoardTerminals() {
        let selected = Environment(name: "Selected", sortOrder: 0)
        let hidden = Environment(name: "Hidden", sortOrder: 1)
        let selectedBoard = BoardViewModel()
        for _ in 0..<5 { selectedBoard.addSession() }
        let hiddenBoard = BoardViewModel()
        hiddenBoard.addSession()
        let boards = [selected.id: selectedBoard, hidden.id: hiddenBoard]

        let stack = EnvironmentBoardsStack(
            environments: [selected, hidden],
            selectedEnvironmentID: selected.id,
            boardViewModel: { boards[$0.id]! },
            onRename: { _, _ in }
        )
        let hosting = NSHostingView(rootView: stack)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        hosting.layoutSubtreeIfNeeded()

        // The selected board has 5 terminals in a 3x2 grid, so its empty cell is
        // the bottom-right third. The hidden board is later in the stack and has
        // one full-width terminal whose web view covers that cell.
        let emptyCellCenter = NSPoint(x: hosting.bounds.width * 5 / 6, y: hosting.bounds.height * 3 / 4)
        let underPoint = hosting.subviews.enumerated().filter { $0.element.frame.contains(emptyCellCenter) }
        let dropTargetIndex = underPoint.last { containsDropTarget($0.element) }?.offset
        let hiddenTerminalIndex = underPoint.last { containsTerminalWebView($0.element) }?.offset

        XCTAssertNotNil(dropTargetIndex)
        XCTAssertNotNil(hiddenTerminalIndex)
        XCTAssertGreaterThan(
            dropTargetIndex ?? -1,
            hiddenTerminalIndex ?? .max,
            "AppKit finds drop targets from the topmost view down, so the selected board's empty cell must be above the hidden terminal"
        )
        window.orderOut(nil)
    }
}
