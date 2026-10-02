import XCTest
@testable import WebWatcher

/// Coverage for §9.6's built-in Google OAuth client: `GoogleOAuthClient.builtIn` and
/// `GoogleOAuthClientStore`'s `override ?? builtIn` precedence. Every store here is
/// constructed with `keychain: nil` and an injected `builtIn` — never the real Keychain,
/// never `Bundle.main`'s actual resources. Kept separate from the pre-existing
/// `GoogleOAuthClientTests.swift`, which is left untouched.
final class GoogleOAuthBuiltInTests: XCTestCase {

    private let fakeBuiltIn = GoogleOAuthClient(
        clientId: "111-built.apps.googleusercontent.com",
        clientSecret: "built-in-secret",
        projectId: "built-in-project"
    )

    private let fakeOverride = GoogleOAuthClient(
        clientId: "222-override.apps.googleusercontent.com",
        clientSecret: "override-secret"
    )

    // MARK: - GoogleOAuthClient.builtIn

    /// No `google-oauth-client.json` resource ships in the test bundle (a fresh clone /
    /// SwiftPM test target never has one) — the equivalent of the old design's "placeholder
    /// client" case: nothing configured resolves to nil, never a crash.
    func testBuiltInIsNilWhenNoResourceIsBundled() {
        XCTAssertNil(GoogleOAuthClient.builtIn)
    }

    // MARK: - GoogleOAuthClientStore precedence: override > builtIn

    func testLoadReturnsBuiltInWhenNoOverrideIsSaved() {
        let store = GoogleOAuthClientStore(keychain: nil, builtIn: fakeBuiltIn)
        XCTAssertEqual(store.load(), fakeBuiltIn)
        XCTAssertFalse(store.isUsingOverride)
    }

    func testLoadCalledTwiceReturnsTheSameBuiltInEachTime() {
        let store = GoogleOAuthClientStore(keychain: nil, builtIn: fakeBuiltIn)
        let first = store.load()
        let second = store.load()
        XCTAssertEqual(first, fakeBuiltIn)
        XCTAssertEqual(first, second)
    }

    func testSaveOverridesTheBuiltInClient() {
        let store = GoogleOAuthClientStore(keychain: nil, builtIn: fakeBuiltIn)
        XCTAssertEqual(store.load(), fakeBuiltIn) // resolve once against builtIn first

        store.save(fakeOverride)
        XCTAssertEqual(store.load(), fakeOverride)
        XCTAssertTrue(store.isUsingOverride)
    }

    /// §9.6: `clear()` re-resolves to `builtIn` — no stale override survives it.
    func testClearRemovesOverrideAndReResolvesToBuiltIn() {
        let store = GoogleOAuthClientStore(keychain: nil, builtIn: fakeBuiltIn)
        store.save(fakeOverride)
        XCTAssertEqual(store.load(), fakeOverride)

        store.clear()
        XCTAssertEqual(store.load(), fakeBuiltIn)
        XCTAssertFalse(store.isUsingOverride)
    }

    func testWithNoBuiltInAndNoOverrideLoadReturnsNil() {
        let store = GoogleOAuthClientStore(keychain: nil, builtIn: nil)
        XCTAssertNil(store.load())
        XCTAssertFalse(store.isConfigured)
        XCTAssertFalse(store.isUsingOverride)
    }

    func testWithNoBuiltInSaveStillWorksAsAnOverride() {
        let store = GoogleOAuthClientStore(keychain: nil, builtIn: nil)
        store.save(fakeOverride)
        XCTAssertEqual(store.load(), fakeOverride)
        XCTAssertTrue(store.isUsingOverride)

        store.clear()
        XCTAssertNil(store.load())
    }

    // MARK: - builtInAvailable / isConfigured

    func testBuiltInAvailableReflectsWhetherABuiltInWasInjected() {
        XCTAssertTrue(GoogleOAuthClientStore(keychain: nil, builtIn: fakeBuiltIn).builtInAvailable)
        XCTAssertFalse(GoogleOAuthClientStore(keychain: nil, builtIn: nil).builtInAvailable)
    }

    func testIsConfiguredTrueWhenBuiltInAloneIsValid() {
        let store = GoogleOAuthClientStore(keychain: nil, builtIn: fakeBuiltIn)
        XCTAssertTrue(fakeBuiltIn.isValid)
        XCTAssertTrue(store.isConfigured)
    }

    func testIsConfiguredFalseWhenBuiltInIsInvalid() {
        let invalid = GoogleOAuthClient(clientId: "not-a-google-id", clientSecret: "")
        let store = GoogleOAuthClientStore(keychain: nil, builtIn: invalid)
        XCTAssertFalse(store.isConfigured)
    }

    // MARK: - Default init still resolves against the real (bundle-absent) builtIn

    /// The existing `init(keychain:)` call sites across the app must keep working —
    /// `builtIn` defaults to `GoogleOAuthClient.builtIn`, which is nil in this test bundle.
    func testDefaultInitStillWorksWithKeychainNilOnly() {
        let store = GoogleOAuthClientStore(keychain: nil)
        XCTAssertNil(store.load())
        XCTAssertFalse(store.isConfigured)
    }
}
