import Foundation
import SwiftTerm

@Observable
class TerminalSessionViewModel {
    private enum Constants {
        static let hookMonitorInterval: TimeInterval = 1.0
        static let idleTimeoutSeconds: TimeInterval = 300
    }

    var session: TerminalSession
    var terminalView: LocalProcessTerminalView?
    var onStateChanged: (() -> Void)?
    var environmentID: UUID?
    var getNotificationSettings: (() -> NotificationSettings?)?
    var getPromptButtons: (() -> [PromptButton])?
    var promptButtonsCollapsed: Bool = false

    private var hookMonitorTimer: Timer?
    private var hasReceivedHookEvent = false
    private var lastProcessedTimestamp: Date?

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
                    print("[Hook] \(session.title): idle timeout, \(session.status.label) -> Asleep")
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

            print("[Hook] \(session.title): event=\"\(state.event)\" \(oldStatus.label) -> \(session.status.label) (age: \(String(format: "%.1f", elapsed))s)")
        } else if hasReceivedHookEvent {
            if let lastEvent = session.lastHookEventTime, Date().timeIntervalSince(lastEvent) > Constants.idleTimeoutSeconds {
                if session.status != .asleep {
                    print("[Hook] \(session.title): no recent events, \(session.status.label) -> Asleep")
                }
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
        terminalView?.send(txt: text + "\n")
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
        guard let settings = getNotificationSettings?(), (settings.enabled || settings.soundEnabled) else { return }
        guard oldStatus == .cooking else { return }
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
        if let tv = terminalView {
            let pid = tv.process.shellPid
            if pid > 0 {
                kill(pid, SIGHUP)
            }
        }
        terminalView = nil
    }
}
