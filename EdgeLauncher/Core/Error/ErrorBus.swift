import Combine
import Foundation

@MainActor
final class ErrorBus: ObservableObject {
    static let shared = ErrorBus()

    @Published var current: AppError?

    struct AppError: Identifiable, Equatable {
        let id = UUID()
        let category: String
        let message: String
    }

    func publish(_ category: String, _ message: String) {
        current = AppError(category: category, message: message)
    }

    func dismiss() {
        current = nil
    }
}
