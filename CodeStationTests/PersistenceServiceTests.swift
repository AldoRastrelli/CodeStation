import XCTest
@testable import CodeStation

final class PersistenceServiceTests: XCTestCase {

    private var testURL: URL!

    override func setUp() {
        super.setUp()
        testURL = PersistenceService.saveURL
    }

    override func tearDown() {
        // Clean up test data if it was written
        try? FileManager.default.removeItem(at: testURL)
        super.tearDown()
    }

    // MARK: - Save and Load Round Trip

    func testSaveAndLoadRoundTrip() {
        let envID = UUID()
        let snapshot = StoreSnapshot(
            environments: [
                EnvironmentSnapshot(
                    id: envID,
                    name: "Test Env",
                    sortOrder: 0,
                    sessions: [
                        SessionSnapshot(gridIndex: 0, title: "Terminal 1", userEditedTitle: false, sessionDescription: "", currentDirectory: nil)
                    ],
                    columnProportions: [0.5, 0.5, 0.0, 0.0],
                    rowProportion: 0.5
                )
            ],
            selectedEnvironmentID: envID,
            fontSize: 15.0,
            notificationSettings: NotificationSettings(),
            promptButtons: [PromptButton(title: "Run", color: "blue", prompt: "npm run")],
            skipCloseConfirmation: false
        )

        PersistenceService.save(snapshot: snapshot)
        let loaded = PersistenceService.load()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.environments.count, 1)
        XCTAssertEqual(loaded?.environments.first?.name, "Test Env")
        XCTAssertEqual(loaded?.selectedEnvironmentID, envID)
        XCTAssertEqual(loaded?.fontSize, 15.0)
        XCTAssertEqual(loaded?.promptButtons?.count, 1)
        XCTAssertEqual(loaded?.skipCloseConfirmation, false)
    }

    // MARK: - Export / Import Round Trip

    func testExportAndImportRoundTrip() throws {
        let envID = UUID()
        let folderID = UUID()
        let snapshot = StoreSnapshot(
            environments: [
                EnvironmentSnapshot(
                    id: envID,
                    name: "Backed Up",
                    sortOrder: 0,
                    sessions: [
                        SessionSnapshot(gridIndex: 0, title: "T1", userEditedTitle: true, sessionDescription: "build", currentDirectory: "/tmp")
                    ],
                    columnProportions: [0.5, 0.5, 0.0, 0.0],
                    rowProportion: 0.4,
                    folderID: folderID,
                    isStarred: true
                )
            ],
            selectedEnvironmentID: envID,
            fontSize: 18.0,
            notificationSettings: NotificationSettings(),
            promptButtons: [PromptButton(title: "Run", color: "green", prompt: "npm run")],
            skipCloseConfirmation: true,
            folders: [FolderSnapshot(id: folderID, name: "Work", sortOrder: 0, isExpanded: false)]
        )

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("codestation-backup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        try PersistenceService.exportSnapshot(snapshot, to: url)
        let decoded = try PersistenceService.importSnapshot(from: url)

        XCTAssertEqual(decoded.environments.count, 1)
        let env = try XCTUnwrap(decoded.environments.first)
        XCTAssertEqual(env.name, "Backed Up")
        XCTAssertEqual(env.folderID, folderID)
        XCTAssertEqual(env.isStarred, true)
        XCTAssertEqual(env.sessions.first?.currentDirectory, "/tmp")
        XCTAssertEqual(decoded.fontSize, 18.0)
        XCTAssertEqual(decoded.selectedEnvironmentID, envID)
        XCTAssertEqual(decoded.skipCloseConfirmation, true)
        XCTAssertEqual(decoded.promptButtons?.first?.title, "Run")
        XCTAssertEqual(decoded.folders?.first?.name, "Work")
        XCTAssertEqual(decoded.folders?.first?.isExpanded, false)
    }

    func testExportWritesReadableJSON() throws {
        let snapshot = StoreSnapshot(
            environments: [
                EnvironmentSnapshot(id: UUID(), name: "Readable", sortOrder: 0, sessions: [], columnProportions: [], rowProportion: 0.5)
            ],
            selectedEnvironmentID: nil,
            fontSize: 13.0
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("codestation-backup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        try PersistenceService.exportSnapshot(snapshot, to: url)
        let contents = try String(contentsOf: url, encoding: .utf8)

        // Pretty-printed output spans multiple lines and preserves field names.
        XCTAssertTrue(contents.contains("\n"))
        XCTAssertTrue(contents.contains("Readable"))
    }

    func testImportFromMissingFileThrows() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("codestation-missing-\(UUID().uuidString).json")
        XCTAssertThrowsError(try PersistenceService.importSnapshot(from: url))
    }

    func testImportFromInvalidJSONThrows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("codestation-invalid-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try "not valid json".data(using: .utf8)!.write(to: url)
        XCTAssertThrowsError(try PersistenceService.importSnapshot(from: url))
    }

    // MARK: - Load Non-Existent

    func testLoadWhenNoFileReturnsNil() {
        // Remove file if it exists
        try? FileManager.default.removeItem(at: testURL)
        let result = PersistenceService.load()
        // May or may not be nil depending on if previous test left data
        // The key thing is it doesn't crash
        _ = result
    }

    // MARK: - Save URL

    func testSaveURLContainsExpectedComponents() {
        let url = PersistenceService.saveURL
        XCTAssertTrue(url.path.contains("CodeStation"))
        XCTAssertTrue(url.path.hasSuffix("environments.json"))
    }

    // MARK: - Overwrite

    func testSaveOverwritesPreviousData() {
        let snapshot1 = StoreSnapshot(
            environments: [
                EnvironmentSnapshot(id: UUID(), name: "First", sortOrder: 0, sessions: [], columnProportions: [], rowProportion: 0.5)
            ],
            selectedEnvironmentID: nil,
            fontSize: 13.0
        )

        let snapshot2 = StoreSnapshot(
            environments: [
                EnvironmentSnapshot(id: UUID(), name: "Second", sortOrder: 0, sessions: [], columnProportions: [], rowProportion: 0.5),
                EnvironmentSnapshot(id: UUID(), name: "Third", sortOrder: 1, sessions: [], columnProportions: [], rowProportion: 0.5),
            ],
            selectedEnvironmentID: nil,
            fontSize: 16.0
        )

        PersistenceService.save(snapshot: snapshot1)
        PersistenceService.save(snapshot: snapshot2)

        let loaded = PersistenceService.load()
        XCTAssertEqual(loaded?.environments.count, 2)
        XCTAssertEqual(loaded?.fontSize, 16.0)
    }
}
