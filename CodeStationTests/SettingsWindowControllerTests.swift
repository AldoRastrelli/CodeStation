import XCTest
import AppKit
@testable import CodeStation

final class SettingsWindowControllerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Close any window left open by a previous test to prevent static state pollution.
        SettingsWindowController.closeForTesting()
    }

    func testShowCreatesWindow() {
        let vm = AppViewModel()
        SettingsWindowController.show(viewModel: vm)
        XCTAssertTrue(vm.isModalOpen)
    }

    func testShowTwiceReusesWindow() {
        let vm = AppViewModel()
        SettingsWindowController.show(viewModel: vm)
        SettingsWindowController.show(viewModel: vm)
        XCTAssertTrue(vm.isModalOpen)
    }
}
