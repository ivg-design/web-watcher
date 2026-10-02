import Foundation

/// Escapes a Swift string for embedding in an AppleScript string literal.
///
/// Order matters: backslashes first, then quotes. The old scraper escaped only
/// quotes while the JS generator doubled backslashes, and the two cancelled out
/// by accident — which broke the moment a user pasted a selector containing a
/// backslash (Tailwind's `.w-1\/2` arrived as the invalid selector `.w-1/2`).
func appleScriptEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
}

/// Escapes a multi-line program for an AppleScript string literal.
///
/// AppleScript string literals cannot contain raw newlines, so they become `\n`
/// escapes *after* backslash doubling — otherwise the escape we just inserted would
/// itself be doubled.
///
/// We inline the program rather than shipping `eval(atob(...))`, because Content
/// Security Policy blocks `eval` on LinkedIn, Reddit and Contra — the base64 trick
/// works only on sites permissive enough not to need it.
func appleScriptProgramLiteral(_ s: String) -> String {
    appleScriptEscape(s)
        .replacingOccurrences(of: "\r", with: "")
        .replacingOccurrences(of: "\n", with: "\\n")
}

/// What the injected program should do.
///
/// The four interactive additions (`scan`, `pickStart`/`pickPoll`/`pickStop`,
/// `highlight`) back the Element Picker Assistant (G1/G2); `isInteractive` is what
/// tells the AppleScript layer these must never trigger a background-tab reload
/// the way a routine check can (§5.2 — reloading mid-pick would tear down the
/// overlay/listeners `pickStart` just installed in the page).
enum ProbeMode: Equatable {
    /// Normal check.
    case check
    /// Check plus a step-by-step report for the Selector Doctor.
    case diagnose
    /// Don't read a value; rank candidate anchors on the page.
    case suggestAnchors
    /// Rank candidate badges/counters on the page (Scan page).
    case scan
    /// Install the hover-highlight overlay and click listener (Pick in Safari).
    case pickStart
    /// Poll an in-progress pick session for its current state.
    case pickPoll
    /// Tear down an in-progress pick session.
    case pickStop
    /// Flash a specific selector on the page so the user can confirm it.
    case highlight(selector: String)
    /// G1 step 1 ("Page"): reports whether the watcher's page is open/loaded
    /// (`title`/`href`/`tabState`/`visible`/`loading` from `fin()`, no `value`) —
    /// read-only like `scan`, never brings Safari forward (§3.6).
    case locate
    /// The app-side "Use this element" action (§9.2): confirms whatever is
    /// currently selected in an in-progress pick session. This is the CSP-proof
    /// path — it must work even on pages whose own toolbar key listeners are
    /// blocked — so it is dispatched just like `pickPoll`, never activating the tab.
    case pickConfirm

    /// The `CFG.mode` string the injected program dispatches on (§3.5).
    var key: String {
        switch self {
        case .check:         return "check"
        case .diagnose:      return "diagnose"
        case .suggestAnchors: return "suggest"
        case .scan:          return "scan"
        case .pickStart:     return "pickStart"
        case .pickPoll:      return "pickPoll"
        case .pickStop:      return "pickStop"
        case .highlight:     return "highlight"
        case .locate:        return "locate"
        case .pickConfirm:   return "pickConfirm"
        }
    }

    /// Scan / pick / highlight / locate run against whatever the user is looking
    /// at right now — reloading the tab out from under them (or blowing away a
    /// pick session's listeners) would break the very thing they are trying to do.
    var isInteractive: Bool {
        switch self {
        case .scan, .pickStart, .pickPoll, .pickStop, .highlight, .locate, .pickConfirm: return true
        case .check, .diagnose, .suggestAnchors: return false
        }
    }
}

/// Builds the JavaScript program and the AppleScript wrapper for a probe.
enum ProbeScript {

    // MARK: - Public

