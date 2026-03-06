import XCTest
@testable import CodeStation

final class PromptButtonTests: XCTestCase {

    // MARK: - Init

    func testInit() {
        let button = PromptButton(title: "Test", color: "blue", prompt: "run tests")
        XCTAssertEqual(button.title, "Test")
        XCTAssertEqual(button.color, "blue")
        XCTAssertEqual(button.prompt, "run tests")
        XCTAssertNotNil(button.id)
    }

    func testUniqueIDs() {
        let a = PromptButton(title: "A", color: "blue", prompt: "a")
        let b = PromptButton(title: "B", color: "red", prompt: "b")
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - Available Colors

    func testAvailableColorsCount() {
        XCTAssertEqual(PromptButton.availableColors.count, 6)
    }

    func testAvailableColorsContainsExpected() {
        let expected = ["blue", "red", "green", "purple", "orange", "pink"]
        XCTAssertEqual(PromptButton.availableColors, expected)
    }

    func testAvailableColorsAreUnique() {
        let colors = PromptButton.availableColors
        XCTAssertEqual(Set(colors).count, colors.count)
    }

    // MARK: - Codable

    func testEncodeDecode() throws {
        let button = PromptButton(title: "Deploy", color: "green", prompt: "npm run deploy")

        let data = try JSONEncoder().encode(button)
        let decoded = try JSONDecoder().decode(PromptButton.self, from: data)

        XCTAssertEqual(button.id, decoded.id)
        XCTAssertEqual(button.title, decoded.title)
        XCTAssertEqual(button.color, decoded.color)
        XCTAssertEqual(button.prompt, decoded.prompt)
    }

    func testEncodeDecodeArray() throws {
        let buttons = [
            PromptButton(title: "A", color: "blue", prompt: "a"),
            PromptButton(title: "B", color: "red", prompt: "b"),
        ]

        let data = try JSONEncoder().encode(buttons)
        let decoded = try JSONDecoder().decode([PromptButton].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].title, "A")
        XCTAssertEqual(decoded[1].title, "B")
    }

    // MARK: - Equatable

    func testEquality() {
        let id = UUID()
        let a = PromptButton(id: id, title: "Test", color: "blue", prompt: "test")
        let b = PromptButton(id: id, title: "Test", color: "blue", prompt: "test")
        XCTAssertEqual(a, b)
    }

    func testInequalityDifferentTitle() {
        let id = UUID()
        let a = PromptButton(id: id, title: "A", color: "blue", prompt: "test")
        let b = PromptButton(id: id, title: "B", color: "blue", prompt: "test")
        XCTAssertNotEqual(a, b)
    }

    func testInequalityDifferentID() {
        let a = PromptButton(title: "Test", color: "blue", prompt: "test")
        let b = PromptButton(title: "Test", color: "blue", prompt: "test")
        XCTAssertNotEqual(a, b)
    }
}
