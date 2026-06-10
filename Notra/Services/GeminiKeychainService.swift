import Foundation
import Security

final class GeminiKeychainService {

    static let shared = GeminiKeychainService()

    private let keychainService = "com.notra.gemini"
    private let keychainAccount = "geminiAPIKey"

    private init() {}

    func saveAPIKey(_ key: String) throws {
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw KeychainError.emptyKey
        }
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { return nil }
        return key
    }

    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func hasAPIKey() -> Bool {
        return loadAPIKey() != nil
    }

    /// Returns a masked display string like "••••ABCD", never the real key.
    func maskedKey() -> String? {
        guard let key = loadAPIKey() else { return nil }
        guard key.count >= 4 else { return "••••" }
        return "••••" + String(key.suffix(4))
    }

    func testKey(_ key: String, completion: @escaping (Result<Void, GeminiParserError>) -> Void) {
        GeminiReceiptParser.shared.testAPIKey(key, completion: completion)
    }

    enum KeychainError: LocalizedError {
        case emptyKey
        case encodingFailed
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .emptyKey: return "API key cannot be empty."
            case .encodingFailed: return "Failed to encode the API key."
            case .saveFailed(let s): return "Keychain save failed (status: \(s))."
            case .deleteFailed(let s): return "Keychain delete failed (status: \(s))."
            }
        }
    }
}
