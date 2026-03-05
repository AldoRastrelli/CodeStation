import Foundation

struct PromptButton: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var color: String   // "blue", "red", "green", "purple", "orange", "pink"
    var prompt: String

    static let availableColors = ["blue", "red", "green", "purple", "orange", "pink"]
}
