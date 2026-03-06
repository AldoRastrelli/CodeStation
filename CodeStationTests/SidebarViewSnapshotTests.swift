import XCTest
import SnapshotTesting
import SwiftUI
@testable import CodeStation

final class SidebarViewSnapshotTests: XCTestCase {
    func testSingleEnvironment() {
        let viewModel = AppViewModel()
        let view = SidebarView(viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 220, height: 300)
        assertSnapshot(of: controller, as: .image)
    }

    func testMultipleEnvironments() {
        let viewModel = AppViewModel()
        viewModel.addEnvironment(name: "Backend")
        viewModel.addEnvironment(name: "Frontend")
        viewModel.addEnvironment(name: "Database")
        let view = SidebarView(viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 220, height: 300)
        assertSnapshot(of: controller, as: .image)
    }

    func testWithSelection() {
        let viewModel = AppViewModel()
        let env = viewModel.addEnvironment(name: "Selected Env")
        viewModel.selectedEnvironmentID = env.id
        let view = SidebarView(viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 220, height: 300)
        assertSnapshot(of: controller, as: .image)
    }
}
