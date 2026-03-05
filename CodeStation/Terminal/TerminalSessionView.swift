import SwiftUI
import SwiftTerm
import AppKit

/// Custom subclass to intercept data output for status tracking
class ObservableTerminalView: LocalProcessTerminalView {
    var onDataReceived: ((ArraySlice<UInt8>) -> Void)?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onDataReceived?(slice)
    }
}

struct TerminalSessionView: NSViewRepresentable {
    let viewModel: TerminalSessionViewModel

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let coordinator = context.coordinator
        coordinator.viewModel = viewModel

        DispatchQueue.main.async {
            guard coordinator.terminalView == nil else { return }
            coordinator.setupTerminal(in: container, viewModel: viewModel)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let tv = context.coordinator.terminalView, tv.superview !== nsView {
            tv.removeFromSuperview()
            tv.frame = nsView.bounds
            tv.autoresizingMask = [.width, .height]
            nsView.addSubview(tv)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        private enum Constants {
            static let statusTimerInterval: TimeInterval = 3.0
            static let defaultFontSize: CGFloat = 13
            static let foregroundColor = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
            static let backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
            static let osc7HookDelay: TimeInterval = 0.5
            static let filePermissions: Int = 0o755
        }

        var terminalView: ObservableTerminalView?
        var viewModel: TerminalSessionViewModel?
        private var statusTimer: Timer?

        override init() {
            super.init()
            statusTimer = Timer.scheduledTimer(withTimeInterval: Constants.statusTimerInterval, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.viewModel?.updateStatusFromOutput()
                }
            }
        }

        deinit {
            statusTimer?.invalidate()
        }

        func setupTerminal(in container: NSView, viewModel: TerminalSessionViewModel) {
            let terminalView = ObservableTerminalView(frame: container.bounds)
            terminalView.autoresizingMask = [.width, .height]

            let session = viewModel.session
            let shell = ShellUtils.defaultShell()
            var env = ShellUtils.shellEnvironment()
            env.append("\(Strings.Shell.sessionEnvVar)=\(session.id.uuidString)")
            env.removeAll { $0.hasPrefix(Strings.Shell.termPrefix) }
            env.append("\(Strings.Shell.termPrefix)\(Strings.Shell.termValue)")
            env.removeAll { $0.hasPrefix(Strings.Shell.colorTermPrefix) }
            env.append("\(Strings.Shell.colorTermPrefix)\(Strings.Shell.colorTermValue)")

            terminalView.font = NSFont.monospacedSystemFont(ofSize: Constants.defaultFontSize, weight: .regular)
            terminalView.nativeForegroundColor = Constants.foregroundColor
            terminalView.nativeBackgroundColor = Constants.backgroundColor
            terminalView.getTerminal().silentLog = true

            terminalView.processDelegate = self
            self.terminalView = terminalView

            terminalView.onDataReceived = { [weak self] slice in
                self?.handleDataReceived(slice: slice)
            }

            container.addSubview(terminalView)

            viewModel.terminalView = terminalView
            viewModel.startHookMonitoring()

            Self.installOSC7Hook(shell: shell, env: &env)

            let workingDir = session.currentDirectory ?? ShellUtils.homeDirectory()
            terminalView.startProcess(
                executable: shell,
                args: [Strings.Shell.loginFlag],
                environment: env,
                execName: shell,
                currentDirectory: workingDir
            )
        }

        func handleDataReceived(slice: ArraySlice<UInt8>) {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel?.recordDataReceived()
            }
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            guard let directory = directory else { return }
            let path: String
            if let url = URL(string: directory), url.scheme == "file" {
                path = url.path
            } else {
                path = directory
            }
            guard !path.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                self?.viewModel?.updateDirectory(path)
            }
        }

        private static func installOSC7Hook(shell: String, env: inout [String]) {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(Strings.Shell.osc7TmpDir)
            try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

            if shell.hasSuffix(Strings.Shell.zshSuffix) {
                let realHome = ShellUtils.homeDirectory()
                let rc = """
                # Source user's real rc files
                if [[ -f "\(realHome)/.zshenv" ]]; then source "\(realHome)/.zshenv"; fi
                if [[ -f "\(realHome)/.zprofile" ]]; then source "\(realHome)/.zprofile"; fi
                if [[ -f "\(realHome)/.zshrc" ]]; then source "\(realHome)/.zshrc"; fi
                # OSC 7 directory reporting for CodeStation
                __codestation_osc7() { printf '\\e]7;file://%s%s\\a' "$HOST" "$PWD"; }
                autoload -Uz add-zsh-hook
                add-zsh-hook chpwd __codestation_osc7
                __codestation_osc7
                """
                let rcPath = tmpDir.appendingPathComponent(Strings.Shell.zshrcFilename)
                try? rc.write(to: rcPath, atomically: true, encoding: .utf8)

                env.removeAll { $0.hasPrefix(Strings.Shell.zdotdirPrefix) }
                env.append("\(Strings.Shell.zdotdirPrefix)\(tmpDir.path)")
            } else {
                let rc = """
                # Source user's real rc files
                if [[ -f "$HOME/.bash_profile" ]]; then source "$HOME/.bash_profile";
                elif [[ -f "$HOME/.profile" ]]; then source "$HOME/.profile"; fi
                if [[ -f "$HOME/.bashrc" ]]; then source "$HOME/.bashrc"; fi
                # OSC 7 directory reporting for CodeStation
                __codestation_osc7() { printf '\\e]7;file://%s%s\\a' "$(hostname)" "$PWD"; }
                PROMPT_COMMAND="__codestation_osc7${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
                __codestation_osc7
                """
                let rcPath = tmpDir.appendingPathComponent(Strings.Shell.bashrcFilename)
                try? rc.write(to: rcPath, atomically: true, encoding: .utf8)

                env.removeAll { $0.hasPrefix(Strings.Shell.bashEnvPrefix) }
                env.append("\(Strings.Shell.bashEnvPrefix)\(rcPath.path)")
                env.removeAll { $0.hasPrefix(Strings.Shell.envPrefix) }
                env.append("\(Strings.Shell.envPrefix)\(rcPath.path)")
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel?.markProcessTerminated()
            }
        }
    }
}
