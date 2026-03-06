import XCTest
@testable import CodeStation

final class ShellUtilsTests: XCTestCase {

    // MARK: - Default Shell

    func testDefaultShellReturnsNonEmpty() {
        let shell = ShellUtils.defaultShell()
        XCTAssertFalse(shell.isEmpty)
    }

    func testDefaultShellIsAbsolutePath() {
        let shell = ShellUtils.defaultShell()
        XCTAssertTrue(shell.hasPrefix("/"), "Shell should be an absolute path")
    }

    func testDefaultShellReturnsKnownShell() {
        let shell = ShellUtils.defaultShell()
        let knownShells = ["/bin/zsh", "/bin/bash", "/bin/sh", "/usr/local/bin/zsh", "/usr/local/bin/bash", "/opt/homebrew/bin/zsh", "/opt/homebrew/bin/bash"]
        XCTAssertTrue(knownShells.contains(shell) || shell.hasSuffix("sh"), "Unexpected shell: \(shell)")
    }

    // MARK: - Home Directory

    func testHomeDirectoryReturnsNonEmpty() {
        let home = ShellUtils.homeDirectory()
        XCTAssertFalse(home.isEmpty)
    }

    func testHomeDirectoryIsAbsolutePath() {
        let home = ShellUtils.homeDirectory()
        XCTAssertTrue(home.hasPrefix("/"))
    }

    func testHomeDirectoryMatchesNSHomeDirectory() {
        XCTAssertEqual(ShellUtils.homeDirectory(), NSHomeDirectory())
    }

    // MARK: - Shell Environment

    func testShellEnvironmentIsNotEmpty() {
        let env = ShellUtils.shellEnvironment()
        XCTAssertFalse(env.isEmpty)
    }

    func testShellEnvironmentContainsKeyValuePairs() {
        let env = ShellUtils.shellEnvironment()
        for entry in env {
            XCTAssertTrue(entry.contains("="), "Environment entry should contain '=': \(entry)")
        }
    }

    func testShellEnvironmentContainsPath() {
        let env = ShellUtils.shellEnvironment()
        let hasPath = env.contains { $0.hasPrefix("PATH=") }
        XCTAssertTrue(hasPath, "Environment should contain PATH")
    }

    func testShellEnvironmentContainsHome() {
        let env = ShellUtils.shellEnvironment()
        let hasHome = env.contains { $0.hasPrefix("HOME=") }
        XCTAssertTrue(hasHome, "Environment should contain HOME")
    }
}
