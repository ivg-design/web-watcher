import XCTest
@testable import WebWatcher

/// Coverage for §3.1's `SenderMatcher`: normalize, parse(fromHeader:), matches, split and
/// gmailQuery. Pure logic — no Gmail API, no Keychain, no files.
final class SenderMatcherTests: XCTestCase {

    // MARK: - normalize

    func testNormalizeNameAngleBracketAddressLowercases() {
        XCTAssertEqual(SenderMatcher.normalize("Name <a@B.com>"), "a@b.com")
    }

    func testNormalizeQuotedNameWithCommaAngleBracketAddress() {
        XCTAssertEqual(SenderMatcher.normalize("\"Doe, Jane\" <j@x.com>"), "j@x.com")
    }

    func testNormalizeBareAngleBracketAddress() {
        XCTAssertEqual(SenderMatcher.normalize("<j@x.com>"), "j@x.com")
    }

    func testNormalizeBareAddressLowercases() {
        XCTAssertEqual(SenderMatcher.normalize("A@B.com"), "a@b.com")
    }

    func testNormalizeDomainPatternLowercases() {
        XCTAssertEqual(SenderMatcher.normalize("@Domain.com"), "@domain.com")
    }

    func testNormalizeRejectsStringWithoutAtSign() {
        XCTAssertNil(SenderMatcher.normalize("not-an-address"))
    }

    func testNormalizeRejectsSpacesInsideUnbracketedAddress() {
        XCTAssertNil(SenderMatcher.normalize("a b@c.com"))
    }

    func testNormalizeRejectsEmptyOrWhitespaceOnly() {
        XCTAssertNil(SenderMatcher.normalize("   "))
        XCTAssertNil(SenderMatcher.normalize(""))
    }

    func testNormalizeRejectsMultipleAtSigns() {
        XCTAssertNil(SenderMatcher.normalize("a@b@c.com"))
    }

    func testNormalizeRejectsBareAtSign() {
        XCTAssertNil(SenderMatcher.normalize("@"))
    }

    // MARK: - parse(fromHeader:)

    func testParseQuotedNameWithCommaSplitsCorrectly() {
        let (name, address) = SenderMatcher.parse(fromHeader: "\"Doe, Jane\" <jane@x.com>")
        XCTAssertEqual(name, "Doe, Jane")
        XCTAssertEqual(address, "jane@x.com")
    }

    func testParseBareAddressHasEmptyName() {
        let (name, address) = SenderMatcher.parse(fromHeader: "jane@x.com")
        XCTAssertEqual(name, "")
        XCTAssertEqual(address, "jane@x.com")
    }

    func testParseAngleBracketsOnlyHasEmptyName() {
        let (name, address) = SenderMatcher.parse(fromHeader: "<j@x.com>")
        XCTAssertEqual(name, "")
        XCTAssertEqual(address, "j@x.com")
    }

    func testParseUnquotedName() {
        let (name, address) = SenderMatcher.parse(fromHeader: "Jane Doe <jane@x.com>")
        XCTAssertEqual(name, "Jane Doe")
        XCTAssertEqual(address, "jane@x.com")
    }

    func testParseLeavesRFC2047EncodedNameAsIs() {
        let (name, address) = SenderMatcher.parse(fromHeader: "=?UTF-8?B?SmFuZQ==?= <jane@x.com>")
        XCTAssertEqual(name, "=?UTF-8?B?SmFuZQ==?=")
        XCTAssertEqual(address, "jane@x.com")
    }

    // MARK: - matches

    func testMatchesExactAddressIsCaseInsensitive() {
        XCTAssertTrue(SenderMatcher.matches(address: "Jane@X.com", patterns: ["jane@x.com"]))
    }

    func testMatchesDomainSuffixPattern() {
        XCTAssertTrue(SenderMatcher.matches(address: "anyone@x.com", patterns: ["@x.com"]))
    }

    func testMatchesRejectsPartialDomainOverlap() {
        // "@x.com" must match the WHOLE domain, not just a substring of it.
        XCTAssertFalse(SenderMatcher.matches(address: "a@notx.com", patterns: ["@x.com"]))
    }

    func testMatchesRejectsUnrelatedAddress() {
        XCTAssertFalse(SenderMatcher.matches(address: "a@y.com", patterns: ["jane@x.com", "@x.com"]))
    }

    func testMatchesReturnsFalseForEmptyPatternList() {
        XCTAssertFalse(SenderMatcher.matches(address: "a@x.com", patterns: []))
    }

    // MARK: - split

    func testSplitOnCommasSemicolonsWhitespaceAndNewlinesWithDedupe() {
        let result = SenderMatcher.split("a@x.com, b@y.com;\nc@z.com c@z.com")
        XCTAssertEqual(result, ["a@x.com", "b@y.com", "c@z.com"])
    }

    func testSplitDropsInvalidEntriesButKeepsValidOnes() {
        let result = SenderMatcher.split("a@x.com, not-an-address, @y.com")
        XCTAssertEqual(result, ["a@x.com", "@y.com"])
    }

    func testSplitPreservesFirstOccurrenceOrder() {
        let result = SenderMatcher.split("z@z.com a@a.com m@m.com")
        XCTAssertEqual(result, ["z@z.com", "a@a.com", "m@m.com"])
    }

    func testSplitOfEmptyStringIsEmpty() {
        XCTAssertEqual(SenderMatcher.split(""), [])
    }

    // MARK: - gmailQuery

    func testGmailQueryOrsExactAndDomainSendersWithNewerThan() {
        XCTAssertEqual(
            SenderMatcher.gmailQuery(for: ["a@b.com", "@b.com"]),
            "(from:a@b.com OR from:b.com) newer_than:2y"
        )
    }

    func testGmailQuerySingleExactSender() {
        XCTAssertEqual(
            SenderMatcher.gmailQuery(for: ["a@b.com"]),
            "(from:a@b.com) newer_than:2y"
        )
    }

    func testGmailQueryDomainOnlyDropsTheAtSign() {
        XCTAssertEqual(
            SenderMatcher.gmailQuery(for: ["@b.com"]),
            "(from:b.com) newer_than:2y"
        )
    }
}
