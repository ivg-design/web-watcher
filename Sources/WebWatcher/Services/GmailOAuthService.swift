import Foundation
import CryptoKit
import AppKit

/// Handles Google OAuth2 authorization with PKCE for Gmail access. Credentials are never
/// hardcoded here (F1) — they come from the client the user imports once in Settings
/// (`GoogleOAuthClientStore`), so this service is inert until that's configured.
final class GmailOAuthService {
    static let shared = GmailOAuthService()

    private let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenURL = "https://oauth2.googleapis.com/token"
    /// gmail.modify only (F6: it's a superset of gmail.readonly, so requesting both only
    /// widens the consent screen for no benefit).
    private let scopes = "https://www.googleapis.com/auth/gmail.modify"

    private let clientStore: GoogleOAuthClientStore
    private var listener: OAuthLoopbackListener?

    init(clientStore: GoogleOAuthClientStore = .shared) {
        self.clientStore = clientStore
    }

    enum OAuthError: Error, LocalizedError {
        case clientNotConfigured
        case serverStartFailed
        case authorizationFailed(String)
        /// Callback `error=access_denied` — the user declined consent.
        case cancelled
        /// Callback `error=admin_policy_enforced` or `error=org_internal` — a Workspace
        /// admin has blocked this OAuth client for the signed-in account.
        case blockedByPolicy(String)
        case tokenExchangeFailed(String)
        /// Token exchange failed with `invalid_client`.
        case invalidClient
        /// `invalid_grant` on the INITIAL code exchange — the code expired or was reused.
        case codeExpired
        /// `invalid_grant` while refreshing — Google revoked access (commonly the 7-day
        /// Testing-mode expiry).
        case refreshRevoked
        /// Google's token response had no `refresh_token` at all (F6: a prior bug treated
        /// this as an empty-but-"authenticated" string; every refresh then failed forever).
        case noRefreshToken
        /// The loopback callback never arrived within the timeout — the consent screen
        /// silently rejected the sign-in ("access blocked" / not a test user) instead of
        /// redirecting back.
        case noResponse
        case userInfoFailed(String)

        var errorDescription: String? {
            switch self {
            case .clientNotConfigured:
                return "Add your Google OAuth client in Settings → Gmail first."
            case .serverStartFailed:
                return "Failed to start OAuth redirect server"
            case .authorizationFailed(let msg):
                return "Authorization failed: \(msg)"
            case .cancelled:
                return "You cancelled the Google sign-in."
            case .blockedByPolicy:
                return "Your Google Workspace admin has blocked WebWatcher for this account. Ask your admin to allow it in the Admin console, or connect a personal Google account instead."
            case .tokenExchangeFailed(let msg):
                return "Token exchange failed: \(msg)"
            case .invalidClient:
                return "Google rejected the OAuth client. Re-import the client JSON."
            case .codeExpired:
                return "That sign-in expired or was already used — try connecting again."
            case .refreshRevoked:
                return "Google revoked access (this happens after 7 days for apps in Testing). Reconnect the account."
            case .noRefreshToken:
                return "Google did not send a refresh token. Remove WebWatcher under Google Account → Security → Third-party access, then connect again."
            case .noResponse:
                return "Google didn't return to WebWatcher. If you're using a personal Google account, add it under OAuth consent screen → Test users for this client, then try again."
            case .userInfoFailed(let detail):
                return "Signed in, but Gmail did not return the account profile: \(detail)"
            }
        }
    }

    struct AuthResult {
        let email: String
        let displayName: String
        let accessToken: String
        /// Never empty — see `OAuthError.noRefreshToken` (F6).
        let refreshToken: String
        let expiresAt: Date
    }

