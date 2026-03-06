import XCTest
@testable import CodeStation

final class EnvironmentTests: XCTestCase {

    // MARK: - Init

    func testDefaultInit() {
        let env = Environment(name: "Test", sortOrder: 0)
        XCTAssertEqual(env.name, "Test")
        XCTAssertEqual(env.sortOrder, 0)
        XCTAssertNotNil(env.id)
    }

    func testInitWithCustomID() {
        let customID = UUID()
        let env = Environment(id: customID, name: "Custom", sortOrder: 3)
        XCTAssertEqual(env.id, customID)
        XCTAssertEqual(env.name, "Custom")
        XCTAssertEqual(env.sortOrder, 3)
    }

    // MARK: - Identifiable

    func testUniqueIDs() {
        let env1 = Environment(name: "A", sortOrder: 0)
        let env2 = Environment(name: "B", sortOrder: 1)
        XCTAssertNotEqual(env1.id, env2.id)
    }

    // MARK: - Mutable Properties

    func testNameCanBeChanged() {
        let env = Environment(name: "Original", sortOrder: 0)
        env.name = "Renamed"
        XCTAssertEqual(env.name, "Renamed")
    }

    func testSortOrderCanBeChanged() {
        let env = Environment(name: "Test", sortOrder: 0)
        env.sortOrder = 5
        XCTAssertEqual(env.sortOrder, 5)
    }
}
