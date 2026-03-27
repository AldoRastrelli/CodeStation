import AppKit
import SwiftUI

class SettingsWindowController: NSObject, NSWindowDelegate {
    private static var window: NSWindow?
    private static var instance: SettingsWindowController?
    private weak var viewModel: AppViewModel?

    static func show(viewModel: AppViewModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsWindowView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: settingsView)

        let controller = SettingsWindowController()
        controller.viewModel = viewModel
        instance = controller

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = Strings.Settings.windowTitle
        window.center()
        window.delegate = controller
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false

        self.window = window
        viewModel.isModalOpen = true
    }

    func windowWillClose(_ notification: Notification) {
        viewModel?.isModalOpen = false
        Self.instance = nil
    }

    static func closeForTesting() {
        window?.close()
        window = nil
        instance = nil
    }
}
