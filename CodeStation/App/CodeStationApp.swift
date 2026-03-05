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
            CommandMenu(Strings.App.viewMenu) {
                Button(Strings.App.zoomIn) { viewModel.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button(Strings.App.zoomOut) { viewModel.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button(Strings.App.actualSize) { viewModel.zoomReset() }
                    .keyboardShortcut("0", modifiers: .command)
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
