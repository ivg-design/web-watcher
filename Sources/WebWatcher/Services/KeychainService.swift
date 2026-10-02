import Foundation
import Security

/// Stores and retrieves OAuth tokens from the macOS Keychain
final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.webwatcher.app.gmail"

    private init() {}

    /// Token data stored in Keychain as JSON
    struct TokenData: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
    }

    /// Save tokens for an account. A thin caller of `saveData` (§3.4) so every existing
    /// call site is untouched by that refactor.
    func saveTokens(accountId: UUID, accessToken: String, refreshToken: String, expiresAt: Date) {
        let tokenData = TokenData(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
        guard let data = try? JSONEncoder().encode(tokenData) else {
            print("KeychainService: Failed to encode token data")
            return
        }
        saveData(service: service, account: accountId.uuidString, data: data)
    }

    /// Load tokens for an account
    func loadTokens(accountId: UUID) -> TokenData? {
        guard let data = loadData(service: service, account: accountId.uuidString) else { return nil }
        return try? JSONDecoder().decode(TokenData.self, from: data)
    }

    /// Delete tokens for an account
    func deleteTokens(accountId: UUID) {
        deleteData(service: service, account: accountId.uuidString)
    }

    // MARK: - Generic Keychain data (§3.4)
    //
    // `saveTokens`/`loadTokens`/`deleteTokens` above are now thin callers of these, so any
    // other credential (e.g. the imported Google OAuth client, §3.3) can reuse the same
    // Keychain plumbing under its own service/account pair without duplicating SecItem calls.

    /// Saves `data` under `service`/`account`, replacing any existing entry. Returns whether
    /// the add succeeded, so callers that care (`GoogleOAuthClientStore`, tests) can check.
    @discardableResult
    func saveData(service: String, account: String, data: Data) -> Bool {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("KeychainService: Failed to save data (status: \(status))")
        }
        return status == errSecSuccess
    }

    /// Loads the data stored under `service`/`account`, or nil when there is none.
    func loadData(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    /// Deletes the entry under `service`/`account`, if any.
    func deleteData(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("KeychainService: Failed to delete data (status: \(status))")
        }
    }
}
