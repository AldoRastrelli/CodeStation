import XCTest
import SnapshotTesting
import SwiftUI
@testable import CodeStation

final class EmptyCellViewSnapshotTests: XCTestCase {
    func testDefaultState() {
        let view = EmptyCellView(onAdd: {})
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 200, height: 150)
        assertSnapshot(of: controller, as: .image)
    }

    func testAcceptDropForwardsSessionID() {
        let expected = UUID()
        var received: UUID?
        let view = EmptyCellView(onAdd: {}, onSessionDropped: { id in
            received = id
            return true
        })

        XCTAssertTrue(view.acceptDrop(sessionID: expected))
        XCTAssertEqual(received, expected)
    }

    func testAcceptDropReturnsHandlerResult() {
        let view = EmptyCellView(onAdd: {}, onSessionDropped: { _ in false })
        XCTAssertFalse(view.acceptDrop(sessionID: UUID()))
    }

    func testAcceptDropWithoutHandlerReturnsFalse() {
        let view = EmptyCellView(onAdd: {})
        XCTAssertFalse(view.acceptDrop(sessionID: UUID()))
    }
}
