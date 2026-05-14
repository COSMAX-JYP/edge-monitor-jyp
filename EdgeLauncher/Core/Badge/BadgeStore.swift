import Combine
import Foundation

@MainActor
final class BadgeStore: ObservableObject {
    static let shared = BadgeStore()

    @Published var counts: [String: Int] = [:]
    @Published var debug: [String: String] = [:]

    func set(_ id: String, count: Int) {
        if count <= 0 {
            counts.removeValue(forKey: id)
        } else {
            counts[id] = count
        }
    }

    func setDebug(_ id: String, _ text: String) {
        debug[id] = text
    }
}
