import SwiftUI
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onNotificationTapped: ((UUID, UUID) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let envString = userInfo["environmentID"] as? String,
           let sessionString = userInfo["sessionID"] as? String,
           let envID = UUID(uuidString: envString),
           let sessionID = UUID(uuidString: sessionString) {
            NSApp.activate(ignoringOtherApps: true)
            onNotificationTapped?(envID, sessionID)
        }
        completionHandler()
    }
}

@main
struct CodeStationApp: App {
    private enum Constants {
        static let defaultWindowWidth: CGFloat = 1200
        static let defaultWindowHeight: CGFloat = 800
        static let settingsWindowWidth: CGFloat = 600
        static let settingsWindowHeight: CGFloat = 400
    }

    @State private var viewModel = AppViewModel()
    @State private var notificationDelegate = NotificationDelegate()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onAppear {
                    setupNotifications()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: Constants.defaultWindowWidth, height: Constants.defaultWindowHeight)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(Strings.Terminals.addTerminal) {
                    viewModel.addTerminalOrEnvironment()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(viewModel.isModalOpen)

                Button(Strings.Terminals.closeTerminal) {
                    viewModel.closeTerminalRequested = true
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(viewModel.focusedTerminalTitle == nil || viewModel.isModalOpen)

                Divider()

                ForEach(1...8, id: \.self) { n in
                    Button(Strings.Navigation.terminalNumber(n)) {
                        viewModel.focusTerminal(at: n - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(n))), modifiers: .command)
                    .disabled(viewModel.isModalOpen)
                }

                Divider()

                Button(Strings.Navigation.previousTerminal) {
                    viewModel.focusTerminalLeft()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
                .disabled(viewModel.isModalOpen)

                Button(Strings.Navigation.nextTerminal) {
                    viewModel.focusTerminalRight()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
                .disabled(viewModel.isModalOpen)

                Divider()

                Button(Strings.Navigation.previousEnvironment) {
                    viewModel.focusEnvironmentUp()
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
                .disabled(viewModel.isModalOpen)

                Button(Strings.Navigation.nextEnvironment) {
                    viewModel.focusEnvironmentDown()
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
                .disabled(viewModel.isModalOpen)
            }

            CommandMenu(Strings.App.viewMenu) {
                Button(Strings.App.zoomIn) { viewModel.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(viewModel.isModalOpen)
                Button(Strings.App.zoomOut) { viewModel.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(viewModel.isModalOpen)
                Button(Strings.App.actualSize) { viewModel.zoomReset() }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(viewModel.isModalOpen)
            }
        }

    }

    private func setupNotifications() {
        notificationDelegate.onNotificationTapped = { envID, sessionID in
            viewModel.navigateToSession(environmentID: envID, sessionID: sessionID)
        }
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationService.requestPermission()
    }
}
