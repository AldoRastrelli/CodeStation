import Foundation

@Observable
class Environment: Identifiable {
    let id: UUID
    var name: String
    var sortOrder: Int
    var folderID: UUID?
    var isStarred: Bool

    init(id: UUID = UUID(), name: String, sortOrder: Int, folderID: UUID? = nil, isStarred: Bool = false) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.folderID = folderID
        self.isStarred = isStarred
    }
}
