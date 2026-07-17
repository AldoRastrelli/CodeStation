import Foundation

struct StoreSnapshot: Codable {
    var environments: [EnvironmentSnapshot]
    var selectedEnvironmentID: UUID?
    var fontSize: Double
    var notificationSettings: NotificationSettings?
    var promptButtons: [PromptButton]?
    var skipCloseConfirmation: Bool?
    var folders: [FolderSnapshot]?
}

struct FolderSnapshot: Codable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var isExpanded: Bool
}

struct EnvironmentSnapshot: Codable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var sessions: [SessionSnapshot]
    var columnProportions: [Double]
    var rowProportion: Double
    var folderID: UUID? = nil
    var isStarred: Bool? = nil
}

struct SessionSnapshot: Codable {
    var gridIndex: Int
    var title: String
    var userEditedTitle: Bool
    var sessionDescription: String
    var currentDirectory: String?
}
