import Foundation

enum HookManager {
    private enum Constants {
        static let claudeDir = "/.claude"
        static let hookScriptName = "codestation_hook.py"
        static let settingsName = "settings.json"
        static let filePermissions: Int = 0o755
    }

    static let hookScriptPath = NSHomeDirectory() + "\(Constants.claudeDir)/\(Constants.hookScriptName)"
    static let settingsPath = NSHomeDirectory() + "\(Constants.claudeDir)/\(Constants.settingsName)"
    static let stateDirectory = Strings.Hooks.stateDirectory
    static let hookMarker = Strings.Hooks.hookMarker

    static let hookEvents = [
        "PreToolUse",
        "PostToolUse",
        "PostToolUseFailure",
        "Stop",
        "StopFailure",
        "UserPromptSubmit",
        "Notification",
        "SubagentStart",
        "SubagentStop",
        "SessionStart",
        "SessionEnd",
        "PermissionRequest",
        "PermissionDenied",
        "TeammateIdle",
        "TaskCreated",
        "TaskCompleted",
        "ConfigChange",
        "PreCompact",
        "PostCompact",
        "Elicitation",
        "ElicitationResult"
    ]

    static let hookScript = """
    #!/usr/bin/env python3
    import os, json, sys, time

    def main():
        session_id = os.environ.get("CODESTATION_SESSION_ID")
        if not session_id:
            return

        event = sys.argv[1] if len(sys.argv) > 1 else "unknown"
        state_dir = "\(Strings.Hooks.stateDirectory)"
        os.makedirs(state_dir, exist_ok=True)

        state_file = os.path.join(state_dir, f"{session_id}.json")
        with open(state_file, "w") as f:
            json.dump({"event": event, "timestamp": time.time()}, f)

    if __name__ == "__main__":
        main()
    """

    static var isInstalled: Bool {
        guard let hooks = readHooksFromSettings() else { return false }
        for event in hookEvents {
            if let entries = hooks[event] as? [[String: Any]] {
                if entries.contains(where: { entryContainsMarker($0) }) {
                    return true
                }
            }
        }
        return false
    }

    static func install() throws {
        let claudeDir = NSHomeDirectory() + Constants.claudeDir
        try FileManager.default.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        try hookScript.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: Constants.filePermissions], ofItemAtPath: hookScriptPath)
        try FileManager.default.createDirectory(atPath: stateDirectory, withIntermediateDirectories: true)

        var settings = readSettings() ?? [:]
        var hooks = settings[Strings.Hooks.settingsKey] as? [String: Any] ?? [:]

        for event in hookEvents {
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.removeAll { entryContainsMarker($0) }
            entries.append([
                Strings.Hooks.hooksKey: [
                    [
                        Strings.Hooks.typeKey: Strings.Hooks.commandType,
                        "command": "python3 \(hookScriptPath) \(event)"
                    ]
                ]
            ])
            hooks[event] = entries
        }

        settings[Strings.Hooks.settingsKey] = hooks
        try writeSettings(settings)
    }

    // MARK: - State file reading

    static func stateFilePath(for sessionID: UUID) -> String {
        "\(stateDirectory)/\(sessionID.uuidString).json"
    }

    struct HookState {
        let event: String
        let timestamp: Date

        var status: SessionStatus {
            switch event {
            case "UserPromptSubmit", "PreToolUse", "SubagentStart",
                 "PostToolUse", "PostToolUseFailure", "SubagentStop",
                 "PreCompact", "ElicitationResult", "TaskCreated":
                return .cooking
            case "Stop", "StopFailure", "TaskCompleted", "SessionStart",
                 "ConfigChange", "PostCompact":
                return .ready
            case "Notification", "PermissionRequest", "PermissionDenied",
                 "Elicitation":
                return .waiting
            case "SessionEnd", "TeammateIdle":
                return .asleep
            default:
                return .ready
            }
        }
    }

    static func readState(for sessionID: UUID) -> HookState? {
        let path = stateFilePath(for: sessionID)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json[Strings.Hooks.eventKey] as? String,
              let timestamp = json[Strings.Hooks.timestampKey] as? Double else { return nil }
        return HookState(event: event, timestamp: Date(timeIntervalSince1970: timestamp))
    }

    static func cleanupState(for sessionID: UUID) {
        try? FileManager.default.removeItem(atPath: stateFilePath(for: sessionID))
    }

    // MARK: - Private helpers

    private static func entryContainsMarker(_ entry: [String: Any]) -> Bool {
        if let cmd = entry["command"] as? String, cmd.contains(hookMarker) {
            return true
        }
        if let innerHooks = entry[Strings.Hooks.hooksKey] as? [[String: Any]] {
            return innerHooks.contains { inner in
                (inner["command"] as? String)?.contains(hookMarker) == true
            }
        }
        return false
    }

    private static func readSettings() -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: settingsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    private static func readHooksFromSettings() -> [String: Any]? {
        readSettings()?[Strings.Hooks.settingsKey] as? [String: Any]
    }

    private static func writeSettings(_ settings: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: settingsPath))
    }
}
