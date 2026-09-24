import XCTest
import SwiftUI
@testable import CodeStation

final class AppColorsTests: XCTestCase {

    func testDefaultStarColorIsInStarColors() {
        XCTAssertTrue(AppColors.starColors.contains(AppColors.defaultStarColor))
    }

    func testStarColorsHaveNoDuplicates() {
        XCTAssertEqual(AppColors.starColors.count, Set(AppColors.starColors).count)
    }

    func testKnownColorsResolveDistinctlyFromFallback() {
        // Every advertised star color must map to a real color, not the fallback.
        let sentinel = Color.black
        for name in AppColors.starColors {
            XCTAssertNotEqual(
                AppColors.color(named: name, default: sentinel),
                sentinel,
                "\(name) should resolve to a concrete color"
            )
        }
    }

    func testUnknownColorReturnsFallback() {
        XCTAssertEqual(AppColors.color(named: "not-a-color", default: .black), .black)
    }

    func testUnknownColorDefaultFallbackIsYellow() {
        XCTAssertEqual(AppColors.color(named: "not-a-color"), .yellow)
    }
}
