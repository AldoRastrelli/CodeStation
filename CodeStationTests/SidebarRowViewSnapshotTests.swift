import XCTest
import SnapshotTesting
import SwiftUI
@testable import CodeStation

final class SidebarRowViewSnapshotTests: XCTestCase {
    private func makeViewModel() -> AppViewModel {
        AppViewModel()
    }

    func testDefaultRow() {
        let viewModel = makeViewModel()
        let env = viewModel.sortedEnvironments.first!
        let view = SidebarRowView(environment: env, viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 220, height: 30)
        assertSnapshot(of: controller, as: .image)
    }

    func testRowWithMultipleSessions() {
        let viewModel = makeViewModel()
        let env = viewModel.sortedEnvironments.first!
        let boardVM = viewModel.boardViewModel(for: env)
        boardVM.addSession()
        boardVM.addSession()
        boardVM.addSession()
        let view = SidebarRowView(environment: env, viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 220, height: 30)
        assertSnapshot(of: controller, as: .image)
    }

    func testRowWithNotificationBadge() {
        let viewModel = makeViewModel()
        let env = viewModel.sortedEnvironments.first!
        let boardVM = viewModel.boardViewModel(for: env)
        let session = boardVM.addSession()!
        boardVM.unseenNotificationSessionIDs.insert(session.id)
        let view = SidebarRowView(environment: env, viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 220, height: 30)
        assertSnapshot(of: controller, as: .image)
    }
}
