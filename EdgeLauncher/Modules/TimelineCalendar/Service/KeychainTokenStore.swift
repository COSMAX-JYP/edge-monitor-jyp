import Foundation
import Security

final class KeychainTokenStore {
    private let service = "com.jyp.EdgeLauncher.outlook"

    var refreshToken: String? {
        get { read(account: "refresh_token") }
        set { write(account: "refresh_token", value: newValue) }
    }

    var username: String? {
        get { read(account: "username") }
        set { write(account: "username", value: newValue) }
    }

    var homeAccountId: String? {
        get { read(account: "home_account_id") }
        set { write(account: "home_account_id", value: newValue) }
    }

    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(account: String, value: String?) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(baseQuery as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
