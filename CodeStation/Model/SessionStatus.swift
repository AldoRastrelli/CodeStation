import Foundation

enum SessionStatus: String, CaseIterable {
    case cooking
    case ready
    case asleep
    case waiting

    var emoji: String {
        switch self {
        case .cooking: return Strings.Status.cookingEmoji
        case .ready: return Strings.Status.readyEmoji
        case .asleep: return Strings.Status.asleepEmoji
        case .waiting: return Strings.Status.waitingEmoji
        }
    }

    var label: String {
        switch self {
        case .cooking: return Strings.Status.cooking
        case .ready: return Strings.Status.ready
        case .asleep: return Strings.Status.asleep
        case .waiting: return Strings.Status.waiting
        }
    }

    var badgeColor: String {
        switch self {
        case .cooking: return "red"
        case .ready: return "green"
        case .asleep: return "gray"
        case .waiting: return "orange"
        }
    }
}
