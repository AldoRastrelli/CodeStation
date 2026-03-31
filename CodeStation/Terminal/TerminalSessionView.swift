import SwiftUI
import WebKit
import AppKit

/// WKWebView subclass that prevents WebKit from consuming Cmd+Shift+Arrow shortcuts.
/// WebKit treats these as text-selection key equivalents (extend selection to
/// line/document boundary) and handles them internally, so they never reach the
/// macOS menu bar. Overriding performKeyEquivalent lets the menu take priority.
class TerminalWebView: WKWebView {
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == [.command, .shift] {
            switch event.specialKey {
            case .leftArrow, .rightArrow, .upArrow, .downArrow:
                if NSApp.mainMenu?.performKeyEquivalent(with: event) == true {
                    return true
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Stable WKScriptMessageHandler that WKWebView holds onto permanently.
/// It forwards messages to the current coordinator via a weak reference,
/// so updating the coordinator never requires removing/re-adding handlers.
class MessageHandlerRelay: NSObject, WKScriptMessageHandler {
    weak var coordinator: TerminalSessionView.Coordinator?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        coordinator?.userContentController(userContentController, didReceive: message)
    }
}

struct TerminalSessionView: NSViewRepresentable {
    let viewModel: TerminalSessionViewModel

    func makeNSView(context: Context) -> WKWebView {
        let coordinator = context.coordinator
        coordinator.viewModel = viewModel

        // Reuse the existing WKWebView when the layout changes (e.g. switching between
        // single-row and grid). Without this, every layout transition destroys the view
        // and restarts the PTY, losing all terminal history.
        if let existing = viewModel.webView {
            viewModel.messageHandlerRelay?.coordinator = coordinator
            coordinator.webView = existing
            coordinator.adoptExistingPTY(viewModel.pty)
            (existing as? TerminalWebView)?.onMouseDown = { [weak viewModel] in
                viewModel?.onFocused?()
            }
            return existing
        }

        let relay = MessageHandlerRelay()
        relay.coordinator = coordinator
        viewModel.messageHandlerRelay = relay

        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        for name in ["input", "resize", "osc7", "ready"] {
            contentController.add(relay, name: name)
        }
        config.userContentController = contentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = TerminalWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.onMouseDown = { [weak viewModel] in
            viewModel?.onFocused?()
        }

        coordinator.webView = webView
        viewModel.webView = webView

        if let htmlURL = Bundle.main.url(forResource: "terminal", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler {
        private enum Constants {
            static let statusTimerInterval: TimeInterval = 3.0
        }

        weak var webView: WKWebView?
        var viewModel: TerminalSessionViewModel?
        private var pty: TerminalPTY?
        private var statusTimer: Timer?

        override init() {
            super.init()
            statusTimer = Timer.scheduledTimer(
                withTimeInterval: Constants.statusTimerInterval,
                repeats: true
            ) { [weak self] _ in
                DispatchQueue.main.async { self?.viewModel?.updateStatusFromOutput() }
            }
        }

        deinit {
            statusTimer?.invalidate()
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "ready":
                guard
                    let dict = message.body as? [String: Any],
                    let cols = dict["cols"] as? Int,
                    let rows = dict["rows"] as? Int
                else { return }
                startProcess(cols: UInt16(cols), rows: UInt16(rows))
                // Apply per-terminal font size and give xterm.js DOM focus.
                if let size = viewModel?.fontSize {
                    webView?.evaluateJavaScript("window.setFontSize(\(size))") { _, _ in }
                }
                webView?.evaluateJavaScript("term.focus()") { _, _ in }

            case "input":
                if let text = message.body as? String {
                    pty?.write(Data(text.utf8))
                }

            case "resize":
                if let dict = message.body as? [String: Any],
                   let cols = dict["cols"] as? Int,
                   let rows = dict["rows"] as? Int {
                    pty?.resize(columns: UInt16(cols), rows: UInt16(rows))
                }

            case "osc7":
                if let raw = message.body as? String {
                    handleOSC7(raw)
                }

            default:
                break
            }
        }

        // MARK: PTY adoption (layout change reuse path)

        func adoptExistingPTY(_ pty: TerminalPTY?) {
            guard let pty = pty else { return }
            self.pty = pty
            pty.onOutput = { [weak self] data in
                self?.writeToTerminal(data)
                self?.viewModel?.recordDataReceived()
            }
            pty.onTerminated = { [weak self] _ in
                DispatchQueue.main.async { self?.viewModel?.markProcessTerminated() }
            }
        }

        // MARK: Process startup

        private func startProcess(cols: UInt16, rows: UInt16) {
            guard let viewModel = viewModel else { return }
            let session = viewModel.session
            let shell = ShellUtils.defaultShell()
            var env = ShellUtils.shellEnvironment()
            env.append("\(Strings.Shell.sessionEnvVar)=\(session.id.uuidString)")
            env.removeAll { $0.hasPrefix(Strings.Shell.termPrefix) }
            env.append("\(Strings.Shell.termPrefix)\(Strings.Shell.termValue)")
            env.removeAll { $0.hasPrefix(Strings.Shell.colorTermPrefix) }
            env.append("\(Strings.Shell.colorTermPrefix)\(Strings.Shell.colorTermValue)")

            Self.installOSC7Hook(shell: shell, env: &env)

            let workingDir = session.currentDirectory ?? ShellUtils.homeDirectory()

            let newPTY = TerminalPTY()
            newPTY.onOutput = { [weak self] data in
                self?.writeToTerminal(data)
                self?.viewModel?.recordDataReceived()
            }
            newPTY.onTerminated = { [weak self] _ in
                DispatchQueue.main.async { self?.viewModel?.markProcessTerminated() }
            }
            newPTY.start(
                executable: shell,
                args: [Strings.Shell.loginFlag],
                environment: env,
                currentDirectory: workingDir,
                columns: cols,
                rows: rows
            )
            pty = newPTY
            viewModel.pty = newPTY
            viewModel.startHookMonitoring()
        }

        // MARK: Terminal I/O

        private func writeToTerminal(_ data: Data) {
            let base64 = data.base64EncodedString()
            webView?.evaluateJavaScript("window.termWrite('\(base64)')") { _, _ in }
        }

        // MARK: OSC 7

        private func handleOSC7(_ raw: String) {
            let path: String
            if let url = URL(string: raw), url.scheme == "file" {
                path = url.path
            } else {
                path = raw
            }
            guard !path.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                self?.viewModel?.updateDirectory(path)
            }
        }

        // MARK: OSC 7 shell hook installation

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
    }
}
