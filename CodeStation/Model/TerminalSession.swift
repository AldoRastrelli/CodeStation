import Foundation

@Observable
class TerminalSession: Identifiable {
    let id: UUID
    var title: String
    var isUserEditedTitle = false
    var sessionDescription: String
    var status: SessionStatus
    var lastOutputTime: Date?
    var lastHookEventTime: Date?
    var gridIndex: Int
    var currentDirectory: String?

    init(gridIndex: Int, title: String? = nil) {
        self.id = UUID()
        self.gridIndex = gridIndex
        self.title = title ?? Strings.Terminals.defaultTitle(gridIndex)
        self.sessionDescription = ""
        self.status = .ready
        self.lastOutputTime = nil
    }
}
