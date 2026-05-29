import Foundation
import WebKit

@Observable
class TerminalSessionViewModel {
    private enum Constants {
        static let hookMonitorInterval: TimeInterval = 1.0
        static let idleTimeoutSeconds: TimeInterval = 300
        static let notificationDedupWindow: TimeInterval = 3.0
    }

    var session: TerminalSession
    var pty: TerminalPTY?
    // Strong reference so the WKWebView survives layout changes (e.g. single-row <-> grid).
    var webView: WKWebView?
    var messageHandlerRelay: MessageHandlerRelay?
    var fontSize: CGFloat = AppViewModel.defaultFontSize
    var onStateChanged: (() -> Void)?
    var onNotificationFired: (() -> Void)?
    // Bumped to pulse the header when a notification lands while the user is
    // already viewing this terminal (no persistent highlight in that case).
    var attentionPulse: Int = 0

    func triggerAttentionPulse() {
        attentionPulse += 1
    }
    var environmentID: UUID?
    var getNotificationSettings: (() -> NotificationSettings?)?
    var getPromptButtons: (() -> [PromptButton])?
    var promptButtonsCollapsed: Bool = true

    private var hookMonitorTimer: Timer?
    private var hasReceivedHookEvent = false
    private var lastProcessedTimestamp: Date?
    private var lastNotifiedStatus: SessionStatus?
    private var lastNotifiedAt: Date?

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

            guard let newStatus = state.status else { return }

            session.status = newStatus

            let elapsed = Date().timeIntervalSince(state.timestamp)
            if session.status == .ready && elapsed > Constants.idleTimeoutSeconds {
                session.status = .asleep
            }

            checkAndFireNotification(isCompletionEvent: state.isCompletion, oldStatus: oldStatus, newStatus: session.status)

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

    // A waiting badge means Claude asked for input; the user typing is them
    // answering, so resume cooking now instead of lingering on waiting until the
    // next hook event, which can arrive many seconds after the keystroke.
    //
    // The terminal auto-replies to escape-sequence queries (cursor position,
    // device attributes, focus reports) on the same channel as keystrokes, and
    // those replies, like arrow and function keys, all begin with ESC. A real
    // answer (Enter, "y") never does, so ignore ESC-prefixed input to avoid the
    // terminal clearing its own waiting state.
    func recordUserInput(_ data: Data) {
        guard let first = data.first, first != 0x1b else { return }
        if session.status == .waiting {
            session.status = .cooking
        }
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
        onStateChanged?()
    }

    func commitTitleEdit() {
        let trimmed = session.title.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            resetTitleToDefault()
        } else {
            session.title = trimmed
            session.isUserEditedTitle = true
            onStateChanged?()
        }
    }

    // Called per-keystroke while the title field is being edited so that the
    // user's typed value survives an app quit without an explicit Enter press.
    // Without this, the shell's OSC 7 directory report on relaunch would
    // overwrite the title because `isUserEditedTitle` had never been set.
    func markTitleAsUserEdited() {
        session.isUserEditedTitle = true
        onStateChanged?()
    }

    func commitDescriptionEdit() {
        session.sessionDescription = session.sessionDescription.trimmingCharacters(in: .whitespaces)
        onStateChanged?()
    }

    func scheduleSave() {
        onStateChanged?()
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

    private func checkAndFireNotification(isCompletionEvent: Bool, oldStatus: SessionStatus, newStatus: SessionStatus) {
        // "Done" only on a real completion event landing in ready, not on
        // compaction or config writes that also resolve to ready. "Waiting" on
        // any entry into waiting, not just from cooking, since a trailing event
        // can leave us in ready by the time the prompt arrives.
        let isDone = newStatus == .ready && oldStatus == .cooking && isCompletionEvent
        let isWaiting = newStatus == .waiting && oldStatus != .waiting
        guard isDone || isWaiting else { return }

        // Suppress only rapid duplicates of the same status (idle flicker);
        // distinct prompts or completions seconds apart still notify.
        let now = Date()
        if newStatus == lastNotifiedStatus, let last = lastNotifiedAt,
           now.timeIntervalSince(last) < Constants.notificationDedupWindow {
            return
        }
        lastNotifiedStatus = newStatus
        lastNotifiedAt = now

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
