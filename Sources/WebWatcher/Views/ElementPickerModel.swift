import Foundation
import AppKit

/// Drives the editor's "Which element?" assistant (Scan page / Pick in Safari).
///
/// All Safari interaction goes through `ElementProbing` so this type is testable
/// with a fake — no AppleScript, no live Safari, no timing flakiness beyond what
/// the test itself injects via `pickTimeout`/`pollInterval`.
///
/// This type carries two API generations side by side:
///  - the original scan()/beginPick()/choose()/change() surface (still exercised by
///    the pre-existing `ElementPickerModelTests`, left behaviorally unchanged);
///  - the three-step guided assistant added on top for G1 (§3.7/§9.4): `Step`,
///    `TabStatus`, `locate()`, `useCandidate`/`chooseStrategy`/`pendingChoice`,
///    `confirmSelection()`, `back(to:)`. The new surface is built ON the old one —
///    `locate()` calls `scan()`, `useCandidate`/`chooseStrategy` call `choose()` —
///    so a single source of truth (`chosen`, `candidates`, the pick loop) backs both.
@MainActor
final class ElementPickerModel: ObservableObject {

    enum Phase: Equatable {
        case idle, scanning, reloading, opening, picking, applied
    }

    enum Source: Equatable {
        case scan, pick
    }

    /// The three visible steps of the guided assistant (G1/§3.7). Raw `Int` so `<` can be
    /// hand-written instead of relying on case declaration order surviving edits.
    enum Step: Int, Comparable {
        case page = 1, element, confirm

        static func < (l: Step, r: Step) -> Bool { l.rawValue < r.rawValue }
    }

    /// Step 1's own state machine — what `locate()` currently knows about the monitored
    /// page's tab. Kept separate from `Phase`/`statusLine` (which drive the Step 2 scan/pick
    /// UI) because Step 1 needs richer state (a found tab's title/url/visibility) than a
    /// single status string can carry.
    enum TabStatus: Equatable {
        case unknown
        case checking
        case found(title: String, url: String, visible: Bool)
        case notOpen
        case opening
        case reloading
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var candidates: [ElementCandidate] = []
    @Published private(set) var chosen: ElementCandidate?
    @Published private(set) var chosenVia: Source?
    @Published private(set) var statusLine: String?
    @Published private(set) var scannedTitle: String?
    @Published private(set) var scannedURL: String?
    @Published private(set) var tabVisible: Bool?
    /// "Monitored URL set to https://…" — shown with an "Undo" action when a
    /// choice changed the watcher's URL.
    @Published private(set) var urlNotice: String?
    @Published private(set) var showList = false

    // MARK: - Guided assistant (G1/§3.7, amended §9.4)

    @Published private(set) var step: Step = .page
    @Published private(set) var tab: TabStatus = .unknown
    /// The pick session's current "selected" element (§9.2 pick v2) — set while the user
    /// has clicked something in Safari but not yet confirmed it with Enter or "Use this".
    /// Distinct from `chosen`: a selection is provisional, a choice is committed.
    @Published private(set) var selection: ElementCandidate?
    /// Populated by `useCandidate` when a candidate has more than one `WatchChoice` —
    /// drives the "How should WebWatcher watch it?" card. Empty once a strategy is chosen.
    @Published private(set) var choices: [WatchChoice] = []
    /// The candidate the choice card is currently deciding a strategy for.
    @Published private(set) var pendingChoice: ElementCandidate?
    /// `via` captured alongside `pendingChoice` — `chooseStrategy` is called later, once
    /// the user picks a radio row, so the source (scan vs. pick) has to survive that gap.
    private var pendingChoiceVia: Source = .scan

    /// Set by the editor via `setDiagnosis` once its own probe-driven diagnosis completes,
    /// so the Confirm card can show it without this model knowing how to run a probe.
    @Published private(set) var diagnosisSummary: String?
    @Published private(set) var diagnosisHealthy: Bool = false
    @Published private(set) var diagnosisBackgroundTab: Bool = false

    let pickTimeout: TimeInterval
    let pollInterval: TimeInterval

    private let probe: any ElementProbing

    /// Supplied by the editor. Must reflect the current form fields (url,
    /// autoOpenEnabled, profileId…) at the moment it is called, not at init time.
    var draft: () -> Watcher = { Watcher() }
    var profile: () -> SiteProfile? = { nil }
    /// Called on the main actor when a candidate is chosen. The editor applies
    /// `WatcherRecipe` and runs the diagnosis.
    var onChoose: (ElementCandidate, _ pageURL: String?, _ pageTitle: String?) -> Void = { _, _, _ in }
    /// Restores the previous URL when the editor's "Undo" action fires.
    var onUndoURL: (String) -> Void = { _ in }

