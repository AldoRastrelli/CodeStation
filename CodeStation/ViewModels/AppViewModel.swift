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
    var pendingSessionID: UUID?

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
        vm.onStateChanged = { [weak self] in
            self?.scheduleSave()
        }
        boardViewModels[env.id] = vm
        return vm
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
            promptButtons: promptButtons
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

        // Pre-create board VMs with pending restores
        for envSnapshot in snapshot.environments {
            let vm = BoardViewModel()
            vm.getNotificationSettings = { [weak self] in self?.notificationSettings }
            vm.getPromptButtons = { [weak self] in self?.promptButtons ?? [] }
            vm.onAddPromptButton = { [weak self] button in
                self?.promptButtons.append(button)
                self?.scheduleSave()
            }
            vm.onStateChanged = { [weak self] in
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
