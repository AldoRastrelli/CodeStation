import XCTest
@testable import CodeStation

// Exercises AppViewModel's backup export/import. importBackup persists to the
// real save file, so the on-disk store is preserved and restored around each
// test to avoid disturbing the developer's actual configuration.
final class SettingsBackupTests: XCTestCase {

    private var savedStoreData: Data?

    override func setUp() {
        super.setUp()
        savedStoreData = try? Data(contentsOf: PersistenceService.saveURL)
    }

    override func tearDown() {
        if let savedStoreData {
            try? savedStoreData.write(to: PersistenceService.saveURL)
        } else {
            try? FileManager.default.removeItem(at: PersistenceService.saveURL)
        }
        super.tearDown()
    }

    private func makeBackupURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("codestation-backup-\(UUID().uuidString).json")
    }

    private func sampleSnapshot(envID: UUID, folderID: UUID) -> StoreSnapshot {
        StoreSnapshot(
            environments: [
                EnvironmentSnapshot(
                    id: envID,
                    name: "Imported Env",
                    sortOrder: 0,
                    sessions: [
                        SessionSnapshot(gridIndex: 0, title: "Server", userEditedTitle: true, sessionDescription: "api", currentDirectory: "/srv"),
                        SessionSnapshot(gridIndex: 1, title: "Web", userEditedTitle: false, sessionDescription: "", currentDirectory: nil),
                    ],
                    columnProportions: [0.5, 0.5, 0.0, 0.0],
                    rowProportion: 0.3,
                    folderID: folderID,
                    isStarred: true
                )
            ],
            selectedEnvironmentID: envID,
            fontSize: 20.0,
            notificationSettings: NotificationSettings(),
            promptButtons: [PromptButton(title: "Deploy", color: "red", prompt: "make deploy")],
            skipCloseConfirmation: true,
            folders: [FolderSnapshot(id: folderID, name: "Work", sortOrder: 0, isExpanded: false)]
        )
    }

    // MARK: - Import

    func testImportBackupAppliesConfiguration() throws {
        let envID = UUID()
        let folderID = UUID()
        let url = makeBackupURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try PersistenceService.exportSnapshot(sampleSnapshot(envID: envID, folderID: folderID), to: url)

        let vm = AppViewModel()
        try vm.importBackup(from: url)

        XCTAssertEqual(vm.environments.count, 1)
        let env = try XCTUnwrap(vm.environments.first)
        XCTAssertEqual(env.name, "Imported Env")
        XCTAssertEqual(env.folderID, folderID)
        XCTAssertTrue(env.isStarred)
        XCTAssertEqual(vm.folders.count, 1)
        XCTAssertEqual(vm.folders.first?.name, "Work")
        XCTAssertEqual(vm.selectedEnvironmentID, envID)
        XCTAssertEqual(vm.fontSize, 20.0)
        XCTAssertTrue(vm.skipCloseConfirmation)
        XCTAssertEqual(vm.promptButtons.first?.title, "Deploy")
        // Terminals are queued for restore on the board rather than live yet.
        XCTAssertEqual(vm.boardViewModel(for: env).pendingRestores.count, 2)
    }

    func testImportBackupReplacesExistingConfiguration() throws {
        let vm = AppViewModel()
        vm.addEnvironment(name: "Pre-existing")
        vm.addFolder(name: "Pre-existing Folder")

        let url = makeBackupURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try PersistenceService.exportSnapshot(sampleSnapshot(envID: UUID(), folderID: UUID()), to: url)

        try vm.importBackup(from: url)

        XCTAssertEqual(vm.environments.count, 1)
        XCTAssertEqual(vm.environments.first?.name, "Imported Env")
        XCTAssertEqual(vm.folders.count, 1)
        XCTAssertEqual(vm.folders.first?.name, "Work")
    }

    func testImportInvalidBackupThrowsAndKeepsState() throws {
        let url = makeBackupURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try "garbage".data(using: .utf8)!.write(to: url)

        let vm = AppViewModel()
        let countBefore = vm.environments.count

        XCTAssertThrowsError(try vm.importBackup(from: url))
        XCTAssertEqual(vm.environments.count, countBefore)
    }

    // MARK: - Export

    func testExportBackupWritesCurrentConfiguration() throws {
        let vm = AppViewModel()
        let env = vm.addEnvironment(name: "Exported Env")
        vm.toggleStar(env)

        let url = makeBackupURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try vm.exportBackup(to: url)

        let decoded = try PersistenceService.importSnapshot(from: url)
        let match = try XCTUnwrap(decoded.environments.first { $0.name == "Exported Env" })
        XCTAssertEqual(match.isStarred, true)
    }

    // Round trip through the running view model: import known state, export it
    // back out, and confirm nothing was lost. Also covers that terminals still
    // pending restore (board never viewed) survive the export.
    func testExportAfterImportPreservesPendingTerminals() throws {
        let envID = UUID()
        let folderID = UUID()
        let importURL = makeBackupURL()
        let exportURL = makeBackupURL()
        defer {
            try? FileManager.default.removeItem(at: importURL)
            try? FileManager.default.removeItem(at: exportURL)
        }
        try PersistenceService.exportSnapshot(sampleSnapshot(envID: envID, folderID: folderID), to: importURL)

        let vm = AppViewModel()
        try vm.importBackup(from: importURL)
        try vm.exportBackup(to: exportURL)

        let decoded = try PersistenceService.importSnapshot(from: exportURL)
        let env = try XCTUnwrap(decoded.environments.first)
        XCTAssertEqual(env.sessions.count, 2)
        XCTAssertEqual(env.sessions.first?.title, "Server")
        XCTAssertEqual(env.sessions.first?.currentDirectory, "/srv")
        XCTAssertEqual(env.folderID, folderID)
        XCTAssertEqual(env.isStarred, true)
    }
}
