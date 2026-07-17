import XCTest
@testable import CodeStation

final class FolderTests: XCTestCase {

    // MARK: - Init

    func testDefaultInit() {
        let folder = Folder(name: "Work", sortOrder: 0)
        XCTAssertEqual(folder.name, "Work")
        XCTAssertEqual(folder.sortOrder, 0)
        XCTAssertTrue(folder.isExpanded)
        XCTAssertNotNil(folder.id)
    }

    func testInitWithCustomID() {
        let customID = UUID()
        let folder = Folder(id: customID, name: "Custom", sortOrder: 3, isExpanded: false)
        XCTAssertEqual(folder.id, customID)
        XCTAssertEqual(folder.name, "Custom")
        XCTAssertEqual(folder.sortOrder, 3)
        XCTAssertFalse(folder.isExpanded)
    }

    // MARK: - Identifiable

    func testUniqueIDs() {
        let a = Folder(name: "A", sortOrder: 0)
        let b = Folder(name: "B", sortOrder: 1)
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - Mutable Properties

    func testNameCanBeChanged() {
        let folder = Folder(name: "Original", sortOrder: 0)
        folder.name = "Renamed"
        XCTAssertEqual(folder.name, "Renamed")
    }

    func testExpandedCanBeToggled() {
        let folder = Folder(name: "F", sortOrder: 0)
        folder.isExpanded = false
        XCTAssertFalse(folder.isExpanded)
    }
}
