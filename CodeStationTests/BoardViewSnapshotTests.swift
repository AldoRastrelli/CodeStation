import XCTest
import SnapshotTesting
import SwiftUI
import WebKit
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

    // MARK: - Swapping terminals moves their web views

    private func hostInWindow<V: View>(_ root: V) -> (NSHostingView<V>, NSWindow) {
        let hosting = NSHostingView(rootView: root)
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
        return (hosting, window)
    }

    private func frame(of webView: WKWebView?, in hosting: NSView) -> NSRect? {
        guard let webView, webView.isDescendant(of: hosting) else { return nil }
        return webView.convert(webView.bounds, to: hosting)
    }

    func testSwappingSessionsMovesTheirWebViews() {
        let board = BoardViewModel()
        for _ in 0..<4 { board.addSession() }
        let sessions = board.sessions.sorted { $0.gridIndex < $1.gridIndex }
        let first = sessions[0]
        let second = sessions[1]
        let (hosting, window) = hostInWindow(TerminalGridView(viewModel: board))
        defer { window.orderOut(nil) }

        let firstFrame = frame(of: board.viewModel(for: first).webView, in: hosting)
        let secondFrame = frame(of: board.viewModel(for: second).webView, in: hosting)
        XCTAssertNotNil(firstFrame)
        XCTAssertNotNil(secondFrame)
        XCTAssertNotEqual(firstFrame, secondFrame)

        XCTAssertTrue(board.swapSessions(sourceID: first.id, targetGridIndex: second.gridIndex))
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))
        hosting.layoutSubtreeIfNeeded()

        XCTAssertEqual(frame(of: board.viewModel(for: first).webView, in: hosting), secondFrame)
        XCTAssertEqual(frame(of: board.viewModel(for: second).webView, in: hosting), firstFrame)
    }

    private func evaluate(_ script: String, in webView: WKWebView) -> Any? {
        var result: Any?
        let done = expectation(description: "js")
        webView.evaluateJavaScript(script) { value, _ in
            result = value
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return result
    }

    private func waitForTerminalReady(_ webView: WKWebView) -> Int? {
        for _ in 0..<40 {
            if let rows = evaluate("typeof term === 'undefined' ? 0 : term.rows", in: webView) as? Int, rows > 1 {
                return rows
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        }
        return nil
    }

    func testSwappingSessionsDoesNotShrinkTheTerminal() throws {
        let board = BoardViewModel()
        for _ in 0..<4 { board.addSession() }
        let sessions = board.sessions.sorted { $0.gridIndex < $1.gridIndex }
        let (_, window) = hostInWindow(TerminalGridView(viewModel: board))
        defer { window.orderOut(nil) }

        let webView = try XCTUnwrap(board.viewModel(for: sessions[0]).webView)
        let rowsBefore = try XCTUnwrap(waitForTerminalReady(webView))
        _ = evaluate("window.__minRows = term.rows; term.onResize(function(s) { window.__minRows = Math.min(window.__minRows, s.rows); }); 0", in: webView)

        XCTAssertTrue(board.swapSessions(sourceID: sessions[0].id, targetGridIndex: sessions[1].gridIndex))
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))

        let minRows = evaluate("window.__minRows", in: webView) as? Int
        XCTAssertEqual(minRows, rowsBefore, "the terminal was resized smaller while its web view moved cells")
        XCTAssertEqual(evaluate("term.rows", in: webView) as? Int, rowsBefore)
    }
}
