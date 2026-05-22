import Foundation

@MainActor
final class OutlookAccountStore {
    private let key = "EdgeLauncher.outlook.homeAccountId"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var homeAccountId: String? {
        get { defaults.string(forKey: key) }
        set {
            if let v = newValue { defaults.set(v, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
    }
}
