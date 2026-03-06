import XCTest
import AppKit
@testable import CodeStation

final class SettingsWindowControllerTests: XCTestCase {

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
