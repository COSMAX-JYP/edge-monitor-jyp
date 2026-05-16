import Foundation

@MainActor
protocol ModuleCommandHandler: AnyObject {
    func handle(_ command: ModuleCommand) -> Bool
}
