import XCTest
@testable import WebWatcher

/// Coverage for G2's "Anything Changes Inside" watch type (§3.1): the `shouldNotifyValue`
/// rule, `WatcherStore.recordObservation`'s `lastChangeDate` bookkeeping, `statusDisplay`,
/// and Codable back-compat for the new field. `WatcherStore` here always points at a temp
/// directory — never the user's real Application Support folder, and never the Keychain
/// or network.
@MainActor
final class SubtreeWatchTypeTests: XCTestCase {

    // MARK: - shouldNotifyValue (§3.1: old != nil && old != new)

    func testShouldNotifyValueFirstReadingIsBaselineNotAlert() {
        XCTAssertFalse(WatcherService.shouldNotifyValue(watchType: .subtreeChange, old: nil, new: "3:a1b2c3"))
    }

    func testShouldNotifyValueNotifiesOnAnyDifference() {
        XCTAssertTrue(WatcherService.shouldNotifyValue(watchType: .subtreeChange, old: "3:a1b2c3", new: "4:d4e5f6"))
        // Even a "decrease" is news — a subtree fingerprint has no up/down direction,
        // unlike badgeNumber/elementCount.
        XCTAssertTrue(WatcherService.shouldNotifyValue(watchType: .subtreeChange, old: "4:d4e5f6", new: "3:a1b2c3"))
    }

    func testShouldNotifyValueDoesNotNotifyWhenUnchanged() {
        XCTAssertFalse(WatcherService.shouldNotifyValue(watchType: .subtreeChange, old: "3:a1b2c3", new: "3:a1b2c3"))
    }

    // MARK: - WatcherStore.recordObservation → lastChangeDate

    private func tempStore() -> WatcherStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubtreeWatchTypeTests-\(UUID().uuidString)", isDirectory: true)
        return WatcherStore(appFolder: dir)
    }

    func testRecordObservationSetsLastChangeDateOnlyWhenValueDiffers() {
        let store = tempStore()
        let w = Watcher(name: "n", url: "u", selector: "s", watchType: .subtreeChange)
        store.watchers = [w]

        // First conclusive reading: a baseline, not a change.
        store.recordObservation(for: w.id, value: "3:aaa")
        XCTAssertNil(store.watchers[0].lastChangeDate)

        // Same value again: still no change.
        store.recordObservation(for: w.id, value: "3:aaa")
        XCTAssertNil(store.watchers[0].lastChangeDate)

        // A different value: this is a real change.
        store.recordObservation(for: w.id, value: "4:bbb")
        XCTAssertNotNil(store.watchers[0].lastChangeDate)
    }

    func testRecordObservationDoesNotAdvanceLastChangeDateOnRepeatedSameValue() {
        let store = tempStore()
        let w = Watcher(name: "n", url: "u", selector: "s", watchType: .subtreeChange)
        store.watchers = [w]

        store.recordObservation(for: w.id, value: "1:x")
        store.recordObservation(for: w.id, value: "2:y")
        let firstChange = store.watchers[0].lastChangeDate
        XCTAssertNotNil(firstChange)

        store.recordObservation(for: w.id, value: "2:y")
        XCTAssertEqual(store.watchers[0].lastChangeDate, firstChange)
    }

    func testRecordObservationReturnsPreviousConclusiveValue() {
        let store = tempStore()
        let w = Watcher(name: "n", url: "u", selector: "s", watchType: .subtreeChange)
        store.watchers = [w]

        XCTAssertNil(store.recordObservation(for: w.id, value: "1:x"))
        XCTAssertEqual(store.recordObservation(for: w.id, value: "2:y"), "1:x")
    }

    // MARK: - statusDisplay (§3.1 formula)

    func testStatusDisplayNotCheckedYetWhenNeverObserved() {
        let w = Watcher(name: "n", url: "u", selector: "s", watchType: .subtreeChange)
        XCTAssertEqual(w.statusDisplay, "Not checked yet")
    }

    func testStatusDisplayWatchingWhenConclusiveButNeverChanged() {
        var w = Watcher(name: "n", url: "u", selector: "s", watchType: .subtreeChange)
        w.lastConclusiveValue = "3:aaa"
        XCTAssertEqual(w.statusDisplay, "Watching")
    }

    func testStatusDisplayShowsChangedWithFormattedTimestamp() {
        var w = Watcher(name: "n", url: "u", selector: "s", watchType: .subtreeChange)
        w.lastConclusiveValue = "4:bbb"
        let now = Date()
        w.lastChangeDate = now
        XCTAssertEqual(w.statusDisplay, "Changed \(EmailTimeFormatter.received(now))")
    }

    // MARK: - Copy (§3.1 exact strings)

    func testDescriptionCopy() {
        XCTAssertEqual(
            WatchType.subtreeChange.description,
            "Notify when anything inside the element changes — a badge appears, text updates, items are added."
        )
    }

    func testRawValueCopy() {
        XCTAssertEqual(WatchType.subtreeChange.rawValue, "Anything Changes Inside")
    }

    // NotificationService's default-body copy for .subtreeChange (§9.1) lives in a
    // private switch with no test hook — out of scope to add one here since this file's
    // ownership is limited to that single case line, not the surrounding type.

    // MARK: - Codable (absent in old JSON)

    func testLegacyJSONWithoutLastChangeDateDecodesToNil() throws {
        let legacy = """
        {"id":"AE28EB85-DDEE-4A79-8B5A-E02318052247","name":"n","url":"u","selector":"s",
         "selectorType":"CSS Selector","watchType":"Anything Changes Inside","interval":60,
         "isEnabled":true,"notificationSound":true}
        """
        let w = try JSONDecoder().decode(Watcher.self, from: Data(legacy.utf8))
        XCTAssertNil(w.lastChangeDate)
        XCTAssertEqual(w.watchType, .subtreeChange)
    }

    func testRoundTripsLastChangeDate() throws {
        var w = Watcher(name: "n", url: "u", selector: "s", watchType: .subtreeChange)
        w.lastChangeDate = Date()

        let data = try JSONEncoder().encode(w)
        let decoded = try JSONDecoder().decode(Watcher.self, from: data)
        XCTAssertNotNil(decoded.lastChangeDate)
    }

    func testRoundTripsWithNilLastChangeDate() throws {
        let w = Watcher(name: "n", url: "u", selector: "s", watchType: .subtreeChange)
        let data = try JSONEncoder().encode(w)
        let decoded = try JSONDecoder().decode(Watcher.self, from: data)
        XCTAssertNil(decoded.lastChangeDate)
    }
}
