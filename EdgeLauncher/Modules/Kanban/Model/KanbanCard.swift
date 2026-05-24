import Foundation

struct KanbanCard: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var notes: String
    var labelIds: [UUID]
    var dueDate: Date?
    var colorHex: String?
    var assignee: String
    var checklist: [ChecklistItem]
    var attachments: [Attachment]
    /// SlidePad 의 3:7 분할 구조에서 카드가 위쪽 30% 영역인지. false = 아래쪽 70%.
    /// 기본값 false (하단). 메인 윈도우 칸반에서는 영향 없음.
    var isUpper: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        labelIds: [UUID] = [],
        dueDate: Date? = nil,
        colorHex: String? = nil,
        assignee: String = "",
        checklist: [ChecklistItem] = [],
        attachments: [Attachment] = [],
        isUpper: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.labelIds = labelIds
        self.dueDate = dueDate
        self.colorHex = colorHex
        self.assignee = assignee
        self.checklist = checklist
        self.attachments = attachments
        self.isUpper = isUpper
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.labelIds = try c.decodeIfPresent([UUID].self, forKey: .labelIds) ?? []
        self.dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        self.colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        self.assignee = try c.decodeIfPresent(String.self, forKey: .assignee) ?? ""
        self.checklist = try c.decodeIfPresent([ChecklistItem].self, forKey: .checklist) ?? []
        self.attachments = try c.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        self.isUpper = try c.decodeIfPresent(Bool.self, forKey: .isUpper) ?? false
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    var progress: Double {
        guard !checklist.isEmpty else { return 0 }
        let done = checklist.filter(\.done).count
        return Double(done) / Double(checklist.count)
    }

    var checklistDone: Int { checklist.filter(\.done).count }
    var hasCompletedChecklist: Bool {
        !checklist.isEmpty && checklist.allSatisfy(\.done)
    }
}
