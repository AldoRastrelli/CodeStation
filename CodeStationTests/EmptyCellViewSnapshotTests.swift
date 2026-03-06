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
}
