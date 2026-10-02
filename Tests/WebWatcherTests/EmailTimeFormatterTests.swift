import XCTest
@testable import WebWatcher

/// Coverage for §3.1's `EmailTimeFormatter.received`. `now`, `calendar` and `locale` are
/// all pinned so the result never depends on the machine running the test.
final class EmailTimeFormatterTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private let locale = Locale(identifier: "en_US_POSIX")

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = hour; comps.minute = minute
        return calendar.date(from: comps)!
    }

    func testSameDayIsToday() {
        let now = date(2026, 9, 26, 18, 0)
        let message = date(2026, 9, 26, 14, 14)
        XCTAssertEqual(EmailTimeFormatter.received(message, now: now, calendar: calendar, locale: locale), "Today 2:14 PM")
    }

    func testOneCalendarDayBackIsYesterday() {
        let now = date(2026, 9, 26, 9, 0)
        let message = date(2026, 9, 25, 14, 14)
        XCTAssertEqual(EmailTimeFormatter.received(message, now: now, calendar: calendar, locale: locale), "Yesterday 2:14 PM")
    }

    func testEarlierThisYearShowsMonthAndDay() {
        let now = date(2026, 9, 26, 9, 0)
        let message = date(2026, 9, 24, 14, 14)
        XCTAssertEqual(EmailTimeFormatter.received(message, now: now, calendar: calendar, locale: locale), "Sep 24, 2:14 PM")
    }

    func testPriorYearShowsMonthDayAndYear() {
        let now = date(2026, 9, 26, 9, 0)
        let message = date(2025, 9, 24, 14, 14)
        XCTAssertEqual(EmailTimeFormatter.received(message, now: now, calendar: calendar, locale: locale), "Sep 24, 2025, 2:14 PM")
    }

    func testMidnightCrossingStillCountsAsYesterdayNotToday() {
        let now = date(2026, 9, 26, 0, 30)
        let message = date(2026, 9, 25, 23, 45)
        XCTAssertEqual(EmailTimeFormatter.received(message, now: now, calendar: calendar, locale: locale), "Yesterday 11:45 PM")
    }
}
