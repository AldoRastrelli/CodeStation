import Foundation

struct StoreSnapshot: Codable {
    var environments: [EnvironmentSnapshot]
    var selectedEnvironmentID: UUID?
    var fontSize: Double
    var notificationSettings: NotificationSettings?
    var promptButtons: [PromptButton]?
    var skipCloseConfirmation: Bool?
}

struct EnvironmentSnapshot: Codable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var sessions: [SessionSnapshot]
    var columnProportions: [Double]
    var rowProportion: Double
}

struct SessionSnapshot: Codable {
    var gridIndex: Int
    var title: String
    var userEditedTitle: Bool
    var sessionDescription: String
    var currentDirectory: String?
}