    /// Full AppleScript for probing a watcher.
    static func probeScript(for watcher: Watcher, profile: SiteProfile?, mode: ProbeMode) -> String {
        let js = javaScript(for: watcher, profile: profile, mode: mode)
        let host = targetHost(for: watcher, profile: profile)

        // Some sites render their nav badge once at page load and never update it in a
        // backgrounded tab — LinkedIn is one, so its count goes stale the moment you
        // read notifications anywhere else. Those profiles opt into a reload.
        //
        // Refresh is suppressed only while the last outcome was signed-out or a bot
        // check, so an auto-opened sign-in page is not reloaded on a timer forever.
        // Suppressing it for every app-opened tab (as this first did) would leave an
        // auto-opened LinkedIn tab permanently stale.
        let blockedState: Set<String> = [CannotReason.signedOut.rawValue, CannotReason.challenge.rawValue]
        let suppressRefresh = watcher.lastCannotReason.map { blockedState.contains($0) } ?? false
        let wantsRefresh = (watcher.forceRefresh || profile?.needsRefresh == true) && !suppressRefresh

        return probeAppleScript(
            host: host,
            preferredPrefix: canonicalURL(for: watcher, profile: profile),
            program: appleScriptProgramLiteral(js),
            wantsRefresh: wantsRefresh,
            isInteractive: mode.isInteractive,
            settle: watcher.refreshDelay
        )
    }

    /// Brings the ranked tab to the front. Used by `beginPick` and `highlight` (not
    /// by scan, which reads a background tab without disturbing the user's focus).
    /// Never reloads — a blank tab here is `pickStart`'s/`check`'s problem, not this
    /// script's, since bringing a suspended tab forward is often enough by itself
    /// to make Safari repaint it.
    static func activateTabScript(for watcher: Watcher, profile: SiteProfile?) -> String {
        let host = targetHost(for: watcher, profile: profile)
        let escapedHost = appleScriptEscape(host)
        let escapedPrefix = appleScriptEscape(canonicalURL(for: watcher, profile: profile))

        return """
        \(rankingHandlers)

        \(tabSelectionPreamble(escapedPrefix: escapedPrefix, escapedHost: escapedHost))

        tell application "Safari"
            set w to (winRef of chosen)
            set current tab of w to (tab (tabIdx of chosen) of w)
            set index of w to 1
            activate
        end tell

        return "WW_ACTIVATED"
        """
    }

    /// Unconditionally reloads the ranked tab in place (§5.2) — used by
    /// `WatcherService`'s `.tabSuspended` recovery, which has already decided a
    /// reload is warranted and just needs it done.
    static func reloadTabScript(for watcher: Watcher, profile: SiteProfile?) -> String {
        let host = targetHost(for: watcher, profile: profile)
        let escapedHost = appleScriptEscape(host)
        let escapedPrefix = appleScriptEscape(canonicalURL(for: watcher, profile: profile))

        return """
        \(rankingHandlers)

        \(reloadHandlers)

        \(tabSelectionPreamble(escapedPrefix: escapedPrefix, escapedHost: escapedHost))

        set stillBlank to my reloadTab((winRef of chosen), (tabIdx of chosen), \(watcher.refreshDelay))
        if stillBlank then return "WW_STILL_BLANK"
        return "WW_RELOADED"
        """
    }

    /// AppleScript that opens a URL as a background tab without stealing focus.
    static func openBackgroundTabScript(url: String) -> String {
        let escaped = appleScriptEscape(url)
        return """
        if not (application "Safari" is running) then return "WW_SAFARI_CLOSED"
        tell application "Safari"
            if (count of windows) is 0 then
                return "WW_NO_WINDOW"
            end if
            tell window 1
                make new tab with properties {URL:"\(escaped)"}
            end tell
            return "WW_OPENED"
        end tell
        """
    }

    /// The page that can actually answer the question.
    ///
    /// Host-only matching is not enough: LinkedIn's `/notifications/` page renders
    /// with no global nav at all, so a tab sitting there cannot report a badge even
    /// though its host matches.
    static func canonicalURL(for watcher: Watcher, profile: SiteProfile?) -> String {
        if let p = profile, !p.watchURL.isEmpty { return p.watchURL }
        return watcher.url
    }

