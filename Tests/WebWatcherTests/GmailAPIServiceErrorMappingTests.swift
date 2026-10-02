import XCTest
@testable import WebWatcher

/// Coverage for `GmailAPIService.handleHTTPResponse`'s 404 mapping: Google's real Gmail API
/// 404 body is the fixed, generic message "Requested entity was not found." — it never
/// contains "historyId" or "notFound" — so the History API's 404 must be classified as
/// `.historyExpired` by endpoint, not by matching text no real response contains. Constructs
/// a bare `HTTPURLResponse` + body; no network call, no Keychain.
final class GmailAPIServiceErrorMappingTests: XCTestCase {

    private let googleGeneric404Body = Data(
        #"{"error":{"code":404,"message":"Requested entity was not found.","status":"NOT_FOUND"}}"#.utf8
    )

    func testHistory404WithGooglesRealGenericBodyMapsToHistoryExpired() {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/history?startHistoryId=1")!
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!

        XCTAssertThrowsError(try GmailAPIService.shared.handleHTTPResponse(response, data: googleGeneric404Body)) { error in
            guard case APIError.historyExpired = error else {
                return XCTFail("expected .historyExpired, got \(error)")
            }
        }
    }

    func testHistory404WithPageTokenQueryStillMapsToHistoryExpired() {
        // The pagination fix appends a `pageToken` query item to the same /history path —
        // confirm the path-based check isn't thrown off by extra query items.
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/history?startHistoryId=1&pageToken=abc")!
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!

        XCTAssertThrowsError(try GmailAPIService.shared.handleHTTPResponse(response, data: googleGeneric404Body)) { error in
            guard case APIError.historyExpired = error else {
                return XCTFail("expected .historyExpired, got \(error)")
            }
        }
    }

    func testNonHistory404WithTheSameGenericBodyStaysRequestFailed() {
        // A message that's genuinely gone (deleted, wrong id) must NOT be misclassified as
        // an expired history cursor just because it shares Google's generic 404 text.
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/abc123")!
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!

        XCTAssertThrowsError(try GmailAPIService.shared.handleHTTPResponse(response, data: googleGeneric404Body)) { error in
            guard case APIError.requestFailed(let code, _) = error else {
                return XCTFail("expected .requestFailed, got \(error)")
            }
            XCTAssertEqual(code, 404)
        }
    }

    func testHistory404WithLegacyReasonTextStillMapsToHistoryExpired() {
        // The old substring check (kept as a fallback) must still work for any error body
        // that does spell "notFound" out, even off the /history endpoint.
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/abc123")!
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        let body = Data(#"{"error":{"code":404,"message":"notFound: startHistoryId too old"}}"#.utf8)

        XCTAssertThrowsError(try GmailAPIService.shared.handleHTTPResponse(response, data: body)) { error in
            guard case APIError.historyExpired = error else {
                return XCTFail("expected .historyExpired, got \(error)")
            }
        }
    }
}
