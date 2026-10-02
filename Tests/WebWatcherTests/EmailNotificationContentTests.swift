import XCTest
@testable import WebWatcher

/// Coverage for §3.10's `NotificationService.emailWatcherContent` — the pure builder
/// behind `notifyEmailWatcher`. Tests call the static function directly, so none of this
/// touches `UNUserNotificationCenter`.
final class EmailNotificationContentTests: XCTestCase {

    private func makeMessage(from: String = "Jane Doe <jane@acme.com>", subject: String = "Invoice #42", snippet: String = "", date: Date = Date()) -> GmailMessage {
        GmailMessage(accountId: UUID(), messageId: "m1", threadId: "t1", from: from, subject: subject, date: date, labelIds: [], snippet: snippet)
    }

    private func makeAccount(email: String = "me@example.com") -> GmailAccount {
        GmailAccount(email: email)
    }

    // MARK: - Title

    func testTitleDefaultsToEmailFromSenderName() {
        let watcher = EmailWatcher(accountId: UUID(), senders: ["jane@acme.com"]) // name left empty
        let content = NotificationService.emailWatcherContent(watcher: watcher, message: makeMessage(), account: makeAccount())
        XCTAssertEqual(content.title, "Email from Jane Doe")
    }

    func testTitleFallsBackToAddressWhenFromHeaderHasNoName() {
        let watcher = EmailWatcher(accountId: UUID(), senders: ["jane@acme.com"])
        let content = NotificationService.emailWatcherContent(watcher: watcher, message: makeMessage(from: "jane@acme.com"), account: makeAccount())
        XCTAssertEqual(content.title, "Email from jane@acme.com")
    }

    func testTitleUsesCustomWatcherNameWhenSet() {
        let watcher = EmailWatcher(name: "Acme Invoices", accountId: UUID(), senders: ["jane@acme.com"])
        let content = NotificationService.emailWatcherContent(watcher: watcher, message: makeMessage(), account: makeAccount())
        XCTAssertEqual(content.title, "Acme Invoices")
    }

    // MARK: - Subtitle

    func testSubtitleIsTheMessageSubject() {
        let watcher = EmailWatcher(accountId: UUID(), senders: ["jane@acme.com"])
        let content = NotificationService.emailWatcherContent(watcher: watcher, message: makeMessage(subject: "Q3 renewal"), account: makeAccount())
        XCTAssertEqual(content.subtitle, "Q3 renewal")
    }

    // MARK: - Body: "received <time>"

    func testBodyContainsReceivedAndTheFormattedTime() {
        let watcher = EmailWatcher(accountId: UUID(), senders: ["jane@acme.com"])
        let now = Date()
        let content = NotificationService.emailWatcherContent(watcher: watcher, message: makeMessage(date: now), account: makeAccount(), now: now)
        XCTAssertTrue(content.body.contains("received"))
        XCTAssertTrue(content.body.contains(EmailTimeFormatter.received(now, now: now)))
    }

    // MARK: - Snippet truncation

    func testSnippetIsTruncatedToOneHundredTwentyCharacters() {
        let watcher = EmailWatcher(accountId: UUID(), senders: ["jane@acme.com"])
        let longSnippet = String(repeating: "x", count: 200)
        let content = NotificationService.emailWatcherContent(watcher: watcher, message: makeMessage(snippet: longSnippet), account: makeAccount())

        XCTAssertTrue(content.body.contains(String(repeating: "x", count: 120)))
        XCTAssertFalse(content.body.contains(String(repeating: "x", count: 121)))
    }

    func testEmptySnippetAddsNoSecondLine() {
        let watcher = EmailWatcher(accountId: UUID(), senders: ["jane@acme.com"])
        let content = NotificationService.emailWatcherContent(watcher: watcher, message: makeMessage(snippet: ""), account: makeAccount())
        XCTAssertFalse(content.body.contains("\n"))
    }

    // MARK: - Account suffix (only with more than one connected account)

    func testAccountSuffixOmittedWithASingleAccount() {
        let watcher = EmailWatcher(accountId: UUID(), senders: ["jane@acme.com"])
        let content = NotificationService.emailWatcherContent(
            watcher: watcher, message: makeMessage(), account: makeAccount(email: "me@example.com"), accountCount: 1
        )
        XCTAssertFalse(content.body.contains("me@example.com"))
    }

    func testAccountSuffixAddedWithMoreThanOneAccount() {
        let watcher = EmailWatcher(accountId: UUID(), senders: ["jane@acme.com"])
        let content = NotificationService.emailWatcherContent(
            watcher: watcher, message: makeMessage(), account: makeAccount(email: "me@example.com"), accountCount: 2
        )
        XCTAssertTrue(content.body.contains("— me@example.com"))
    }

    func testAccountSuffixDefaultsToOmittedWhenAccountCountIsNotPassed() {
        let watcher = EmailWatcher(accountId: UUID(), senders: ["jane@acme.com"])
        let content = NotificationService.emailWatcherContent(watcher: watcher, message: makeMessage(), account: makeAccount(email: "me@example.com"))
        XCTAssertFalse(content.body.contains("me@example.com"))
    }
}
