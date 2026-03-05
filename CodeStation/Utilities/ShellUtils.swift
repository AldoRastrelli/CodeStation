import Foundation

enum ShellUtils {
    static func defaultShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], !shell.isEmpty {
            return shell
        }
        return Strings.Shell.fallbackShell
    }

    static func homeDirectory() -> String {
        return NSHomeDirectory()
    }

    static func shellEnvironment() -> [String] {
        let env = ProcessInfo.processInfo.environment
        return env.map { "\($0.key)=\($0.value)" }
    }
}
