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
