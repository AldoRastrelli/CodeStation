import XCTest
import SnapshotTesting
import SwiftUI
@testable import CodeStation

final class SettingsWindowViewSnapshotTests: XCTestCase {
    func testNotificationsTab() {
        let viewModel = AppViewModel()
        let view = SettingsWindowView(viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 580, height: 400)
        assertSnapshot(of: controller, as: .image)
    }

    func testNotificationsDisabled() {
        let viewModel = AppViewModel()
        viewModel.notificationSettings.enabled = false
        let view = SettingsWindowView(viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 580, height: 400)
        assertSnapshot(of: controller, as: .image)
    }

    func testKeyboardShortcutsTab() {
        let viewModel = AppViewModel()
        var view = SettingsWindowView(viewModel: viewModel)
        let tabMirror = SettingsTab.keyboardShortcuts
        let hostView = SettingsWindowView(viewModel: viewModel)
        let controller = NSHostingController(rootView: hostView)
        controller.view.frame = NSRect(x: 0, y: 0, width: 580, height: 400)
        assertSnapshot(of: controller, as: .image, named: "keyboardShortcuts")
    }

    func testCustomPromptsEmpty() {
        let viewModel = AppViewModel()
        viewModel.promptButtons = []
        let view = SettingsWindowView(viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 580, height: 400)
        assertSnapshot(of: controller, as: .image, named: "customPromptsEmpty")
    }

    func testCustomPromptsWithButtons() {
        let viewModel = AppViewModel()
        viewModel.promptButtons = [
            PromptButton(title: "Build", color: "blue", prompt: "npm run build"),
            PromptButton(title: "Test", color: "green", prompt: "npm test"),
            PromptButton(title: "Deploy", color: "red", prompt: "npm run deploy"),
        ]
        let view = SettingsWindowView(viewModel: viewModel)
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 580, height: 400)
        assertSnapshot(of: controller, as: .image, named: "customPromptsPopulated")
    }
}