    private var task: Task<Void, Never>?
    /// The URL a choice replaced, so "Undo" can restore it. Not published: the
    /// editor only ever sees it through `urlNotice` and the undo action.
    private var previousURLForUndo: String?

    /// `locate()`'s own background task — separate from `task` (scan/pick) so a page-step
    /// retry loop and an element-step scan/pick session can never cancel one another.
    private var locateTask: Task<Void, Never>?
    /// The last URL `locate()` successfully scanned, so `.found` only triggers a fresh
    /// `scan()` once per URL rather than on every re-locate (§3.7: "auto-scan once per URL").
    private var lastScannedURL: String?

    init(probe: any ElementProbing, pickTimeout: TimeInterval = 90, pollInterval: TimeInterval = 0.5) {
        self.probe = probe
        self.pickTimeout = pickTimeout
        self.pollInterval = pollInterval
    }

    // MARK: - Scan

    func scan() {
        task?.cancel()
        // Clear any prior choice up front so its summary card cannot linger next
        // to a freshly rendered candidate list once this scan completes — `phase`
        // alone doesn't cover it, since it returns to `.idle`/`.applied` well
        // before the user picks again.
        chosen = nil
        chosenVia = nil
        task = Task { [weak self] in
            await self?.runScan(isRetry: false)
        }
    }

    private func runScan(isRetry: Bool) async {
        let w = draft()
        let p = profile()

        phase = .scanning
        statusLine = "Scanning the Safari tab…"

        let report = await probe.scan(w, profile: p)
        if Task.isCancelled { return }

        if let reason = report.observation.cannotReason {
            await handleCannot(reason, watcher: w, profileValue: p, isRetry: isRetry) {
                await self.runScan(isRetry: true)
            }
            return
        }

        candidates = report.candidates
        scannedTitle = report.pageTitle
        scannedURL = report.matchedURL
        tabVisible = report.tabVisible
        showList = true
        phase = .idle
        statusLine = report.candidates.isEmpty
            ? "No badges or counters found on this page. Scan looks for notification-style counts — for text, prices or “element exists” watchers, use Pick in Safari."
            : nil
    }

    // MARK: - Pick

    func beginPick() {
        task?.cancel()
        // See scan()'s comment: a stale summary card must not survive into a new
        // pick session.
        chosen = nil
        chosenVia = nil
        selection = nil
        task = Task { [weak self] in
            await self?.runBeginPick(isRetry: false)
        }
    }

    private func runBeginPick(isRetry: Bool) async {
        let w = draft()
        let p = profile()

        let report = await probe.beginPick(w, profile: p)
        if Task.isCancelled { return }

        if let reason = report.observation.cannotReason {
            await handleCannot(reason, watcher: w, profileValue: p, isRetry: isRetry) {
                await self.runBeginPick(isRetry: true)
            }
            return
        }

        guard report.pickState == .waiting else {
            statusLine = "Couldn't start picking — try again."
            phase = .idle
            return
        }

        phase = .picking
        statusLine = "Click the element in Safari — press Esc to cancel."
        await pollPickLoop(watcher: w, profileValue: p)
    }

    private func pollPickLoop(watcher w: Watcher, profileValue p: SiteProfile?) async {
        let deadline = Date().addingTimeInterval(pickTimeout)

        while true {
            if Task.isCancelled { return }

            if Date() >= deadline {
                await probe.endPick(w, profile: p)
                selection = nil
                statusLine = "No click after 90 seconds — try again, or use Scan page instead."
                phase = .idle
                return
            }

            try? await Task.sleep(nanoseconds: UInt64(max(pollInterval, 0) * 1_000_000_000))
            if Task.isCancelled { return }

            let poll = await probe.pollPick(w, profile: p)
            if Task.isCancelled { return }

            if poll.note == "iframe" {
                statusLine = "That element is inside an embedded frame WebWatcher can't reach — pick something outside it."
                continue
            }

            switch poll.pickState {
            case .picked:
                await probe.endPick(w, profile: p)
                if Task.isCancelled { return }
                selection = nil
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let pick = poll.pick {
                    applyChoice(pick, via: .pick)
                } else {
                    statusLine = "The Safari tab changed before you clicked — try again."
                    phase = .idle
                }
                return
            case .selected:
                // Pick session v2 (§9.2): a click landed but hasn't been confirmed yet.
                // The user can press Enter in Safari (caught above next poll) or click the
                // app-side "Use this" button, which calls `confirmSelection()` directly —
                // this loop keeps polling either way so it notices a Safari-side Enter too.
                selection = poll.pick
                if let label = poll.pick?.label {
                    statusLine = "Selected: \(label) — press ⏎ in Safari, or click Use this here."
                }
                continue
            case .cancelled:
                await probe.endPick(w, profile: p)
                selection = nil
                statusLine = "Cancelled."
                phase = .idle
                return
            case .absent:
                await probe.endPick(w, profile: p)
                selection = nil
                statusLine = "The Safari tab changed before you clicked — try again."
                phase = .idle
                return
            case .waiting, .none:
                continue
            }
        }
    }

