import Foundation
import AppKit

@Observable
class AppViewModel {
    private enum Constants {
        static let defaultFontSize: CGFloat = 13
        static let minFontSize: CGFloat = 8
        static let maxFontSize: CGFloat = 32
        static let saveDebounceSeconds: TimeInterval = 2.0
        static let notificationName = "CodeStation.directoryChanged"
    }

    var environments: [Environment] = []
    var selectedEnvironmentID: UUID?
    var notificationSettings = NotificationSettings()
    var promptButtons: [PromptButton] = []
    var skipCloseConfirmation: Bool = false
    var pendingSessionID: UUID?
    var closeTerminalRequested = false
    var isModalOpen = false

    static let defaultFontSize: CGFloat = Constants.defaultFontSize
    static let minFontSize: CGFloat = Constants.minFontSize
    static let maxFontSize: CGFloat = Constants.maxFontSize

    var fontSize: CGFloat = Constants.defaultFontSize {
        didSet { applyFontToAll() }
    }

    static let directoryChangedNotification = Notification.Name(Constants.notificationName)

    var boardViewModels: [UUID: BoardViewModel] = [:]

    private var saveWorkItem: DispatchWorkItem?
    private var terminateObserver: Any?
    private var directoryObserver: Any?

    var selectedEnvironment: Environment? {
        environments.first { $0.id == selectedEnvironmentID }
    }

    var sortedEnvironments: [Environment] {
        environments.sorted { $0.sortOrder < $1.sortOrder }
    }

    init() {
        loadFromDisk()
        if environments.isEmpty {
            let env = Environment(name: Strings.Environments.defaultName, sortOrder: 0)
            environments.append(env)
            selectedEnvironmentID = env.id
        }

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveNow()
            self?.cleanupAllSessions()
        }

