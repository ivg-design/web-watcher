import Foundation
import Combine

/// Manages the collection of Gmail accounts and persists them.
@MainActor
class GmailAccountStore: ObservableObject {
    static let shared = ScreenshotMode.isActive
        ? GmailAccountStore(fileURL: ScreenshotMode.scratchFile("gmail_accounts.json"), keychain: nil)
        : GmailAccountStore()

    @Published var accounts: [GmailAccount] = []

    private let fileURL: URL
    /// nil in tests: tokens are neither loaded nor saved, so a test run never touches the
    /// real Keychain. The shared instance always gets `KeychainService.shared` (the default),
    /// so its behaviour is unchanged from before this became injectable.
    private let keychain: KeychainService?

    init(fileURL: URL? = nil, keychain: KeychainService? = KeychainService.shared) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("WebWatcher", isDirectory: true)
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            self.fileURL = appFolder.appendingPathComponent("gmail_accounts.json")
        }
        self.keychain = keychain
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            accounts = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            accounts = try JSONDecoder().decode([GmailAccount].self, from: data)
            // Restore tokens from Keychain
            for i in accounts.indices {
                if let tokenData = keychain?.loadTokens(accountId: accounts[i].id) {
                    accounts[i].accessToken = tokenData.accessToken
                    accounts[i].refreshToken = tokenData.refreshToken
                    accounts[i].tokenExpiresAt = tokenData.expiresAt
                }
            }
        } catch {
            print("Failed to load Gmail accounts: \(error)")
            accounts = []
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(accounts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save Gmail accounts: \(error)")
        }
    }

    func add(_ account: GmailAccount) {
        accounts.append(account)
        // Save tokens to Keychain
        if let accessToken = account.accessToken, let refreshToken = account.refreshToken {
            keychain?.saveTokens(
                accountId: account.id,
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: account.tokenExpiresAt ?? Date()
            )
        }
        save()
    }

    func update(_ account: GmailAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            // Update tokens in Keychain if present
            if let accessToken = account.accessToken, let refreshToken = account.refreshToken {
                keychain?.saveTokens(
                    accountId: account.id,
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiresAt: account.tokenExpiresAt ?? Date()
                )
            }
            save()
        }
    }

    func delete(_ account: GmailAccount) {
        accounts.removeAll { $0.id == account.id }
        keychain?.deleteTokens(accountId: account.id)
        save()
    }

    func updateResult(for accountId: UUID, historyId: String?, unreadCount: Int?, error: String?) {
        if let index = accounts.firstIndex(where: { $0.id == accountId }) {
            if let historyId = historyId {
                accounts[index].lastHistoryId = historyId
            }
            if let unreadCount = unreadCount {
                accounts[index].unreadCount = unreadCount
            }
            accounts[index].lastCheck = Date()
            accounts[index].lastError = error
            if error != nil {
                accounts[index].consecutiveErrors += 1
            } else {
                accounts[index].consecutiveErrors = 0
            }
            save()
        }
    }

    func updateTokens(for accountId: UUID, accessToken: String, expiresAt: Date) {
        if let index = accounts.firstIndex(where: { $0.id == accountId }) {
            accounts[index].accessToken = accessToken
            accounts[index].tokenExpiresAt = expiresAt
            if let refreshToken = accounts[index].refreshToken {
                keychain?.saveTokens(
                    accountId: accountId,
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiresAt: expiresAt
                )
            }
        }
    }

    /// Get the next available account index
    var nextAccountIndex: Int {
        (accounts.map(\.accountIndex).max() ?? -1) + 1
    }
}
