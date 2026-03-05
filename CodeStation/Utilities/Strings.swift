import Foundation

enum Strings {
    // MARK: - App
    enum App {
        static let name = "CodeStation"
        static let zoomIn = "Zoom In"
        static let zoomOut = "Zoom Out"
        static let actualSize = "Actual Size"
        static let viewMenu = "View"
    }

    // MARK: - Environments
    enum Environments {
        static let defaultName = "Default"
        static func newName(_ count: Int) -> String { "Environment \(count)" }
        static let noEnvironments = "No environments"
        static let selectEnvironment = "Select an environment"
        static let createEnvironment = "Create Environment"
        static let newEnvironment = "New Environment"
        static let rename = "Rename"
        static let delete = "Delete"
    }

    // MARK: - Terminals
    enum Terminals {
        static func defaultTitle(_ index: Int) -> String { "Terminal \(index + 1)" }
        static func sessionCount(_ count: Int, max: Int) -> String { "\(count)/\(max)" }
        static let noTerminals = "No terminals open"
        static let openTerminal = "Open Terminal"
        static let newTerminal = "New Terminal"
        static let addTerminal = "Add terminal"
        static let closeTerminal = "Close terminal"
        static let closeTerminalTitle = "Close Terminal"
        static let cancel = "Cancel"
        static let close = "Close"
        static func closeConfirmation(_ title: String) -> String {
            "Are you sure you want to close \"\(title)\"? The running process will be terminated and all history on this terminal will be lost."
        }
        static let titlePlaceholder = "Title"
        static let descriptionPlaceholder = "Description"
        static let namePlaceholder = "Name"
    }

    // MARK: - Status
    enum Status {
        static let cooking = "Cooking"
        static let ready = "Ready"
        static let asleep = "Asleep"
        static let waiting = "Waiting"
        static let cookingEmoji = "♨️"
        static let readyEmoji = "🟢"
        static let asleepEmoji = "🌙"
        static let waitingEmoji = "🟠"
    }

    // MARK: - Persistence
    enum Persistence {
        static let appSupportDir = "CodeStation"
        static let filename = "environments.json"
        static let saveFailed = "EnvironmentStore: save failed:"
        static let loadFailed = "EnvironmentStore: load failed:"
    }

    // MARK: - Shell
    enum Shell {
        static let fallbackShell = "/bin/zsh"
        static let termValue = "xterm-256color"
        static let colorTermValue = "truecolor"
        static let loginFlag = "-l"
        static let sessionEnvVar = "CODESTATION_SESSION_ID"
        static let termPrefix = "TERM="
        static let colorTermPrefix = "COLORTERM="
        static let zdotdirPrefix = "ZDOTDIR="
        static let bashEnvPrefix = "BASH_ENV="
        static let envPrefix = "ENV="
        static let zshSuffix = "/zsh"
        static let osc7TmpDir = "codestation_rc"
        static let zshrcFilename = ".zshrc"
        static let bashrcFilename = ".bashrc_codestation"
    }

    // MARK: - SF Symbols
    enum Icons {
        static let plus = "plus"
        static let plusCircle = "plus.circle"
        static let plusCircleFill = "plus.circle.fill"
        static let xmark = "xmark"
        static let terminal = "terminal"
        static let grid = "square.grid.2x2"
        static let gear = "gearshape"
    }

    // MARK: - Settings
    enum Settings {
        static let windowTitle = "Settings"
        static let windowID = "settings"
        static let notifyWhen = "Notify when"
        static let soundSection = "Sound"
    }

    // MARK: - Notifications
    enum Notifications {
        static let sectionTitle = "Notifications"
        static let enableToggle = "Show Notifications"
        static let whenDoneToggle = "When done"
        static let whenWaitingToggle = "When waiting"
        static let doneTitle = "Task Complete"
        static func doneBody(_ sessionTitle: String) -> String { "\(sessionTitle) terminal is ready" }
        static let waitingTitle = "Action Required"
        static func waitingBody(_ sessionTitle: String) -> String { "\(sessionTitle) terminal is waiting for input" }
        static let makeSoundToggle = "Make Sound"
        static let soundPicker = "Sound"
    }

    // MARK: - Custom Prompts
    enum CustomPrompts {
        static let sectionTitle = "Custom Prompts"
        static let addPrompt = "Add Prompt"
        static let editPrompt = "Edit Prompt"
        static let deletePrompt = "Delete"
        static let titlePlaceholder = "Button title"
        static let promptPlaceholder = "Prompt text to send..."
        static let colorLabel = "Color"
        static let noPrompts = "No custom prompts yet"
        static let promptLabel = "Prompt"
        static let buttonsLabel = "Buttons"
        static let duplicateName = "A prompt with this name already exists"
        static let duplicatePrompt = "Duplicate"
    }

    // MARK: - Hooks
    enum Hooks {
        static let stateDirectory = "/tmp/codestation"
        static let hookMarker = "codestation_hook.py"
        static let settingsKey = "hooks"
        static let commandType = "command"
        static let hooksKey = "hooks"
        static let eventKey = "event"
        static let timestampKey = "timestamp"
        static let typeKey = "type"
    }
}