        directoryObserver = NotificationCenter.default.addObserver(
            forName: Self.directoryChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleSave()
        }
    }

    // MARK: - Zoom

    func zoomIn() {
        fontSize = min(fontSize + 1, Constants.maxFontSize)
    }

    func zoomOut() {
        fontSize = max(fontSize - 1, Constants.minFontSize)
    }

    func zoomReset() {
        fontSize = Constants.defaultFontSize
    }

    private func applyFontToAll() {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        for (_, boardVM) in boardViewModels {
            for session in boardVM.sessions {
                boardVM.viewModel(for: session).terminalView?.font = font
            }
        }
    }

    // MARK: - Environment CRUD

    @discardableResult
    func addEnvironment(name: String? = nil) -> Environment {
        let nextOrder = (environments.map(\.sortOrder).max() ?? -1) + 1
        let envName = name ?? Strings.Environments.newName(environments.count + 1)
        let env = Environment(name: envName, sortOrder: nextOrder)
        environments.append(env)
        selectedEnvironmentID = env.id
        scheduleSave()
        return env
    }

    func removeEnvironment(_ env: Environment) {
        if let boardVM = boardViewModels[env.id] {
            boardVM.cleanupAllSessions()
            boardViewModels.removeValue(forKey: env.id)
        }
        environments.removeAll { $0.id == env.id }

        if selectedEnvironmentID == env.id {
            selectedEnvironmentID = sortedEnvironments.first?.id
        }
        scheduleSave()
    }

    func moveEnvironment(from source: IndexSet, to destination: Int) {
        var sorted = sortedEnvironments
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, env) in sorted.enumerated() {
            env.sortOrder = i
        }
        scheduleSave()
    }

    func renameEnvironment(_ env: Environment, to newName: String) {
        env.name = newName
        scheduleSave()
    }

    // MARK: - Board ViewModels

    func boardViewModel(for env: Environment) -> BoardViewModel {
        if let vm = boardViewModels[env.id] {
            vm.environmentID = env.id
            return vm
        }
        let vm = BoardViewModel()
        vm.environmentID = env.id
        vm.getNotificationSettings = { [weak self] in self?.notificationSettings }
        vm.getPromptButtons = { [weak self] in self?.promptButtons ?? [] }
        vm.onAddPromptButton = { [weak self] button in
            self?.promptButtons.append(button)
            self?.scheduleSave()
        }
        vm.onUpdatePromptButton = { [weak self] updated in
            guard let self else { return }
            if let index = self.promptButtons.firstIndex(where: { $0.id == updated.id }) {
                self.promptButtons[index] = updated
                self.scheduleSave()
            }
        }
        vm.onDeletePromptButton = { [weak self] id in
            self?.promptButtons.removeAll { $0.id == id }
            self?.scheduleSave()
        }
        vm.onStateChanged = { [weak self] in
            self?.scheduleSave()
        }
        vm.getSkipCloseConfirmation = { [weak self] in self?.skipCloseConfirmation ?? false }
        vm.onSkipCloseConfirmationChanged = { [weak self] skip in
            self?.skipCloseConfirmation = skip
            self?.scheduleSave()
        }
        boardViewModels[env.id] = vm
        return vm
    }

    // MARK: - Terminal Commands

    func addTerminalOrEnvironment() {
        guard let envID = selectedEnvironmentID,
              let boardVM = boardViewModels[envID] else { return }
        if boardVM.canAddSession {
            let session = boardVM.addSession()
            if let session {
                boardVM.focusedSessionID = session.id
            }
        } else {
            // Max terminals reached — create new environment
            let currentEnv = environments.first { $0.id == envID }
            let baseName = currentEnv?.name ?? "Environment"
            let newEnv = addEnvironment(name: baseName + ".2")
            let newBoardVM = boardViewModel(for: newEnv)
            let session = newBoardVM.addSession()
            if let session {
                newBoardVM.focusedSessionID = session.id
            }
        }
    }

    func focusEnvironmentUp() {
        let sorted = sortedEnvironments
        guard !sorted.isEmpty else { return }
        let currentIndex = sorted.firstIndex(where: { $0.id == selectedEnvironmentID }) ?? 0
        let targetIndex = currentIndex == 0 ? sorted.count - 1 : currentIndex - 1
        selectedEnvironmentID = sorted[targetIndex].id
    }

    func focusEnvironmentDown() {
        let sorted = sortedEnvironments
        guard !sorted.isEmpty else { return }
        let currentIndex = sorted.firstIndex(where: { $0.id == selectedEnvironmentID }) ?? 0
        let targetIndex = currentIndex == sorted.count - 1 ? 0 : currentIndex + 1
        selectedEnvironmentID = sorted[targetIndex].id
    }

    func focusTerminalLeft() {
        guard let envID = selectedEnvironmentID,
              let boardVM = boardViewModels[envID] else { return }
        let sorted = boardVM.sessions.sorted { $0.gridIndex < $1.gridIndex }
        guard !sorted.isEmpty else { return }
        let currentIndex = sorted.firstIndex(where: { $0.id == boardVM.focusedSessionID }) ?? 0
        let targetIndex = currentIndex == 0 ? sorted.count - 1 : currentIndex - 1
        let target = sorted[targetIndex]
        boardVM.focusedSessionID = target.id
        boardVM.viewModel(for: target).makeFocused()
    }

    func focusTerminalRight() {
        guard let envID = selectedEnvironmentID,
              let boardVM = boardViewModels[envID] else { return }
        let sorted = boardVM.sessions.sorted { $0.gridIndex < $1.gridIndex }
        guard !sorted.isEmpty else { return }
        let currentIndex = sorted.firstIndex(where: { $0.id == boardVM.focusedSessionID }) ?? 0
        let targetIndex = currentIndex == sorted.count - 1 ? 0 : currentIndex + 1
        let target = sorted[targetIndex]
        boardVM.focusedSessionID = target.id
        boardVM.viewModel(for: target).makeFocused()
    }

    func focusTerminal(at gridIndex: Int) {
        guard let envID = selectedEnvironmentID,
              let boardVM = boardViewModels[envID] else { return }
        let sorted = boardVM.sessions.sorted { $0.gridIndex < $1.gridIndex }
        guard gridIndex < sorted.count else { return }
        let session = sorted[gridIndex]
        boardVM.focusedSessionID = session.id
        boardVM.viewModel(for: session).makeFocused()
    }

    // MARK: - Close Focused Terminal

    var focusedTerminalTitle: String? {
        guard let envID = selectedEnvironmentID,
              let boardVM = boardViewModels[envID],
              let sessionID = boardVM.focusedSessionID,
              let session = boardVM.sessions.first(where: { $0.id == sessionID }) else { return nil }
        return session.title
    }

    func closeFocusedTerminal() {
        guard let envID = selectedEnvironmentID,
              let boardVM = boardViewModels[envID],
              let sessionID = boardVM.focusedSessionID,
              let session = boardVM.sessions.first(where: { $0.id == sessionID }) else { return }
        boardVM.removeSession(session)
    }

    // MARK: - Navigation

    func navigateToSession(environmentID: UUID, sessionID: UUID) {
        selectedEnvironmentID = environmentID
        pendingSessionID = sessionID
    }

    // MARK: - Persistence

    func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.saveDebounceSeconds, execute: item)
    }

    private func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil

        let snapshot = StoreSnapshot(
            environments: sortedEnvironments.map { env in
                let boardVM = boardViewModels[env.id]
                let sessionSnapshots = (boardVM?.sessions ?? []).map { session in
                    SessionSnapshot(
                        gridIndex: session.gridIndex,
                        title: session.title,
                        userEditedTitle: session.isUserEditedTitle,
                        sessionDescription: session.sessionDescription,
                        currentDirectory: session.currentDirectory
                    )
                }
                return EnvironmentSnapshot(
                    id: env.id,
                    name: env.name,
                    sortOrder: env.sortOrder,
                    sessions: sessionSnapshots,
                    columnProportions: (boardVM?.columnProportions ?? []).map { Double($0) },
                    rowProportion: Double(boardVM?.rowProportion ?? 0.5)
                )
            },
            selectedEnvironmentID: selectedEnvironmentID,
            fontSize: Double(fontSize),
            notificationSettings: notificationSettings,
            promptButtons: promptButtons,
            skipCloseConfirmation: skipCloseConfirmation
        )

        PersistenceService.save(snapshot: snapshot)
    }

    private func loadFromDisk() {
        guard let snapshot = PersistenceService.load() else { return }
        environments = snapshot.environments.map { envSnapshot in
            Environment(id: envSnapshot.id, name: envSnapshot.name, sortOrder: envSnapshot.sortOrder)
        }
        selectedEnvironmentID = snapshot.selectedEnvironmentID
        fontSize = CGFloat(snapshot.fontSize)
        if let settings = snapshot.notificationSettings {
            notificationSettings = settings
        }
        if let buttons = snapshot.promptButtons {
            promptButtons = buttons
        }
        if let skip = snapshot.skipCloseConfirmation {
            skipCloseConfirmation = skip
        }

        // Pre-create board VMs with pending restores
        for envSnapshot in snapshot.environments {
            let vm = BoardViewModel()
            vm.getNotificationSettings = { [weak self] in self?.notificationSettings }
            vm.getPromptButtons = { [weak self] in self?.promptButtons ?? [] }
            vm.onAddPromptButton = { [weak self] button in
                self?.promptButtons.append(button)
                self?.scheduleSave()
            }
            vm.onUpdatePromptButton = { [weak self] updated in
                guard let self else { return }
                if let index = self.promptButtons.firstIndex(where: { $0.id == updated.id }) {
                    self.promptButtons[index] = updated
                    self.scheduleSave()
                }
            }
            vm.onDeletePromptButton = { [weak self] id in
                self?.promptButtons.removeAll { $0.id == id }
                self?.scheduleSave()
            }
            vm.onStateChanged = { [weak self] in
                self?.scheduleSave()
            }
            vm.getSkipCloseConfirmation = { [weak self] in self?.skipCloseConfirmation ?? false }
            vm.onSkipCloseConfirmationChanged = { [weak self] skip in
                self?.skipCloseConfirmation = skip
                self?.scheduleSave()
            }
            vm.columnProportions = envSnapshot.columnProportions.map { CGFloat($0) }
            vm.rowProportion = CGFloat(envSnapshot.rowProportion)
            vm.pendingRestores = envSnapshot.sessions
            boardViewModels[envSnapshot.id] = vm
        }
    }

    private func cleanupAllSessions() {
        for (_, boardVM) in boardViewModels {
            boardVM.cleanupAllSessions()
        }
    }
}
