import Foundation
import Darwin

/// Manages a PTY-backed shell process.
final class TerminalPTY {
    private var masterFd: Int32 = -1
    private(set) var shellPid: pid_t = -1
    private var readSource: DispatchSourceRead?

    /// Called on the main queue with raw bytes from the shell.
    var onOutput: ((Data) -> Void)?
    /// Called on the main queue when the shell process exits.
    var onTerminated: ((Int32?) -> Void)?

    func start(
        executable: String,
        args: [String],
        environment: [String],
        currentDirectory: String,
        columns: UInt16,
        rows: UInt16
    ) {
        var ws = winsize()
        ws.ws_col = columns
        ws.ws_row = rows

        var master: Int32 = 0
        let pid = forkpty(&master, nil, nil, &ws)

        if pid < 0 { return }

        if pid == 0 {
            // Child: switch to working directory then exec the shell.
            _ = currentDirectory.withCString { chdir($0) }
            var cArgs: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString(strdup) }
            cArgs.append(nil)
            var cEnv: [UnsafeMutablePointer<CChar>?] = environment.map { $0.withCString(strdup) }
            cEnv.append(nil)
            executable.withCString { _ = execve($0, &cArgs, &cEnv) }
            exit(127)
        }

        // Parent
        masterFd = master
        shellPid = pid
        startReading()
    }

    func write(_ data: Data) {
        guard masterFd >= 0 else { return }
        data.withUnsafeBytes { _ = Darwin.write(masterFd, $0.baseAddress!, $0.count) }
    }

    func resize(columns: UInt16, rows: UInt16) {
        guard masterFd >= 0 else { return }
        var ws = winsize()
        ws.ws_col = columns
        ws.ws_row = rows
        _ = ioctl(masterFd, TIOCSWINSZ, &ws)
    }

    func terminate() {
        readSource?.cancel()
        readSource = nil
        if shellPid > 0 {
            kill(shellPid, SIGHUP)
        }
    }

    deinit {
        terminate()
    }

    // MARK: - Private

    private func startReading() {
        let source = DispatchSource.makeReadSource(fileDescriptor: masterFd, queue: .global())

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            var buf = [UInt8](repeating: 0, count: 4096)
            let n = Darwin.read(self.masterFd, &buf, buf.count)
            if n > 0 {
                let data = Data(buf[0..<n])
                DispatchQueue.main.async { self.onOutput?(data) }
            } else {
                // EIO or EOF - child exited
                self.readSource?.cancel()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            let fd = self.masterFd
            self.masterFd = -1
            Darwin.close(fd)

            var status: Int32 = 0
            if self.shellPid > 0 {
                waitpid(self.shellPid, &status, 0)
                // Replicate WIFEXITED / WEXITSTATUS without the C macros.
                let code: Int32? = (status & 0x7f) == 0 ? (status >> 8) & 0xff : nil
                DispatchQueue.main.async { self.onTerminated?(code) }
            } else {
                DispatchQueue.main.async { self.onTerminated?(nil) }
            }
        }

        source.resume()
        readSource = source
    }
}