    /// Host we expect the tab to be on.
    static func targetHost(for watcher: Watcher, profile: SiteProfile?) -> String {
        if let p = profile, !p.hostSuffix.isEmpty { return p.hostSuffix }
        return normalizedHost(from: watcher.url) ?? watcher.url
    }

    static func normalizedHost(from urlString: String) -> String? {
        guard var host = URL(string: urlString)?.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasSuffix(".") { host.removeLast() }
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        return host
    }

    // MARK: - AppleScript · shared tab selection (§5.1)

    /// AppleScript handlers shared by the probe, activate and reload scripts, so the
    /// three scripts rank tabs identically instead of drifting apart. Kept as plain
    /// text (not a helper library file) because each script is a wholly separate
    /// program handed to `NSAppleScript` — there is no way to `import` a shared
    /// AppleScript module, only to paste the same handler text into each.
    ///
    /// `collectCandidates`'s prefix pass is a plain text-prefix comparison with no
    /// scheme requirement, so it matches `file://` URLs (the test fixture) exactly
    /// as it matches `https://` URLs — only the host-suffix fallback pass requires
    /// an `http` prefix, since `file://` URLs have no meaningful host to match on.
    private static let rankingHandlers = #"""
    on hostOf(theURL)
        set oldTIDs to AppleScript's text item delimiters
        try
            set urlText to theURL as text
            if urlText does not contain "://" then
                set AppleScript's text item delimiters to oldTIDs
                return ""
            end if
            set AppleScript's text item delimiters to "://"
            set parts to text items of urlText
            if (count of parts) < 2 then
                set AppleScript's text item delimiters to oldTIDs
                return ""
            end if
            set restPart to item 2 of parts
            set AppleScript's text item delimiters to "/"
            set hostPart to item 1 of (text items of restPart)
            if hostPart contains ":" then
                set AppleScript's text item delimiters to ":"
                set hostPart to item 1 of (text items of hostPart)
            end if
            set AppleScript's text item delimiters to oldTIDs
            if hostPart starts with "www." then return text 5 thru -1 of hostPart
            return hostPart
        on error
            set AppleScript's text item delimiters to oldTIDs
            return ""
        end try
    end hostOf

    on matchesHost(theURL, targetHost)
        if theURL is missing value then return false
        set u to theURL as text
        if u does not start with "http" then return false
        set h to my hostOf(u)
        if h is "" then return false
        if h is targetHost then return true
        if h ends with ("." & targetHost) then return true
        return false
    end matchesHost

