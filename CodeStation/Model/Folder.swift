import Foundation

@Observable
class Folder: Identifiable {
    let id: UUID
    var name: String
    var sortOrder: Int
    var isExpanded: Bool

    init(id: UUID = UUID(), name: String, sortOrder: Int, isExpanded: Bool = true) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isExpanded = isExpanded
    }
}
