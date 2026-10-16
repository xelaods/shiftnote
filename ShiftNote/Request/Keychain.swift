import Foundation
import Security

/// シフコンのログイン情報・Cookie をこの iPhone のキーチェーンに保存する
enum Keychain {
    private static let service = "app.shiftnote.shifcon"

    static func data(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    static func set(_ data: Data?, for key: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(base as CFDictionary)
        guard let data else { return true }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func dictionary(_ key: String) -> [String: String]? {
        guard let d = data(key) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: d)
    }

    @discardableResult
    static func set(_ dict: [String: String]?, for key: String) -> Bool {
        set(dict.flatMap { try? JSONEncoder().encode($0) }, for: key)
    }
}
