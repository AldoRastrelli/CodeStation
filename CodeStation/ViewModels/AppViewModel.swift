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
    var folders: [Folder] = []
    var selectedEnvironmentID: UUID? {
        didSet {
            // Leaving an environment defocuses its terminals so a terminal that
            // finished while in the background keeps its notification highlight
            // until the user actively refocuses it on return.
            if let previousID = oldValue, previousID != selectedEnvironmentID {
                boardViewModels[previousID]?.focusedSessionID = nil
            }
            markActiveTerminalSeen()
        }
    }
    var notificationSettings = NotificationSettings()
    var promptButtons: [PromptButton] = []
    var skipCloseConfirmation: Bool = false
    var closeTerminalRequested = false
    var isModalOpen = false
    var showNewEnvironmentAlert = false
    var newEnvironmentName = ""
    var showNewFolderAlert = false
    var newFolderName = ""

    static let defaultFontSize: CGFloat = Constants.defaultFontSize
    static let minFontSize: CGFloat = Constants.minFontSize
    static let maxFontSize: CGFloat = Constants.maxFontSize

    var fontSize: CGFloat = Constants.defaultFontSize

    static let directoryChangedNotification = Notification.Name(Constants.notificationName)

    var boardViewModels: [UUID: BoardViewModel] = [:]

    private var saveWorkItem: DispatchWorkItem?
    private var terminateObserver: Any?
    private var directoryObserver: Any?
    private var didBecomeActiveObserver: Any?

    var selectedEnvironment: Environment? {
        environments.first { $0.id == selectedEnvironmentID }
    }

    var sortedEnvironments: [Environment] {
        environments.sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedFolders: [Folder] {
        folders.sorted { $0.sortOrder < $1.sortOrder }
    }

    var topLevelEnvironments: [Environment] {
        sortedEnvironments.filter { $0.folderID == nil }
    }

    func environments(in folder: Folder) -> [Environment] {
        sortedEnvironments.filter { $0.folderID == folder.id }
    }

    // Flattened order of environments a user can step through, following the
    // sidebar layout: each folder's environments (only when the folder is
    // expanded) then the top-level environments.
    var visibleEnvironmentsInOrder: [Environment] {
        var result: [Environment] = []
        for folder in sortedFolders where folder.isExpanded {
            result.append(contentsOf: environments(in: folder))
        }
        result.append(contentsOf: topLevelEnvironments)
        return result
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

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.markActiveTerminalSeen()
        }
    }

    // Clears the pending notification on the terminal the user is now actively
    // viewing (after an app reactivation or an environment switch).
    private func markActiveTerminalSeen() {
        guard let envID = selectedEnvironmentID,
              let boardVM = boardViewModels[envID] else { return }
        boardVM.markFocusedTerminalSeenIfActive()
    }

    // MARK: - Zoom (per-terminal)

    func zoomIn() {
        focusedTerminalViewModel?.zoomIn()
    }

    func zoomOut() {
        focusedTerminalViewModel?.zoomOut()
    }

    func zoomReset() {
        focusedTerminalViewModel?.zoomReset()
    }

    private var focusedTerminalViewModel: TerminalSessionViewModel? {
        guard let envID = selectedEnvironmentID,
              let boardVM = boardViewModels[envID] else { return nil }
        let sessionID = boardVM.focusedSessionID ?? boardVM.sessions.first?.id
        guard let sessionID,
              let session = boardVM.sessions.first(where: { $0.id == sessionID }) else { return nil }
        return boardVM.viewModel(for: session)
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

    // Reorders environments within a single container (a folder, or the
    // top level when folderID is nil). sortOrder values stay unique per
    // container, which is all the sidebar ordering relies on.
    func moveEnvironment(from source: IndexSet, to destination: Int, inFolder folderID: UUID? = nil) {
        var container = sortedEnvironments.filter { $0.folderID == folderID }
        container.move(fromOffsets: source, toOffset: destination)
        for (i, env) in container.enumerated() {
            env.sortOrder = i
        }
        scheduleSave()
    }

    // Moves an environment into a folder (or out to the top level when
    // folderID is nil), placing it at the end of the destination container.
    func moveEnvironment(_ env: Environment, toFolder folderID: UUID?) {
        guard env.folderID != folderID else { return }
        env.folderID = folderID
        let siblings = sortedEnvironments.filter { $0.folderID == folderID && $0.id != env.id }
        env.sortOrder = (siblings.map(\.sortOrder).max() ?? -1) + 1
        scheduleSave()
    }

    func renameEnvironment(_ env: Environment, to newName: String) {
        env.name = newName
        scheduleSave()
    }

    func toggleStar(_ env: Environment) {
        env.isStarred.toggle()
        scheduleSave()
    }

    // MARK: - Folder CRUD

    @discardableResult
    func addFolder(name: String? = nil) -> Folder {
        let nextOrder = (folders.map(\.sortOrder).max() ?? -1) + 1
        let folderName = name ?? Strings.Environments.newFolderName(folders.count + 1)
        let folder = Folder(name: folderName, sortOrder: nextOrder)
        folders.append(folder)
        scheduleSave()
        return folder
    }

    // Deleting a folder keeps its environments, moving them back to the top level.
    func removeFolder(_ folder: Folder) {
        for env in environments where env.folderID == folder.id {
            env.folderID = nil
        }
        folders.removeAll { $0.id == folder.id }
        scheduleSave()
    }

    func renameFolder(_ folder: Folder, to newName: String) {
        folder.name = newName
        scheduleSave()
    }

    func setFolderExpanded(_ folder: Folder, expanded: Bool) {
        folder.isExpanded = expanded
        scheduleSave()
    }

    func moveFolder(from source: IndexSet, to destination: Int) {
        var sorted = sortedFolders
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, folder) in sorted.enumerated() {
            folder.sortOrder = i
        }
        scheduleSave()
    }

    // Reorders/moves an environment so it lands immediately before `target`,
    // adopting the target's container. Used for row-to-row drops.
    func moveEnvironment(_ dragged: Environment, before target: Environment) {
        guard dragged.id != target.id else { return }
        dragged.folderID = target.folderID
        var container = sortedEnvironments.filter { $0.folderID == target.folderID && $0.id != dragged.id }
        let targetIndex = container.firstIndex { $0.id == target.id } ?? container.count
        container.insert(dragged, at: targetIndex)
        for (i, env) in container.enumerated() {
            env.sortOrder = i
        }
        scheduleSave()
    }

    func environment(withID id: UUID) -> Environment? {
        environments.first { $0.id == id }
    }

    // MARK: - Drag & Drop

    private func draggedEnvironment(from items: [String]) -> Environment? {
        guard let first = items.first, let id = UUID(uuidString: first) else { return nil }
        return environment(withID: id)
    }

    @discardableResult
    func handleEnvironmentDrop(_ items: [String], before target: Environment) -> Bool {
        guard let dragged = draggedEnvironment(from: items) else { return false }
        moveEnvironment(dragged, before: target)
        return true
    }

    @discardableResult
    func handleEnvironmentDrop(_ items: [String], toFolder folderID: UUID?) -> Bool {
        guard let dragged = draggedEnvironment(from: items) else { return false }
        moveEnvironment(dragged, toFolder: folderID)
        return true
    }

    // MARK: - Board ViewModels

    func boardViewModel(for env: Environment) -> BoardViewModel {
        if let boardVM = boardViewModels[env.id] {
            boardVM.environmentID = env.id
            return boardVM
        }
        let boardVM = BoardViewModel()
        boardVM.environmentID = env.id
        boardVM.isBoardActive = { [weak self] in NSApp.isActive && self?.selectedEnvironmentID == env.id }
        boardVM.getNotificationSettings = { [weak self] in self?.notificationSettings }
        boardVM.getPromptButtons = { [weak self] in self?.promptButtons ?? [] }
        boardVM.onAddPromptButton = { [weak self] button in
            self?.promptButtons.append(button)
            self?.scheduleSave()
        }
        boardVM.onUpdatePromptButton = { [weak self] updated in
            guard let self else { return }
            if let index = self.promptButtons.firstIndex(where: { $0.id == updated.id }) {
                self.promptButtons[index] = updated
                self.scheduleSave()
            }
        }
        boardVM.onDeletePromptButton = { [weak self] id in
            self?.promptButtons.removeAll { $0.id == id }
            self?.scheduleSave()
        }
        boardVM.onStateChanged = { [weak self] in
            self?.scheduleSave()
        }
        boardVM.getSkipCloseConfirmation = { [weak self] in self?.skipCloseConfirmation ?? false }
        boardVM.onSkipCloseConfirmationChanged = { [weak self] skip in
            self?.skipCloseConfirmation = skip
            self?.scheduleSave()
        }
        boardViewModels[env.id] = boardVM
        return boardVM
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
        let sorted = visibleEnvironmentsInOrder
        guard !sorted.isEmpty else { return }
        let currentIndex = sorted.firstIndex(where: { $0.id == selectedEnvironmentID }) ?? 0
        let targetIndex = currentIndex == 0 ? sorted.count - 1 : currentIndex - 1
        selectedEnvironmentID = sorted[targetIndex].id
        focusFocusedTerminalInSelectedEnvironment()
    }

    func focusEnvironmentDown() {
        let sorted = visibleEnvironmentsInOrder
        guard !sorted.isEmpty else { return }
        let currentIndex = sorted.firstIndex(where: { $0.id == selectedEnvironmentID }) ?? 0
        let targetIndex = currentIndex == sorted.count - 1 ? 0 : currentIndex + 1
        selectedEnvironmentID = sorted[targetIndex].id
        focusFocusedTerminalInSelectedEnvironment()
    }

    private func focusFocusedTerminalInSelectedEnvironment() {
        guard let envID = selectedEnvironmentID,
              let boardVM = boardViewModels[envID] else { return }
        let sessionID = boardVM.focusedSessionID ?? boardVM.sessions.first?.id
        guard let sessionID,
              let session = boardVM.sessions.first(where: { $0.id == sessionID }) else { return }
        boardVM.focusedSessionID = session.id
        boardVM.viewModel(for: session).makeFocused()
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
        if let boardVM = boardViewModels[environmentID] {
            boardVM.focusedSessionID = sessionID
            if let session = boardVM.sessions.first(where: { $0.id == sessionID }) {
                boardVM.viewModel(for: session).makeFocused()
            }
        }
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
                    rowProportion: Double(boardVM?.rowProportion ?? 0.5),
                    folderID: env.folderID,
                    isStarred: env.isStarred
                )
            },
            selectedEnvironmentID: selectedEnvironmentID,
            fontSize: Double(fontSize),
            notificationSettings: notificationSettings,
            promptButtons: promptButtons,
            skipCloseConfirmation: skipCloseConfirmation,
            folders: sortedFolders.map { folder in
                FolderSnapshot(
                    id: folder.id,
                    name: folder.name,
                    sortOrder: folder.sortOrder,
                    isExpanded: folder.isExpanded
                )
            }
        )

        PersistenceService.save(snapshot: snapshot)
    }

    private func loadFromDisk() {
        guard let snapshot = PersistenceService.load() else { return }
        environments = snapshot.environments.map { envSnapshot in
            Environment(
                id: envSnapshot.id,
                name: envSnapshot.name,
                sortOrder: envSnapshot.sortOrder,
                folderID: envSnapshot.folderID,
                isStarred: envSnapshot.isStarred ?? false
            )
        }
        folders = (snapshot.folders ?? []).map { folderSnapshot in
            Folder(
                id: folderSnapshot.id,
                name: folderSnapshot.name,
                sortOrder: folderSnapshot.sortOrder,
                isExpanded: folderSnapshot.isExpanded
            )
        }
        // Drop dangling folder references so an environment whose folder no
        // longer exists reappears at the top level instead of vanishing.
        let folderIDs = Set(folders.map(\.id))
        for env in environments where env.folderID != nil && !folderIDs.contains(env.folderID!) {
            env.folderID = nil
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
            let boardVM = BoardViewModel()
            boardVM.environmentID = envSnapshot.id
            boardVM.isBoardActive = { [weak self] in NSApp.isActive && self?.selectedEnvironmentID == envSnapshot.id }
            boardVM.getNotificationSettings = { [weak self] in self?.notificationSettings }
            boardVM.getPromptButtons = { [weak self] in self?.promptButtons ?? [] }
            boardVM.onAddPromptButton = { [weak self] button in
                self?.promptButtons.append(button)
                self?.scheduleSave()
            }
            boardVM.onUpdatePromptButton = { [weak self] updated in
                guard let self else { return }
                if let index = self.promptButtons.firstIndex(where: { $0.id == updated.id }) {
                    self.promptButtons[index] = updated
                    self.scheduleSave()
                }
            }
            boardVM.onDeletePromptButton = { [weak self] id in
                self?.promptButtons.removeAll { $0.id == id }
                self?.scheduleSave()
            }
            boardVM.onStateChanged = { [weak self] in
                self?.scheduleSave()
            }
            boardVM.getSkipCloseConfirmation = { [weak self] in self?.skipCloseConfirmation ?? false }
            boardVM.onSkipCloseConfirmationChanged = { [weak self] skip in
                self?.skipCloseConfirmation = skip
                self?.scheduleSave()
            }
            boardVM.columnProportions = envSnapshot.columnProportions.map { CGFloat($0) }
            boardVM.rowProportion = CGFloat(envSnapshot.rowProportion)
            boardVM.pendingRestores = envSnapshot.sessions
            boardViewModels[envSnapshot.id] = boardVM
        }
    }

    private func cleanupAllSessions() {
        for (_, boardVM) in boardViewModels {
            boardVM.cleanupAllSessions()
        }
    }
}
