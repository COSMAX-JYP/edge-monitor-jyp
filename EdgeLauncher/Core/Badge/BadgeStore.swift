import Combine
import Foundation

@MainActor
final class BadgeStore: ObservableObject {
    static let shared = BadgeStore()

    @Published var counts: [String: Int] = [:]

    func set(_ id: String, count: Int) {
        if count <= 0 {
            counts.removeValue(forKey: id)
        } else {
            counts[id] = count
        }
    }
}