    /// The app-side "Use this" button while a pick session is `.selected` (§9.2's CSP-proof
    /// path — the in-page toolbar is a convenience, this must always work regardless of the
    /// page's Content-Security-Policy). Confirms the current selection via a dedicated probe
    /// call rather than waiting for the poll loop to notice an Enter keypress in Safari.
    func confirmSelection() {
        guard selection != nil else { return }
        let w = draft()
        let p = profile()

        // Cancel the poll loop SYNCHRONOUSLY, before this method's own `await` — not after.
        // `pollPickLoop` checks `Task.isCancelled` immediately after its own `await
        // probe.pollPick`, before touching `poll.pickState`; cancelling here first
        // guarantees that check sees `true` and the loop can never re-set `selection` (or
        // apply a stale `.picked`/`.selected` poll) out from under the candidate this method
        // is about to commit.
        task?.cancel()
        task = nil

        // The new task is stored back into `task` (not left untracked) so that if the user
        // navigates away while the AppleScript round trip is still in flight — `back(to:)`
        // sees `phase == .picking` and calls `cancel()` — `cancel()`'s own `task?.cancel()`
        // reaches this task too, and the `Task.isCancelled` check below stops its result
        // from overriding whatever the user navigated to in the meantime.
        task = Task { [weak self] in
            guard let self else { return }
            let report = await self.probe.pickConfirm(w, profile: p)
            await self.probe.endPick(w, profile: p)
            if Task.isCancelled { return }

            if report.pickState == .picked, let pick = report.pick {
                self.selection = nil
                NSApplication.shared.activate(ignoringOtherApps: true)
                self.useCandidate(pick, via: .pick)
            } else {
                self.selection = nil
                self.phase = .idle
                self.statusLine = "The Safari tab changed before you clicked — try again."
            }
        }
    }

    // MARK: - Shared .cannot recovery (scan/pick both use this)

    /// `.tabSuspended` → reload once, retry. `.noTab` with auto-open enabled →
    /// open once, retry. Anything else (or a retry that failed again) becomes a
    /// terminal status line.
    private func handleCannot(
        _ reason: CannotReason,
        watcher w: Watcher,
        profileValue p: SiteProfile?,
        isRetry: Bool,
        retry: () async -> Void
    ) async {
        switch reason {
        case .tabSuspended where !isRetry:
            phase = .reloading
            statusLine = "Tab unloaded by Safari — reloading…"
            _ = await probe.reloadTab(for: w, profile: p)
            if Task.isCancelled { return }
            await retry()

        case .noTab where !isRetry && w.autoOpenEnabled:
            phase = .opening
            statusLine = "Opening the page in Safari…"
            let opened = await probe.openBackgroundTab(for: w, profile: p)
            if Task.isCancelled { return }
            if opened {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { return }
                await retry()
            } else {
                statusLine = terminalStatus(for: reason, watcher: w)
                phase = .idle
            }

        default:
            statusLine = terminalStatus(for: reason, watcher: w)
            phase = .idle
        }
    }

    private func terminalStatus(for reason: CannotReason, watcher w: Watcher) -> String {
        if reason == .noTab, !w.autoOpenEnabled {
            let host = URL(string: w.url)?.host ?? w.url
            return "Open \(host) in Safari first."
        }
        if let remedy = reason.remedy {
            return "\(reason.shortStatus) — \(remedy)"
        }
        return reason.shortStatus
    }

    // MARK: - Choice / cancel / lifecycle

    func choose(_ c: ElementCandidate, via: Source = .scan) {
        applyChoice(c, via: via)
    }

