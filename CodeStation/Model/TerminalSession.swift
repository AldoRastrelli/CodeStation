import Foundation
import UniformTypeIdentifiers

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

/// Pasteboard payload for reordering terminals by dragging their headers.
/// Uses the NSItemProvider based onDrag/onDrop API: SwiftUI's Transferable
/// dropDestination was never targeted by these drags on macOS.
enum TerminalDragPayload {
    static let contentTypes: [UTType] = [.utf8PlainText, .plainText]

    static func itemProvider(for sessionID: UUID) -> NSItemProvider {
        NSItemProvider(object: sessionID.uuidString as NSString)
    }

    static func sessionID(from string: String) -> UUID? {
        UUID(uuidString: string)
    }

    /// Returns false when no provider carries a string. The completion runs on
    /// whatever queue NSItemProvider picks, so callers hop to main themselves.
    @discardableResult
    static func loadSessionID(from providers: [NSItemProvider], completion: @escaping (UUID?) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            completion((object as? NSString).flatMap { sessionID(from: $0 as String) })
        }
        return true
    }
}
