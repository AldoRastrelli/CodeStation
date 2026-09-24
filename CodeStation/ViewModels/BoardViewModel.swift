import Foundation
import AppKit

@Observable
class BoardViewModel {
    private enum Constants {
        static let maxSessions = 8
        static let maxGridColumns = 4
        static let gridLayoutThreshold = 3
        static let defaultColumnProportion: CGFloat = 0.25
        static let defaultRowProportion: CGFloat = 0.5
        static let minColumnProportion: CGFloat = 0.08
        static let minRowProportion: CGFloat = 0.15
    }

    var sessions: [TerminalSession] = []
    static let maxSessions = Constants.maxSessions

    var columnProportions: [CGFloat] = Array(repeating: Constants.defaultColumnProportion, count: Constants.maxGridColumns)
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
    // True only when this board's environment is selected and the app is
    // frontmost, i.e. the user is actually looking at this board.
    var isBoardActive: (() -> Bool)?

    var focusedSessionID: UUID? {
        didSet {
            if let sessionID = focusedSessionID, isBoardActive?() ?? false {
                unseenNotificationSessionIDs.remove(sessionID)
            }
        }
    }
    var getSkipCloseConfirmation: (() -> Bool)?
    var onSkipCloseConfirmationChanged: ((Bool) -> Void)?
    var unseenNotificationSessionIDs: Set<UUID> = []

    var hasUnseenNotification: Bool {
        !unseenNotificationSessionIDs.isEmpty
    }

    // Clears the focused terminal's pending notification when the user returns to
    // actively viewing this board (app reactivated or environment reselected).
    func markFocusedTerminalSeenIfActive() {
        guard isBoardActive?() ?? false, let focused = focusedSessionID else { return }
        unseenNotificationSessionIDs.remove(focused)
    }

    var hasCookingSession: Bool {
        sessions.contains { $0.status == .cooking }
    }

    var canAddSession: Bool {
        sessions.count < Constants.maxSessions
    }

    var useGridLayout: Bool {
        sessions.count > Constants.gridLayoutThreshold
    }

    var gridColumns: Int {
        Self.gridColumns(forCount: sessions.count)
    }

    var gridRows: Int {
        useGridLayout ? 2 : 1
    }

    private static func gridColumns(forCount count: Int) -> Int {
        switch count {
        case 0...4: return 2
        case 5...6: return 3
        default: return Constants.maxGridColumns
        }
    }

    // MARK: - Divider Resizing

    /// `fractionDelta` is the pointer travel as a fraction of the visible row width.
    /// Stored proportions are normalized by the sum of the visible columns when
    /// laid out, so the delta is scaled by that sum before it is applied.
    func resizeColumns(from startProportions: [CGFloat], dividerAfter index: Int, visibleCount count: Int, fractionDelta: CGFloat) {
        guard index >= 0, index + 1 < count else { return }
        let start = startProportions.count >= count
            ? startProportions
            : Array(repeating: 1 / CGFloat(count), count: count)
        let visibleTotal = start.prefix(count).reduce(0, +)
        guard visibleTotal > 0 else { return }

        let minRaw = Constants.minColumnProportion * visibleTotal
        let left = start[index]
        let right = start[index + 1]
        let lowerBound = minRaw - left
        let upperBound = right - minRaw
        guard lowerBound <= upperBound else { return }
        let rawDelta = min(max(fractionDelta * visibleTotal, lowerBound), upperBound)

        var props = start
        props[index] = left + rawDelta
        props[index + 1] = right - rawDelta
        columnProportions = props
    }

    /// `fractionDelta` is the pointer travel as a fraction of the visible grid height.
    func resizeRows(from startProportion: CGFloat, fractionDelta: CGFloat) {
        let lower = Constants.minRowProportion
        let upper = 1 - Constants.minRowProportion
        rowProportion = min(max(startProportion + fractionDelta, lower), upper)
    }

    // MARK: - Session CRUD

    @discardableResult
    func addSession() -> TerminalSession? {
        guard canAddSession else { return nil }

        let willBeGrid = (sessions.count + 1) > Constants.gridLayoutThreshold
        if !willBeGrid || !useGridLayout {
            compactGridIndicesInReadingOrder()
        }

        let oldCols = gridColumns
        let newCols = Self.gridColumns(forCount: sessions.count + 1)
        if newCols > oldCols {
            remapGridIndicesPreservingPositions(from: oldCols, to: newCols)
        }

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

        let oldCols = gridColumns
        viewModel(for: session).cleanup()
        sessionViewModels.removeValue(forKey: session.id)
        unseenNotificationSessionIDs.remove(session.id)
        sessions.removeAll { $0.id == session.id }

        let newCols = gridColumns
        if newCols < oldCols || !useGridLayout {
            compactGridIndicesInReadingOrder()
        }

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
        if let sessionVM = sessionViewModels[session.id] {
            return sessionVM
        }
        let sessionVM = TerminalSessionViewModel(session: session)
        sessionVM.environmentID = environmentID
        sessionVM.getNotificationSettings = getNotificationSettings
        sessionVM.getPromptButtons = getPromptButtons
        sessionVM.onStateChanged = { [weak self] in
            self?.onStateChanged?()
        }
        sessionVM.onNotificationFired = { [weak self, weak sessionVM] in
            guard let self else { return }
            // The user is actively viewing this terminal when the app is frontmost,
            // this environment is selected, and this terminal is focused. In that
            // case pulse the header for attention instead of leaving a persistent
            // highlight; otherwise mark it unseen.
            let activelyViewed = (self.isBoardActive?() ?? false) && self.focusedSessionID == session.id
            if activelyViewed {
                sessionVM?.triggerAttentionPulse()
            } else {
                self.unseenNotificationSessionIDs.insert(session.id)
            }
        }
        sessionViewModels[session.id] = sessionVM
        return sessionVM
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

    private func remapGridIndicesPreservingPositions(from oldCols: Int, to newCols: Int) {
        for session in sessions {
            let row = session.gridIndex / oldCols
            let col = session.gridIndex % oldCols
            session.gridIndex = row * newCols + col
        }
    }

    private func compactGridIndicesInReadingOrder() {
        let sorted = sessions.sorted { $0.gridIndex < $1.gridIndex }
        for (i, session) in sorted.enumerated() {
            session.gridIndex = i
        }
    }
}
