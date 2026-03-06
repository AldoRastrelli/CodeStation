import XCTest
@testable import CodeStation

final class PersistenceModelsTests: XCTestCase {

    // MARK: - SessionSnapshot

    func testSessionSnapshotEncodeDecode() throws {
        let snapshot = SessionSnapshot(
            gridIndex: 2,
            title: "Test Terminal",
            userEditedTitle: true,
            sessionDescription: "Running tests",
            currentDirectory: "/Users/test"
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: data)

        XCTAssertEqual(decoded.gridIndex, 2)
        XCTAssertEqual(decoded.title, "Test Terminal")
        XCTAssertTrue(decoded.userEditedTitle)
        XCTAssertEqual(decoded.sessionDescription, "Running tests")
        XCTAssertEqual(decoded.currentDirectory, "/Users/test")
    }

    func testSessionSnapshotNilDirectory() throws {
        let snapshot = SessionSnapshot(
            gridIndex: 0,
            title: "Terminal 1",
            userEditedTitle: false,
            sessionDescription: "",
            currentDirectory: nil
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: data)

        XCTAssertNil(decoded.currentDirectory)
    }

    // MARK: - EnvironmentSnapshot

    func testEnvironmentSnapshotEncodeDecode() throws {
        let envSnapshot = EnvironmentSnapshot(
            id: UUID(),
            name: "Dev",
            sortOrder: 0,
            sessions: [
                SessionSnapshot(gridIndex: 0, title: "T1", userEditedTitle: false, sessionDescription: "", currentDirectory: nil),
                SessionSnapshot(gridIndex: 1, title: "T2", userEditedTitle: true, sessionDescription: "Build", currentDirectory: "/tmp"),
            ],
            columnProportions: [0.25, 0.25, 0.25, 0.25],
            rowProportion: 0.5
        )

        let data = try JSONEncoder().encode(envSnapshot)
        let decoded = try JSONDecoder().decode(EnvironmentSnapshot.self, from: data)

        XCTAssertEqual(decoded.name, "Dev")
        XCTAssertEqual(decoded.sortOrder, 0)
        XCTAssertEqual(decoded.sessions.count, 2)
        XCTAssertEqual(decoded.columnProportions, [0.25, 0.25, 0.25, 0.25])
        XCTAssertEqual(decoded.rowProportion, 0.5)
    }

    func testEnvironmentSnapshotEmptySessions() throws {
        let envSnapshot = EnvironmentSnapshot(
            id: UUID(),
            name: "Empty",
            sortOrder: 1,
            sessions: [],
            columnProportions: [],
            rowProportion: 0.5
        )

        let data = try JSONEncoder().encode(envSnapshot)
        let decoded = try JSONDecoder().decode(EnvironmentSnapshot.self, from: data)

        XCTAssertTrue(decoded.sessions.isEmpty)
    }

    // MARK: - StoreSnapshot

    func testStoreSnapshotEncodeDecode() throws {
        let envID = UUID()
        let snapshot = StoreSnapshot(
            environments: [
                EnvironmentSnapshot(
                    id: envID,
                    name: "Main",
                    sortOrder: 0,
                    sessions: [],
                    columnProportions: [0.5, 0.5],
                    rowProportion: 0.5
                )
            ],
            selectedEnvironmentID: envID,
            fontSize: 14.0,
            notificationSettings: NotificationSettings(),
            promptButtons: [
                PromptButton(title: "Run", color: "green", prompt: "npm run")
            ],
            skipCloseConfirmation: true
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(StoreSnapshot.self, from: data)

        XCTAssertEqual(decoded.environments.count, 1)
        XCTAssertEqual(decoded.selectedEnvironmentID, envID)
        XCTAssertEqual(decoded.fontSize, 14.0)
        XCTAssertNotNil(decoded.notificationSettings)
        XCTAssertEqual(decoded.promptButtons?.count, 1)
        XCTAssertEqual(decoded.skipCloseConfirmation, true)
    }

    func testStoreSnapshotOptionalFieldsNil() throws {
        let snapshot = StoreSnapshot(
            environments: [],
            selectedEnvironmentID: nil,
            fontSize: 13.0,
            notificationSettings: nil,
            promptButtons: nil,
            skipCloseConfirmation: nil
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(StoreSnapshot.self, from: data)

        XCTAssertTrue(decoded.environments.isEmpty)
        XCTAssertNil(decoded.selectedEnvironmentID)
        XCTAssertEqual(decoded.fontSize, 13.0)
        XCTAssertNil(decoded.notificationSettings)
        XCTAssertNil(decoded.promptButtons)
        XCTAssertNil(decoded.skipCloseConfirmation)
    }

    func testStoreSnapshotPreservesEnvironmentID() throws {
        let id = UUID()
        let snapshot = StoreSnapshot(
            environments: [
                EnvironmentSnapshot(id: id, name: "E", sortOrder: 0, sessions: [], columnProportions: [], rowProportion: 0.5)
            ],
            selectedEnvironmentID: id,
            fontSize: 13.0
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(StoreSnapshot.self, from: data)

        XCTAssertEqual(decoded.environments.first?.id, id)
        XCTAssertEqual(decoded.selectedEnvironmentID, id)
    }
}