    private func applyChoice(_ c: ElementCandidate, via source: Source) {
        chosen = c
        chosenVia = source
        showList = false
        phase = .applied
        // §9.4: a committed choice always lands on the Confirm card, whichever step the
        // user was on (Element, or Page if they skipped straight to a pick).
        step = .confirm
        onChoose(c, scannedURL, scannedTitle)
    }

    /// Shows the previously-saved recipe on the Confirm card when the editor opens an
    /// EXISTING custom watcher (§9.4) — sets `chosen`/`step` directly, without running
    /// `onChoose`, which would re-apply `WatcherRecipe` and fight with fields already
    /// decoded straight off the watcher.
    func openExisting(_ c: ElementCandidate) {
        chosen = c
        chosenVia = nil
        step = .confirm
    }

    func change() {
        switch chosenVia {
        case .scan:
            showList = true
        case .pick:
            beginPick()
        case .none:
            break
        }
    }

    func cancel() {
        let wasPicking = (phase == .picking)
        task?.cancel()
        task = nil
        selection = nil
        phase = .idle
        statusLine = "Cancelled."
        if wasPicking {
            let w = draft()
            let p = profile()
            Task { [probe] in await probe.endPick(w, profile: p) }
        }
    }

    func highlight(_ c: ElementCandidate) {
        let w = draft()
        let p = profile()
        Task { [weak self] in
            guard let self else { return }
            let found = await self.probe.highlight(c.selector, watcher: w, profile: p)
            if !found {
                self.statusLine = "Couldn't find it on the page any more — scan again."
            }
        }
    }

    /// Sets/clears `urlNotice` after `WatcherRecipe.apply` ran. The editor calls
    /// this with the outcome once it has written the new fields back to its
    /// `@State`, so `draft()` already reflects the new URL by the time this runs.
    func noteURLChange(_ outcome: RecipeOutcome) {
        guard outcome.urlChanged, let previous = outcome.previousURL else {
            urlNotice = nil
            previousURLForUndo = nil
            return
        }
        previousURLForUndo = previous
        urlNotice = "Monitored URL set to \(draft().url)"
    }

    /// Restores the URL `noteURLChange` last replaced, via `onUndoURL`, and
    /// clears the notice. No-op if there is nothing pending.
    func undoURLChange() {
        guard let previous = previousURLForUndo else { return }
        onUndoURL(previous)
        urlNotice = nil
        previousURLForUndo = nil
    }

    /// Called from the editor's `.onDisappear`. Same teardown as `cancel()` but
    /// without touching `statusLine` — the window is going away, nobody will see it.
    func stop() {
        let wasPicking = (phase == .picking)
        task?.cancel()
        task = nil
        locateTask?.cancel()
        locateTask = nil
        phase = .idle
        if wasPicking {
            let w = draft()
            let p = profile()
            Task { [probe] in await probe.endPick(w, profile: p) }
        }
    }

    // MARK: - Guided assistant: Page step (§3.7, amended §9.2/§9.4)

    /// Looks for the monitored URL in Safari and updates `tab`. Debounced by the VIEW
    /// (800ms after a user edit to the URL field, §3.7) — this method itself just runs
    /// once per call, so the view is free to cancel/re-trigger as the user types.
    ///
    /// A `loading` response (§9.2 — `document.readyState !== 'complete'`) maps to
    /// `.checking` and is retried after 1s, up to 15s total, rather than treated as a
    /// failure: a page mid-navigation is not the same thing as a missing tab.
    func locate() {
        locateTask?.cancel()
        tab = .checking
        let deadline = Date().addingTimeInterval(15)
        locateTask = Task { [weak self] in
            await self?.runLocate(deadline: deadline)
        }
    }

