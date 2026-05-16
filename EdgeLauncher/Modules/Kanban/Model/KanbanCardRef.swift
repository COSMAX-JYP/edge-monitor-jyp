import Foundation
import CoreTransferable
import UniformTypeIdentifiers

nonisolated struct KanbanCardRef: Codable, Hashable, Sendable, Transferable {
    let cardId: UUID
    let boardId: UUID
    let sourceColumnId: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .kanbanCardRef)
    }
}

extension UTType {
    nonisolated static let kanbanCardRef = UTType(exportedAs: "com.jongyoungpark.edgelauncher.kanban-card-ref")
}
