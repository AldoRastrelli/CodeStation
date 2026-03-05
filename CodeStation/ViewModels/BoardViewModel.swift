import Foundation
import AppKit

@Observable
class BoardViewModel {
    private enum Constants {
        static let maxSessions = 8
        static let gridColumns = 4
        static let gridLayoutThreshold = 4
        static let defaultColumnProportion: CGFloat = 0.25
        static let defaultRowProportion: CGFloat = 0.5
    }

    var sessions: [TerminalSession] = []
    static let maxSessions = Constants.maxSessions

    var columnProportions: [CGFloat] = Array(repeating: Constants.defaultColumnProportion, count: Constants.gridColumns)
    var rowProportion: CGFloat = Constants.defaultRowProportion

    var pendingRestores: [SessionSnapshot] = []

    var sessionViewModels: [UUID: TerminalSessionViewModel] = [:]
    var onStateChanged: (() -> Void)?
    var environmentID: UUID?
    var getNotificationSettings: (() -> NotificationSettings?)?
    var getPromptButtons: (() -> [PromptButton])?
    var onAddPromptButton: ((PromptButton) -> Void)?
    var onUpdatePromptButton: ((PromptButton) -> Void)?
    var onDeletePromptButton: ((UUID) -> Void)?
    var focusedSessionID: UUID?
    var getSkipCloseConfirmation: (() -> Bool)?
    var onSkipCloseConfirmationChanged: ((Bool) -> Void)?
    var hasUnseenNotification: Bool = false

    var canAddSession: Bool {
        sessions.count < Constants.maxSessions
    }

    var useGridLayout: Bool {
        sessions.count > Constants.gridLayoutThreshold
    }

    var gridColumns: Int {
        Constants.gridColumns
    }

    var gridRows: Int {
        useGridLayout ? 2 : 1
    }

    // MARK: - Session CRUD

    @discardableResult
    func addSession() -> TerminalSession? {
        guard canAddSession else { return nil }
        let index = nextAvailableIndex()
        let session = TerminalSession(gridIndex: index)
        sessions.append(session)
        onStateChanged?()
        return session
    }

    func addSession(restoring snapshot: SessionSnapshot) -> TerminalSession? {
        guard canAddSession else { return nil }
        let session = TerminalSession(gridIndex: snapshot.gridIndex, title: snapshot.title)
        session.isUserEditedTitle = snapshot.userEditedTitle
        session.sessionDescription = snapshot.sessionDescription
        session.currentDirectory = snapshot.currentDirectory
        sessions.append(session)
        return session
    }

    func restorePendingSessions() {
        guard !pendingRestores.isEmpty else { return }
        let snapshots = pendingRestores
        pendingRestores = []
        for snapshot in snapshots {
            _ = addSession(restoring: snapshot)
        }
    }

    func removeSession(_ session: TerminalSession) {
        let sorted = sessions.sorted { $0.gridIndex < $1.gridIndex }
        let sortedIndex = sorted.firstIndex(where: { $0.id == session.id })

        viewModel(for: session).cleanup()
        sessionViewModels.removeValue(forKey: session.id)
        sessions.removeAll { $0.id == session.id }
        onStateChanged?()

        // Focus previous terminal
        let remaining = sessions.sorted { $0.gridIndex < $1.gridIndex }
        if !remaining.isEmpty {
            let targetIndex = max(0, (sortedIndex ?? 1) - 1)
            let clamped = min(targetIndex, remaining.count - 1)
            let target = remaining[clamped]
            focusedSessionID = target.id
            viewModel(for: target).makeFocused()
        } else {
            focusedSessionID = nil
        }
    }

    @discardableResult
    func addSessionAt(row: Int, col: Int) -> TerminalSession? {
        guard canAddSession else { return nil }
        let index = row * gridColumns + col
        let session = TerminalSession(gridIndex: index)
        sessions.append(session)
        onStateChanged?()
        return session
    }

    // MARK: - Drag & Drop

    func moveSession(sourceID: UUID, toGridIndex target: Int) -> Bool {
        guard let session = sessions.first(where: { $0.id == sourceID }) else { return false }
        session.gridIndex = target
        onStateChanged?()
        return true
    }

    func swapSessions(sourceID: UUID, targetGridIndex: Int) -> Bool {
        guard let source = sessions.first(where: { $0.id == sourceID }),
              let target = sessions.first(where: { $0.gridIndex == targetGridIndex }),
              source.id != target.id else { return false }
        let sourceIndex = source.gridIndex
        source.gridIndex = target.gridIndex
        target.gridIndex = sourceIndex
        onStateChanged?()
        return true
    }

    // MARK: - Grid

    func sessionAt(row: Int, col: Int) -> TerminalSession? {
        let index = row * gridColumns + col
        return sessions.first { $0.gridIndex == index }
    }

    func isSlotEmpty(row: Int, col: Int) -> Bool {
        let index = row * gridColumns + col
        return !sessions.contains { $0.gridIndex == index }
    }

    // MARK: - Child ViewModels

    func viewModel(for session: TerminalSession) -> TerminalSessionViewModel {
        if let vm = sessionViewModels[session.id] {
            return vm
        }
        let vm = TerminalSessionViewModel(session: session)
        vm.environmentID = environmentID
        vm.getNotificationSettings = getNotificationSettings
        vm.getPromptButtons = getPromptButtons
        vm.onStateChanged = { [weak self] in
            self?.onStateChanged?()
        }
        vm.onNotificationFired = { [weak self] in
            self?.hasUnseenNotification = true
        }
        sessionViewModels[session.id] = vm
        return vm
    }

    // MARK: - Cleanup

    func cleanupAllSessions() {
        for session in sessions {
            viewModel(for: session).cleanup()
        }
    }

    // MARK: - Private

    private func nextAvailableIndex() -> Int {
        let usedIndices = Set(sessions.map { $0.gridIndex })
        for i in 0..<Constants.maxSessions {
            if !usedIndices.contains(i) {
                return i
            }
        }
        return sessions.count
    }
}
