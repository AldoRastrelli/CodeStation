import XCTest
@testable import CodeStation

final class TerminalPTYTests: XCTestCase {

    // MARK: - Initial state

    func testInitialShellPidIsNegative() {
        let pty = TerminalPTY()
        XCTAssertEqual(pty.shellPid, -1)
    }

    // MARK: - Safe no-ops before start

    func testWriteBeforeStartDoesNotCrash() {
        let pty = TerminalPTY()
        pty.write(Data("hello".utf8))
    }

    func testWriteEmptyDataBeforeStartDoesNotCrash() {
        let pty = TerminalPTY()
        pty.write(Data())
    }

    func testResizeBeforeStartDoesNotCrash() {
        let pty = TerminalPTY()
        pty.resize(columns: 80, rows: 24)
    }

    func testTerminateBeforeStartDoesNotCrash() {
        let pty = TerminalPTY()
        pty.terminate()
    }

    func testDeinitBeforeStartDoesNotCrash() {
        var pty: TerminalPTY? = TerminalPTY()
        pty = nil
        XCTAssertNil(pty)
    }

    // MARK: - Start sets shellPid

    func testStartSetsPositiveShellPid() {
        let pty = TerminalPTY()
        let exp = expectation(description: "output received")
        pty.onOutput = { _ in exp.fulfill() }
        pty.start(
            executable: "/bin/echo",
            args: ["echo", "hi"],
            environment: ["PATH=/usr/bin:/bin"],
            currentDirectory: NSTemporaryDirectory(),
            columns: 80,
            rows: 24
        )
        XCTAssertGreaterThan(pty.shellPid, 0)
        wait(for: [exp], timeout: 5)
        pty.terminate()
    }

    // MARK: - Output callback

    func testStartReceivesOutput() {
        let pty = TerminalPTY()
        var received = Data()
        let exp = expectation(description: "output")
        pty.onOutput = { data in
            received.append(data)
            exp.fulfill()
        }
        pty.start(
            executable: "/bin/echo",
            args: ["echo", "hello-pty"],
            environment: ["PATH=/usr/bin:/bin"],
            currentDirectory: NSTemporaryDirectory(),
            columns: 80,
            rows: 24
        )
        wait(for: [exp], timeout: 5)
        let text = String(data: received, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("hello-pty"))
        pty.terminate()
    }

    // MARK: - Termination callback

    func testProcessExitCallsTerminatedCallback() {
        let pty = TerminalPTY()
        let exp = expectation(description: "terminated")
        pty.onTerminated = { _ in exp.fulfill() }
        pty.start(
            executable: "/bin/echo",
            args: ["echo", "bye"],
            environment: ["PATH=/usr/bin:/bin"],
            currentDirectory: NSTemporaryDirectory(),
            columns: 80,
            rows: 24
        )
        wait(for: [exp], timeout: 5)
    }

    // MARK: - Write and resize after start

    func testWriteAfterStartDoesNotCrash() {
        let pty = TerminalPTY()
        let exp = expectation(description: "output")
        exp.assertForOverFulfill = false
        pty.onOutput = { _ in exp.fulfill() }
        pty.start(
            executable: "/bin/echo",
            args: ["echo", "write-test"],
            environment: ["PATH=/usr/bin:/bin"],
            currentDirectory: NSTemporaryDirectory(),
            columns: 80,
            rows: 24
        )
        XCTAssertGreaterThan(pty.shellPid, 0)
        wait(for: [exp], timeout: 5)
        pty.write(Data("extra input\n".utf8))
        pty.terminate()
    }

    func testResizeAfterStartDoesNotCrash() {
        let pty = TerminalPTY()
        let exp = expectation(description: "output")
        exp.assertForOverFulfill = false
        pty.onOutput = { _ in exp.fulfill() }
        pty.start(
            executable: "/bin/echo",
            args: ["echo", "resize-test"],
            environment: ["PATH=/usr/bin:/bin"],
            currentDirectory: NSTemporaryDirectory(),
            columns: 80,
            rows: 24
        )
        wait(for: [exp], timeout: 5)
        pty.resize(columns: 120, rows: 40)
        pty.terminate()
    }

    // MARK: - Terminate after start

    func testTerminateAfterStartDoesNotCrash() {
        let pty = TerminalPTY()
        let exp = expectation(description: "output")
        exp.assertForOverFulfill = false
        pty.onOutput = { _ in exp.fulfill() }
        pty.start(
            executable: "/bin/echo",
            args: ["echo", "terminate-test"],
            environment: ["PATH=/usr/bin:/bin"],
            currentDirectory: NSTemporaryDirectory(),
            columns: 80,
            rows: 24
        )
        wait(for: [exp], timeout: 5)
        pty.terminate()
        XCTAssertGreaterThan(pty.shellPid, 0) // pid set at start, not cleared on terminate
    }
}
