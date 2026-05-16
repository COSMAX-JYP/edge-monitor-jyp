import Foundation

struct ChecklistItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var text: String
    var done: Bool

    init(id: UUID = UUID(), text: String = "", done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }
}
