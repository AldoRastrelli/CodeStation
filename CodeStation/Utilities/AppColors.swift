import SwiftUI

enum AppColors {
    // System colors offered for the environment star icon in Color Preferences.
    static let starColors = [
        "yellow", "orange", "red", "pink",
        "purple", "indigo", "blue", "cyan",
        "teal", "mint", "green", "gray",
    ]

    static let defaultStarColor = "yellow"

    static func color(named name: String, default fallback: Color = .yellow) -> Color {
        switch name {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "yellow": return .yellow
        case "teal": return .teal
        case "indigo": return .indigo
        case "mint": return .mint
        case "cyan": return .cyan
        case "gray": return .gray
        default: return fallback
        }
    }
}