    -- §5.1 step 1: a prefix pass over every tab's URL (works for file:// URLs too,
    -- since it is a plain text-prefix test with no scheme requirement), else a host
    -- pass. Returns a list of records {winRef:w, tabIdx:i, vis:v} rather than tab
    -- references directly — a tab reference embeds an index that can go stale the
    -- moment a tab elsewhere in the same window closes, while the window+index pair
    -- here is re-resolved fresh by every handler that consumes it.
    on collectCandidates(wantedPrefix, wantedHost)
        set cands to {}
        tell application "Safari"
            if wantedPrefix is not "" then
                repeat with w in windows
                    set tabURLs to URL of every tab of w
                    repeat with i from 1 to (count of tabURLs)
                        set u to item i of tabURLs
                        if u is not missing value then
                            if (u as text) starts with wantedPrefix then
                                set end of cands to {winRef:w, tabIdx:i, vis:(visible of tab i of w)}
                            end if
                        end if
                    end repeat
                end repeat
            end if
            if (count of cands) is 0 then
                repeat with w in windows
                    set tabURLs to URL of every tab of w
                    repeat with i from 1 to (count of tabURLs)
                        if my matchesHost(item i of tabURLs, wantedHost) then
                            set end of cands to {winRef:w, tabIdx:i, vis:(visible of tab i of w)}
                        end if
                    end repeat
                end repeat
            end if
        end tell
        return cands
    end collectCandidates

    -- §5.1 step 2: visible candidates first, stable within each group (window
    -- enumeration order is preserved because both passes above append in order).
    on rankCandidates(cands)
        set visList to {}
        set restList to {}
        repeat with rec in cands
            if vis of rec then
                set end of visList to rec
            else
                set end of restList to rec
            end if
        end repeat
        return visList & restList
    end rankCandidates

    -- §5.1 step 2 (continued): probes at most the first 4 ranked candidates for
    -- liveness — `location.href` starting with "http" (or "file:", so the local
    -- fixture used by the live-verification protocol counts as live too — real
    -- watchers only ever target http(s) sites) — each inside a 3-second timeout
    -- so one hung/suspended tab cannot stall tab selection for the rest.
    -- Returns {winRef:w, tabIdx:i, vis:v, blank:bool}; `blank` is true only when
    -- none of the probed candidates turned out to be live, in which case the first
    -- candidate is chosen anyway (never zero — that is `collectCandidates`'s job).
    --
    -- `vis` on the RETURNED record is the document's own `visibilityState`, not
    -- Safari's per-window `visible` tab property used for ranking. The two differ
    -- exactly when it matters: the current tab of a window that sits behind other
    -- apps is `visible` to AppleScript but `hidden` to the page, and a hidden page
    -- does not repaint (F2) — so that is the signal the reload decision must use.
    on chooseCandidate(ranked)
        set n to count of ranked
        set probeLimit to 4
        if n < probeLimit then set probeLimit to n
        tell application "Safari"
            repeat with idx from 1 to probeLimit
                set rec to item idx of ranked
                set href to ""
                set docVisible to false
                try
                    with timeout of 3 seconds
                        tell tab (tabIdx of rec) of (winRef of rec)
                            set href to do JavaScript "location.href"
                            set docVisible to ((do JavaScript "document.visibilityState") is "visible")
                        end tell
                    end timeout
                end try
                if href starts with "http" or href starts with "file:" then
                    return {winRef:(winRef of rec), tabIdx:(tabIdx of rec), vis:docVisible, blank:false}
                end if
            end repeat
        end tell
        set rec to item 1 of ranked
        return {winRef:(winRef of rec), tabIdx:(tabIdx of rec), vis:false, blank:true}
    end chooseCandidate
    """#

    /// AppleScript handlers for the unified reload (§5.2), shared by the probe
    /// script's `needReload` branch and `reloadTabScript`.
    private static let reloadHandlers = #"""
    -- Escapes a run-time string for embedding inside a single-quoted JS string
    -- literal that is built via AppleScript concatenation *while the script runs*
    -- (not a text substitution done ahead of time, since the tab's URL is only
    -- known once tab selection has actually happened). Backslashes first, then
    -- quotes — same order as the Swift-side `appleScriptEscape`, for the same
    -- reason: escaping the quote first would double the backslash it just inserted.
    on jsEscapeText(s)
        set oldTIDs to AppleScript's text item delimiters
        set AppleScript's text item delimiters to "\\"
        set s to (text items of s) as text
        set AppleScript's text item delimiters to "\\\\"
        set s to (text items of s) as text
        set AppleScript's text item delimiters to "'"
        set s to (text items of s) as text
        set AppleScript's text item delimiters to "\\'"
        set s to (text items of s) as text
        set AppleScript's text item delimiters to oldTIDs
        return s
    end jsEscapeText

    -- Waits up to 15s (0.5s steps) for `tab tabIdx of winRef` to report readyState
    -- "complete" and an http(s) (or file:, for the local fixture) location — i.e.
    -- for a real document to have replaced a blank one. The tab is re-resolved by
    -- position on every poll (not captured once into a `tab` variable) so a tab
    -- elsewhere in the same window closing mid-wait cannot leave a stale reference
    -- pointed at the wrong physical tab for the rest of the 15s window.
    on waitForLive(winRef, tabIdx)
        set waited to 0
        repeat while waited < 15
            delay 0.5
            set waited to waited + 0.5
            tell application "Safari"
                try
                    set rs to ""
                    set href to ""
                    tell tab tabIdx of winRef
                        set rs to do JavaScript "document.readyState"
                        set href to do JavaScript "location.href"
                    end tell
                    if rs is "complete" and (href starts with "http" or href starts with "file:") then return false
                end try
            end tell
        end repeat
        return true
    end waitForLive

    -- §5.2: `set URL of (tab tabIdx of winRef) to ...` often no-ops when Safari
    -- already thinks the tab is showing that URL (exactly the case F1 describes:
    -- the AppleScript URL is the real page while the document itself is still
    -- about:blank), so a harsher `location.replace` on the tab's own (JS-escaped)
    -- URL is tried before giving up. Returns true iff the tab is still not live
    -- afterward. `delay settleSeconds` runs only when a reload actually landed —
    -- never on failure. `winRef`/`tabIdx` (not a captured tab reference) are
    -- threaded through and re-resolved at every Apple Event send, so a tab closing
    -- elsewhere in the window during this multi-second call cannot make a later
    -- event in the same call land on the wrong tab.
    on reloadTab(winRef, tabIdx, settleSeconds)
        set origURL to ""
        tell application "Safari"
            try
                set origURL to (URL of tab tabIdx of winRef) as text
            end try
            try
                set URL of tab tabIdx of winRef to origURL
            end try
        end tell

        set stillBlank to my waitForLive(winRef, tabIdx)

        if stillBlank and origURL is not "" then
            tell application "Safari"
                try
                    tell tab tabIdx of winRef
                        do JavaScript "location.replace('" & my jsEscapeText(origURL) & "')"
                    end tell
                end try
            end tell
            set stillBlank to my waitForLive(winRef, tabIdx)
        end if

        if not stillBlank then delay settleSeconds
        return stillBlank
    end reloadTab
    """#

    /// §5.1: the boilerplate every one of the three scripts starts with — bail out
    /// if Safari isn't running or has no window, then rank and choose a tab. Kept
    /// as a Swift function (not more AppleScript handler text) purely so the
    /// `wantedPrefix`/`wantedHost` string literals get Swift's `appleScriptEscape`
    /// applied at the call site rather than duplicated three times.
    ///
    /// Note the `is running` check is evaluated *outside* any `tell application
    /// "Safari"` block. Sending an Apple Event inside such a block launches Safari,
    /// which used to produce a window-less Safari and a bogus "Tab not found".
    private static func tabSelectionPreamble(escapedPrefix: String, escapedHost: String) -> String {
        """
        if not (application "Safari" is running) then return "WW_SAFARI_CLOSED"

        tell application "Safari"
            if (count of windows) is 0 then return "WW_NO_WINDOW"
        end tell

        set cands to my collectCandidates("\(escapedPrefix)", "\(escapedHost)")
        if (count of cands) is 0 then return "WW_NO_TAB"
        set ranked to my rankCandidates(cands)
        set chosen to my chooseCandidate(ranked)
        """
    }

    /// Assembles the full probe script: shared tab selection, the unified reload
    /// (§5.2), then the actual `do JavaScript` call.
    private static func probeAppleScript(
        host: String,
        preferredPrefix: String,
        program: String,
        wantsRefresh: Bool,
        isInteractive: Bool,
        settle: Double
    ) -> String {
        let escapedHost = appleScriptEscape(host)
        let escapedPrefix = appleScriptEscape(preferredPrefix)

        // Interactive modes (scan/pick*/highlight) never reload except when the
        // chosen tab is outright blank — reloading a live-but-hidden tab mid-pick
        // would tear down the overlay/listeners `pickStart` just installed.
        let effectiveWantsRefresh = isInteractive ? false : wantsRefresh
        let refreshComment = isInteractive
            ? "-- interactive mode: never reload except when chosenBlank (wantsRefresh forced off)"
            : "-- wantsRefresh reflects forceRefresh / profile.needsRefresh, suppressed while blocked"

        return """
        \(rankingHandlers)

        \(reloadHandlers)

        \(tabSelectionPreamble(escapedPrefix: escapedPrefix, escapedHost: escapedHost))

        set chosenBlank to (blank of chosen)
        set chosenVisible to (vis of chosen)
        \(refreshComment)
        set wantsRefresh to \(effectiveWantsRefresh)
        set needReload to chosenBlank or (wantsRefresh and not chosenVisible)

        -- No tab reference is captured here: `winRef`/`tabIdx` are threaded through
        -- reloadTab and the final read below, each re-resolving `tab tabIdx of
        -- winRef` at the moment its own Apple Event is sent, so a tab elsewhere in
        -- the window closing during the (up to ~30s) reload wait cannot leave a
        -- stale positional reference for the probe read that follows it.
        if needReload then
            set stillBlank to my reloadTab((winRef of chosen), (tabIdx of chosen), \(settle))
            if stillBlank then return "WW_TAB_BLANK"
        end if

        set jsResult to ""
        tell application "Safari"
            tell tab (tabIdx of chosen) of (winRef of chosen)
                set jsResult to do JavaScript "\(program)"
            end tell
        end tell

        if jsResult is missing value then return "WW_EMPTY"
        return jsResult
        """
    }

    // MARK: - JavaScript

    /// Builds `CFG` and substitutes it into `ProbeProgram.source`. The injected
    /// program is embedded as one raw string there so it can contain backslashes,
    /// quotes and regex literals freely — a bare `\d` inside an AppleScript string
    /// literal is a hard compile error (-2741) with no line number.
    static func javaScript(for watcher: Watcher, profile: SiteProfile?, mode: ProbeMode) -> String {
        var cfg: [String: Any] = [
            "mode": mode.key,
            "diag": mode == .diagnose,
            "suggest": mode == .suggestAnchors,
            "pierce": profile?.pierceShadow ?? true,
            // Precedence: an explicit profile always wins (it is the vetted, tested
            // recipe); otherwise a watcher configured by the Element Picker
            // Assistant carries its own strategy; a hand-authored/legacy watcher
            // with neither falls back to "manual" (the raw selector/watchType path).
            "strategy": profile?.strategy.rawValue ?? watcher.strategy?.rawValue ?? "manual",
            "anchor": profile?.anchorSelector ?? watcher.anchorSelector ?? NSNull(),
            // A profile's badge selector wins; otherwise, an assistant-configured
            // watcher (strategy != nil) points `badge` at its own selector, since
            // for anchoredBadge/ariaCount/autoBadge that selector IS the badge.
            "badge": profile?.badgeSelector ?? (watcher.strategy != nil ? watcher.selector : NSNull()),
            "attr": profile?.badgeAttribute ?? watcher.badgeAttribute ?? NSNull(),
            "signedOut": profile?.signedOutSelector ?? NSNull(),
            "selector": watcher.selector,
            "selectorType": watcher.selectorType == .xpath ? "xpath" : "css",
            "watchType": watchTypeKey(watcher.watchType),
            "hl": NSNull()
        ]
        if case .highlight(let selector) = mode {
            cfg["hl"] = selector
        }

        let cfgJSON = (try? JSONSerialization.data(withJSONObject: cfg, options: []))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return ProbeProgram.source.replacingOccurrences(of: "__CFG__", with: cfgJSON)
    }

    private static func watchTypeKey(_ t: WatchType) -> String {
        switch t {
        case .badgeNumber:       return "badge"
        case .elementCount:      return "count"
        case .textChange:        return "text"
        case .elementExists:     return "exists"
        case .elementDisappears: return "disappears"
        // G2: the JS side fingerprints the element's subtree (§3.5/9.2) under this key.
        case .subtreeChange:     return "subtree"
        }
    }
}