    /// Perform the full OAuth2 authorization flow: opens the browser for consent, waits
    /// for the loopback redirect (bounded by `timeout`), exchanges the code for tokens.
    func authorize(timeout: TimeInterval = 120) async throws -> AuthResult {
        guard let client = clientStore.load(), client.isValid else {
            throw OAuthError.clientNotConfigured
        }

        // Generate PKCE parameters
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = UUID().uuidString

        // Start loopback server
        let listener = OAuthLoopbackListener()
        self.listener = listener

        let port: UInt16
        do {
            port = try listener.start()
        } catch {
            throw OAuthError.serverStartFailed
        }

        let redirectURI = "http://127.0.0.1:\(port)/callback"

        guard let authorizationURL = authorizationURL(client: client, redirectURI: redirectURI, state: state, codeChallenge: codeChallenge) else {
            listener.stop()
            throw OAuthError.authorizationFailed("Invalid authorization URL")
        }

        // Open browser for consent
        await MainActor.run {
            NSWorkspace.shared.open(authorizationURL)
        }

        // Wait for the callback, bounded by `timeout` so a consent screen that never
        // redirects back doesn't hang forever.
        let code = try await waitForCallback(listener: listener, expectedState: state, timeout: timeout)

        // Exchange code for tokens
        let tokenResponse = try await exchangeCodeForTokens(
            client: client,
            code: code,
            codeVerifier: codeVerifier,
            redirectURI: redirectURI
        )

        guard let refreshToken = tokenResponse.refresh_token, !refreshToken.isEmpty else {
            throw OAuthError.noRefreshToken
        }

        // Fetch user profile
        let userInfo = try await fetchUserInfo(accessToken: tokenResponse.access_token)

        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))

        return AuthResult(
            email: userInfo.email,
            displayName: userInfo.name ?? userInfo.email,
            accessToken: tokenResponse.access_token,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }

    /// Refresh an expired access token using the refresh token. Reads the client from the
    /// store on every call (not cached at init) so an updated/re-imported client takes
    /// effect immediately.
    func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, expiresAt: Date) {
        guard let client = clientStore.load(), client.isValid else {
            throw OAuthError.clientNotConfigured
        }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: client.clientId),
            URLQueryItem(name: "client_secret", value: client.clientSecret),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw mapTokenExchangeError(data: data, isRefresh: true)
        }

        let tokenResponse = try JSONDecoder().decode(GmailTokenResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))

        return (tokenResponse.access_token, expiresAt)
    }

    /// Cancel any in-progress authorization
    func cancel() {
        listener?.stop()
        listener = nil
    }

    /// Builds Google's authorization-endpoint URL for the consent step. Pulled out of
    /// `authorize()` so it can be exercised directly by tests without driving a browser or
    /// a loopback server (integrator verification protocol §4.3).
    func authorizationURL(client: GoogleOAuthClient, redirectURI: String, state: String, codeChallenge: String) -> URL? {
        var components = URLComponents(string: authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: client.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url
    }

    // MARK: - Private

    /// Races the blocking loopback callback against `timeout`. Whichever finishes first
    /// wins; on timeout the listener is stopped (closing its socket unblocks the other
    /// side's blocked `accept()` — verified: closing a fd another thread is blocked on in
    /// `accept()` makes it return immediately on Darwin) so that thread doesn't leak past
    /// this function returning.
    private func waitForCallback(listener: OAuthLoopbackListener, expectedState: String, timeout: TimeInterval) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let authCode = try listener.waitForCallback(expectedState: expectedState)
                            continuation.resume(returning: authCode)
                        } catch {
                            continuation.resume(throwing: Self.mapListenerError(error))
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(timeout, 0) * 1_000_000_000))
                listener.stop()
                throw OAuthError.noResponse
            }

            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw OAuthError.noResponse
            }
            return first
        }
    }

    private static func mapListenerError(_ error: Error) -> Error {
        guard let listenerError = error as? OAuthLoopbackListener.ListenerError else {
            return OAuthError.authorizationFailed(error.localizedDescription)
        }
        switch listenerError {
        case .callbackError(let code, let description):
            switch code {
            case "access_denied":
                return OAuthError.cancelled
            case "admin_policy_enforced", "org_internal":
                return OAuthError.blockedByPolicy(code)
            default:
                return OAuthError.authorizationFailed(description ?? code)
            }
        default:
            return OAuthError.authorizationFailed(listenerError.localizedDescription)
        }
    }

    private func exchangeCodeForTokens(client: GoogleOAuthClient, code: String, codeVerifier: String, redirectURI: String) async throws -> GmailTokenResponse {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: client.clientId),
            URLQueryItem(name: "client_secret", value: client.clientSecret),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw mapTokenExchangeError(data: data, isRefresh: false)
        }

        return try JSONDecoder().decode(GmailTokenResponse.self, from: data)
    }

    private struct GoogleTokenErrorResponse: Decodable {
        let error: String
        let error_description: String?
    }

    /// Maps a Google token-endpoint error body to a specific `OAuthError`. `isRefresh`
    /// disambiguates `invalid_grant`, which means something different depending on which
    /// call produced it (§3.7): an expired/reused code on the initial exchange, or a
    /// revoked grant on refresh.
    private func mapTokenExchangeError(data: Data, isRefresh: Bool) -> OAuthError {
        let body = String(data: data, encoding: .utf8) ?? "Unknown error"
        guard let errorResponse = try? JSONDecoder().decode(GoogleTokenErrorResponse.self, from: data) else {
            return .tokenExchangeFailed(body)
        }
        switch errorResponse.error {
        case "invalid_client":
            return .invalidClient
        case "invalid_grant":
            return isRefresh ? .refreshRevoked : .codeExpired
        default:
            return .tokenExchangeFailed(errorResponse.error_description ?? errorResponse.error)
        }
    }

    /// Resolves the signed-in address from Gmail's own profile endpoint.
    ///
    /// The generic `oauth2/v2/userinfo` endpoint needs the `userinfo.email`/`openid`
    /// scopes, which this app never requests (it asks for `gmail.modify` only) — so it
    /// answered 401 and every sign-in ended in "Failed to fetch user profile" (1.7.0/1.8.0).
    /// `users/me/profile` is covered by the Gmail scope and returns the same address.
    private func fetchUserInfo(accessToken: String) async throws -> GoogleUserInfoResponse {
        do {
            let profile = try await GmailAPIService.shared.fetchProfile(accessToken: accessToken)
            return GoogleUserInfoResponse(email: profile.emailAddress, name: nil, picture: nil)
        } catch let apiError as APIError {
            throw OAuthError.userInfoFailed(apiError.localizedDescription)
        } catch {
            throw OAuthError.userInfoFailed(error.localizedDescription)
        }
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded()
    }
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