    private func runLocate(deadline: Date) async {
        // A tab Safari keeps unloading must not keep this loop (and its AppleScript
        // reloads) alive forever: one reload, then a terminal state — the same
        // single-retry rule `handleCannot` applies for scan/pick.
        var reloadedOnce = false
        while true {
            if Task.isCancelled { return }
            let w = draft()
            let p = profile()

            let report = await probe.locate(w, profile: p)
            if Task.isCancelled { return }

            if let reason = report.observation.cannotReason {
                switch reason {
                case .tabSuspended:
                    if reloadedOnce || Date() >= deadline {
                        tab = .failed("Safari keeps unloading this tab — switch to it in Safari, then try again.")
                        return
                    }
                    reloadedOnce = true
                    tab = .reloading
                    _ = await probe.reloadTab(for: w, profile: p)
                    if Task.isCancelled { return }
                    continue
                case .noTab:
                    tab = .notOpen
                    return
                default:
                    tab = .failed(terminalStatus(for: reason, watcher: w))
                    return
                }
            }

            if report.isLoading == true {
                if Date() >= deadline {
                    tab = .failed("Still loading after 15 seconds — try again.")
                    return
                }
                tab = .checking
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                continue
            }

            let matched = report.matchedURL ?? w.url
            tab = .found(title: report.pageTitle ?? "", url: matched, visible: report.tabVisible ?? true)
            if step < .element { step = .element }
            if lastScannedURL != matched {
                lastScannedURL = matched
                scan()
            }
            return
        }
    }

    /// "Open it" on the Page card while `tab == .notOpen`.
    func openTab() {
        guard case .notOpen = tab else { return }
        tab = .opening
        let w = draft()
        let p = profile()
        locateTask?.cancel()
        locateTask = Task { [weak self] in
            guard let self else { return }
            let opened = await self.probe.openBackgroundTab(for: w, profile: p)
            if Task.isCancelled { return }
            guard opened else {
                self.tab = .failed("Couldn't open the page.")
                return
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if Task.isCancelled { return }
            self.locate()
        }
    }

    // MARK: - Guided assistant: Element step (§3.7, amended §9.4)

    /// Splits `candidates` into the Element step's three groups, in scan order within
    /// each group. `.autoBadge` (no reading yet, only a promise of one) is its own group
    /// so it never gets mistaken for a live count; everything that isn't a number reading
    /// (title/text/exists/subtree) falls into "Other".
    var groupedCandidates: (showingNumber: [ElementCandidate], couldGetBadge: [ElementCandidate], other: [ElementCandidate]) {
        var showingNumber: [ElementCandidate] = []
        var couldGetBadge: [ElementCandidate] = []
        var other: [ElementCandidate] = []
        for c in candidates {
            switch c.strategy {
            case .autoBadge:
                couldGetBadge.append(c)
            case .badgeText, .badgeAttr, .ariaCount, .count:
                showingNumber.append(c)
            case .title, .text, .exists, .subtree:
                other.append(c)
            }
        }
        return (showingNumber, couldGetBadge, other)
    }

    /// "Use" on a candidate row, or a confirmed pick. Single watch choice → commit
    /// immediately (mirrors the old one-path-only behavior); more than one → show the
    /// "How should WebWatcher watch it?" card instead of guessing.
    func useCandidate(_ c: ElementCandidate, via: Source = .scan) {
        let options = WatcherRecipe.watchChoices(for: c)
        if options.count <= 1 {
            choices = []
            pendingChoice = nil
            choose(c, via: via)
        } else {
            choices = options
            pendingChoice = c
            pendingChoiceVia = via
        }
    }

    /// A radio row on the choice card.
    func chooseStrategy(_ s: CandidateStrategy) {
        guard let pending = pendingChoice else { return }
        let via = pendingChoiceVia
        choices = []
        pendingChoice = nil
        pendingChoiceVia = .scan
        choose(WatcherRecipe.candidate(pending, switchedTo: s), via: via)
    }

    /// "Change element" on the Confirm card (§9.4): back to Step 2, and — since Confirm
    /// can be reached with `candidates` still empty (a pick never populates the scan list)
    /// — re-runs `locate()`/`scan()` so Step 2 isn't left showing nothing.
    func changeElement() {
        back(to: .element)
        guard candidates.isEmpty else { return }
        lastScannedURL = nil
        locate()
    }

    // MARK: - Guided assistant: navigation

    /// Clickable completed step headers, and the Confirm card's "Editing <url> · Change".
    /// Leaving an in-progress pick session behind when the user jumps away would strand a
    /// live overlay/listener in Safari, so this cancels one first.
    func back(to target: Step) {
        if phase == .picking { cancel() }
        choices = []
        pendingChoice = nil
        step = target
    }

    /// Called by the editor once ITS OWN diagnosis (`SafariScraper.diagnose`) completes, so
    /// the Confirm card can show the same summary without this model knowing how to run a
    /// probe itself.
    func setDiagnosis(summary: String, healthy: Bool, backgroundTab: Bool) {
        diagnosisSummary = summary
        diagnosisHealthy = healthy
        diagnosisBackgroundTab = backgroundTab
    }
}
