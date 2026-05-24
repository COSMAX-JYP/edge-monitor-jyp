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

        // nil 이면 삭제만.
        guard let value, let data = value.data(using: .utf8) else {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }

        // upsert: 기존 item 의 ACL("항상 허용") 을 보존하기 위해 delete+add 대신 update 우선.
        // delete+add 는 ACL trusted-application list 가 매번 새로 만들어져 사용자가 반복 프롬프트를 보게 된다.
        let updateAttrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess { return }

        // 신규 item — ACL 부여 (첫 저장 시 사용자가 "항상 허용" 한 번 누르면 끝).
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
