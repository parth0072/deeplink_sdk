import Foundation
import Security

/// Reads and writes a persistent device ID to the iOS Keychain.
///
/// Unlike UserDefaults, Keychain data survives app uninstalls and reinstalls,
/// enabling deterministic deferred deep link matching on returning users.
internal enum KeychainHelper {

    private static let service = "com.deeplink.sdk"
    private static let deviceIdKey = "device_id"

    /// Returns the stored device ID, or generates and stores a new UUID if none exists.
    static func getOrCreateDeviceId() -> String {
        if let existing = read(key: deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        save(key: deviceIdKey, value: newId)
        DeeplinkLogger.log("Generated new keychain device_id: \(newId)")
        return newId
    }

    // MARK: - Private

    static func read(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let deleteQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    key,
            kSecValueData:      data,
            // Accessible after first unlock — available in background, survives reinstall
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
