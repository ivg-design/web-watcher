import XCTest
@testable import WebWatcher

/// Coverage for §3.3's `GoogleOAuthClient`, `GoogleOAuthClientParser` and
/// `GoogleOAuthClientStore`. The store is always constructed with `keychain: nil` so no
/// test touches the real Keychain. Client secrets here are fabricated, never read from
/// the user's actual Downloads file (F2).
final class GoogleOAuthClientTests: XCTestCase {

    // MARK: - GoogleOAuthClient

    func testIsValidRequiresGoogleSuffixAndNonEmptySecret() {
        let valid = GoogleOAuthClient(clientId: "123-abc.apps.googleusercontent.com", clientSecret: "s3cr3t")
        XCTAssertTrue(valid.isValid)

        let noSecret = GoogleOAuthClient(clientId: "123-abc.apps.googleusercontent.com", clientSecret: "")
        XCTAssertFalse(noSecret.isValid)

        let wrongSuffix = GoogleOAuthClient(clientId: "123-abc.example.com", clientSecret: "s3cr3t")
        XCTAssertFalse(wrongSuffix.isValid)
    }

    func testShortIdIsFirstTwelveCharactersPlusEllipsis() {
        let client = GoogleOAuthClient(
            clientId: "123456789012-abcdefghijklmnopqrstuvwxyz012345.apps.googleusercontent.com",
            clientSecret: "s"
        )
        XCTAssertEqual(client.shortId, "123456789012…")
    }

    // MARK: - GoogleOAuthClientParser

    /// Equivalent shape to the F2 file (fabricated secret — never read the real Downloads file).
    func testParsesInstalledClientJSONMatchingF2Shape() throws {
        let json = """
        {"installed":{"client_id":"123456789012-abcdefghijklmnopqrstuvwxyz012345.apps.googleusercontent.com",
         "project_id":"opportune-mile-469511-f7","auth_uri":"https://accounts.google.com/o/oauth2/auth",
         "token_uri":"https://oauth2.googleapis.com/token",
         "auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs",
         "client_secret":"GOCSPX-fake-secret-value","redirect_uris":["http://localhost"]}}
        """
        let client = try GoogleOAuthClientParser.parse(Data(json.utf8))

        XCTAssertEqual(client.clientId, "123456789012-abcdefghijklmnopqrstuvwxyz012345.apps.googleusercontent.com")
        XCTAssertEqual(client.clientSecret, "GOCSPX-fake-secret-value")
        XCTAssertEqual(client.projectId, "opportune-mile-469511-f7")
        XCTAssertTrue(client.isValid)
    }

    func testWebClientJSONIsRejectedWithUnsupportedType() {
        let json = """
        {"web":{"client_id":"123.apps.googleusercontent.com","client_secret":"s",
         "auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token"}}
        """
        XCTAssertThrowsError(try GoogleOAuthClientParser.parse(Data(json.utf8))) { error in
            guard case GoogleOAuthClientParser.ParseError.unsupportedType(let type) = error else {
                return XCTFail("Expected unsupportedType, got \(error)")
            }
            XCTAssertEqual(type, "web")
            XCTAssertEqual(
                (error as? GoogleOAuthClientParser.ParseError)?.errorDescription,
                "This is a Web application client. Create a Desktop app client instead."
            )
        }
    }

    func testGarbageDataIsNotJSON() {
        let garbage = Data("this is not json {{{".utf8)
        XCTAssertThrowsError(try GoogleOAuthClientParser.parse(garbage)) { error in
            guard case GoogleOAuthClientParser.ParseError.notJSON = error else {
                return XCTFail("Expected notJSON, got \(error)")
            }
        }
    }

    func testMissingClientSecretIsMissingFields() {
        let json = """
        {"installed":{"client_id":"123.apps.googleusercontent.com","project_id":"p"}}
        """
        XCTAssertThrowsError(try GoogleOAuthClientParser.parse(Data(json.utf8))) { error in
            guard case GoogleOAuthClientParser.ParseError.missingFields = error else {
                return XCTFail("Expected missingFields, got \(error)")
            }
        }
    }

    func testUnknownRootKeyIsUnsupportedType() {
        let json = """
        {"service_account":{"client_id":"123.apps.googleusercontent.com","client_secret":"s"}}
        """
        XCTAssertThrowsError(try GoogleOAuthClientParser.parse(Data(json.utf8))) { error in
            guard case GoogleOAuthClientParser.ParseError.unsupportedType(let type) = error else {
                return XCTFail("Expected unsupportedType, got \(error)")
            }
            XCTAssertEqual(type, "service_account")
        }
    }

    // MARK: - GoogleOAuthClientStore (in-memory only — never touches the real Keychain)

    func testStoreRoundTripsInMemoryWithoutKeychain() {
        let store = GoogleOAuthClientStore(keychain: nil)
        XCTAssertNil(store.load())
        XCTAssertFalse(store.isConfigured)

        let client = GoogleOAuthClient(clientId: "123.apps.googleusercontent.com", clientSecret: "s")
        store.save(client)
        XCTAssertEqual(store.load(), client)
        XCTAssertTrue(store.isConfigured)

        store.clear()
        XCTAssertNil(store.load())
        XCTAssertFalse(store.isConfigured)
    }
}
