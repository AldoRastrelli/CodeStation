import Foundation
import WebKit

@Observable
class TerminalSessionViewModel {
    private enum Constants {
        static let hookMonitorInterval: TimeInterval = 1.0
        static let idleTimeoutSeconds: TimeInterval = 300
    }

    var session: TerminalSession
    var pty: TerminalPTY?
    // Strong reference so the WKWebView survives layout changes (e.g. single-row <-> grid).
    var webView: WKWebView?
    var messageHandlerRelay: MessageHandlerRelay?
    var fontSize: CGFloat = AppViewModel.defaultFontSize
    var onStateChanged: (() -> Void)?
    var onNotificationFired: (() -> Void)?
    var environmentID: UUID?
    var getNotificationSettings: (() -> NotificationSettings?)?
    var getPromptButtons: (() -> [PromptButton])?
    var promptButtonsCollapsed: Bool = true

    private var hookMonitorTimer: Timer?
    private var hasReceivedHookEvent = false
    private var lastProcessedTimestamp: Date?
    private var lastNotifiedStatus: SessionStatus?

    init(session: TerminalSession) {
        self.session = session
    }

    func startHookMonitoring() {
        hookMonitorTimer = Timer.scheduledTimer(withTimeInterval: Constants.hookMonitorInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.pollHookState()
            }
        }
    }

    private func pollHookState() {
        if let state = HookManager.readState(for: session.id) {
            if let lastTs = lastProcessedTimestamp, lastTs == state.timestamp {
                let elapsed = Date().timeIntervalSince(state.timestamp)
                if session.status == .ready && elapsed > Constants.idleTimeoutSeconds {
                    session.status = .asleep
                }
                return
            }

            let oldStatus = session.status
            hasReceivedHookEvent = true
            session.lastHookEventTime = state.timestamp
            lastProcessedTimestamp = state.timestamp
            session.status = state.status

            let elapsed = Date().timeIntervalSince(state.timestamp)
            if session.status == .ready && elapsed > Constants.idleTimeoutSeconds {
                session.status = .asleep
            }

            checkAndFireNotification(oldStatus: oldStatus, newStatus: session.status)

        } else if hasReceivedHookEvent {
            if let lastEvent = session.lastHookEventTime, Date().timeIntervalSince(lastEvent) > Constants.idleTimeoutSeconds {
                session.status = .asleep
            }
        }
    }

    func updateStatusFromOutput() {
        guard !hasReceivedHookEvent else { return }
        guard let lastOutput = session.lastOutputTime else {
            session.status = .ready
            return
        }

        let elapsed = Date().timeIntervalSince(lastOutput)
        if elapsed < Constants.idleTimeoutSeconds {
            session.status = .ready
        } else {
            session.status = .asleep
        }
    }

    func recordDataReceived() {
        session.lastOutputTime = Date()
    }

    func sendPrompt(_ text: String) {
        pty?.write(Data((text + "\n").utf8))
    }

    func makeFocused() {
        guard let webView = webView, let window = webView.window else { return }
        window.makeFirstResponder(webView)
        // Give xterm.js DOM focus so it captures keyboard input.
        webView.evaluateJavaScript("term.focus()") { _, _ in }
    }

    func setFontSize(_ size: CGFloat) {
        fontSize = size
        webView?.evaluateJavaScript("window.setFontSize(\(size))") { _, _ in }
    }

    func zoomIn() {
        setFontSize(min(fontSize + 1, AppViewModel.maxFontSize))
    }

    func zoomOut() {
        setFontSize(max(fontSize - 1, AppViewModel.minFontSize))
    }

    func zoomReset() {
        setFontSize(AppViewModel.defaultFontSize)
    }

    func resetTitleToDefault() {
        if let dir = session.currentDirectory {
            session.title = (dir as NSString).lastPathComponent
        } else {
            session.title = Strings.Terminals.defaultTitle(session.gridIndex)
        }
        session.isUserEditedTitle = false
    }

    func updateDirectory(_ path: String) {
        session.currentDirectory = path
        if !session.isUserEditedTitle {
            let folderName = (path as NSString).lastPathComponent
            session.title = folderName
        }
        onStateChanged?()
    }

    func markProcessTerminated() {
        session.status = .asleep
    }

    private func checkAndFireNotification(oldStatus: SessionStatus, newStatus: SessionStatus) {
        guard oldStatus == .cooking else { return }
        guard newStatus == .ready || newStatus == .waiting else { return }
        // Claude can fire repeated cooking->ready cycles on an idle terminal
        // (auto-compaction, duplicate Stops). Only notify once per status
        // until a different notifiable status breaks the streak.
        guard newStatus != lastNotifiedStatus else { return }
        lastNotifiedStatus = newStatus

        onNotificationFired?()

        guard let settings = getNotificationSettings?(), (settings.enabled || settings.soundEnabled) else { return }
        guard let envID = environmentID else { return }

        if newStatus == .ready && settings.notifyWhenDone {
            NotificationService.send(
                title: Strings.Notifications.doneTitle,
                body: Strings.Notifications.doneBody(session.title),
                environmentID: envID,
                sessionID: session.id,
                settings: settings
            )
        } else if newStatus == .waiting && settings.notifyWhenWaiting {
            NotificationService.send(
                title: Strings.Notifications.waitingTitle,
                body: Strings.Notifications.waitingBody(session.title),
                environmentID: envID,
                sessionID: session.id,
                settings: settings
            )
        }
    }

    func cleanup() {
        hookMonitorTimer?.invalidate()
        hookMonitorTimer = nil
        HookManager.cleanupState(for: session.id)
        pty?.terminate()
        pty = nil
        messageHandlerRelay = nil
        webView = nil
    }
}
