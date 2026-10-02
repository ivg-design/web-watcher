import SwiftUI
import AppKit

/// Editor view for creating or editing a watcher
struct WatcherEditorView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var store: WatcherStore
    var watcherService: WatcherService
    var existingWatcher: Watcher?

    /// Drives the "Which element?" assistant (Scan page / Pick in Safari). Owns its
    /// own polling/timeouts; the editor only wires `draft`/`profile`/`onChoose`.
    @StateObject private var pickerModel: ElementPickerModel

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var selector: String = ""
    @State private var selectorType: SelectorType = .css
    @State private var watchType: WatchType = .badgeNumber
    @State private var interval: CheckInterval = .seconds30
    @State private var notificationSound: Bool = true
    @State private var actionURL: String = ""
    @State private var apiLookupCommand: String = ""

    // Notification customization
    @State private var customIconPath: String = ""
    @State private var notificationTitle: String = ""
    @State private var notificationBodyTemplate: String = ""
    @State private var showingIconPicker = false

    // Badge extraction
    @State private var badgeAttribute: String = ""
    @State private var anchorSelector: String = ""
    @State private var profileId: String = ""
    @State private var autoOpenEnabled: Bool = true

    /// Detection strategy set by the Element Picker Assistant (nil = manual/legacy).
    @State private var strategy: ProbeStrategy? = nil

    // Safari behavior
    @State private var forceRefresh: Bool = false
    @State private var refreshDelay: Double = 2.0

    @State private var testResult: String?
    @State private var isTesting: Bool = false
    @State private var previewStatus: String?

    // Disclosure sections — collapsed by default; Advanced auto-expands when
    // editing a watcher that already has a manually-set selector (§6.1 item 7).
    @State private var advancedExpanded: Bool = false
    @State private var notificationExpanded: Bool = false

    // Selector Doctor + anchor suggestions
    @State private var doctorSteps: [DoctorStep] = []
    @State private var doctorSummary: String?
    @State private var doctorHealthy: Bool = false
    @State private var anchorSuggestions: [AnchorSuggestion] = []
    @State private var isSuggesting: Bool = false

    // Guided assistant (§9.4): the URL field's own 800ms debounce before `locate()` fires,
    // and a flag that swallows the one `.onChange(of: url)` a *programmatic* assignment in
    // `setUp()` triggers — only user edits should ever start a Page-step lookup.
    @State private var urlDebounceTask: Task<Void, Never>?
    @State private var isProgrammaticURLChange = false

    @ObservedObject private var profileStore = SiteProfileStore.shared

    /// Watchers backed by a built-in recipe don't need manual selectors.
    private var usesProfile: Bool { !profileId.isEmpty }

    var isEditing: Bool { existingWatcher != nil }

    /// Single source of truth for this editor's window height (§9.4) — read by both this
    /// view's own `.frame` and `AddWatcherView.size(for: .web)`, so the two can never drift.
    static let contentHeight: CGFloat = 720

    init(store: WatcherStore, watcherService: WatcherService, existingWatcher: Watcher?) {
        self.store = store
        self.watcherService = watcherService
        self.existingWatcher = existingWatcher
        _pickerModel = StateObject(wrappedValue: ElementPickerModel(probe: SafariScraper.shared))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(isEditing ? "Edit Watcher" : "Add Watcher")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. Site recipe — the fast path for adding a new site
                    siteSection

                    // 2. Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., Contra Messages", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 3. URL — profile-backed watchers keep it here since they never touch
                    // the wizard; a custom watcher's URL field lives inside the guided
                    // assistant's own Page step instead (§3.7/§9.4).
                    if usesProfile {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URL to Monitor (must be open in Safari)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("https://example.com/page", text: $url)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // 4. Which element? — the Element Picker Assistant
                    ElementPickerSection(
                        model: pickerModel,
                        usesProfile: usesProfile,
                        profileName: profileStore.profile(id: profileId)?.displayName,
                        onSwitchToManual: { profileId = "" },
                        onUndoURL: { pickerModel.undoURLChange() },
                        url: $url,
                        doctorSteps: doctorSteps,
                        forceRefresh: forceRefresh,
                        onTestAgain: runTest
                    )

                    // 5. Check interval
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check Interval")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $interval) {
                            ForEach(CheckInterval.allCases, id: \.self) { int in
                                Text(int.displayName).tag(int)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    // 6. Watch Type — kept visible; the recipe sets it
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Watch Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $watchType) {
                            ForEach(WatchType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Text(watchType.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // 7. Advanced
                    DisclosureGroup("Advanced", isExpanded: $advancedExpanded) {
                        advancedContent
                            .padding(.top, 8)
                    }

                    // 8. Notification
                    DisclosureGroup("Notification", isExpanded: $notificationExpanded) {
                        notificationContent
                            .padding(.top, 8)
                    }

                    // 9. Selector Doctor — the whole chain, not one opaque string. For a
                    // custom watcher this now lives INSIDE the Confirm card (§9.4); a
                    // profile-backed watcher never runs the wizard, so it keeps its own copy.
                    if usesProfile {
                        Divider()
                        diagnosisSection
                    }
                }
                .padding()
            }

            Divider()

            // 10. Actions
            HStack {
                if isEditing {
                    Button("Delete", role: .destructive) {
                        if let watcher = existingWatcher {
                            store.delete(watcher)
                            watcherService.watcherDeleted(watcher.id)
                        }
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                Button("Save") {
                    saveWatcher()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || url.isEmpty || selector.isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: Self.contentHeight)
        .onAppear(perform: setUp)
        .onDisappear { pickerModel.stop() }
        .onChange(of: url) { _ in
            // §9.4: only a user edit debounces into `locate()` — the programmatic initial
            // assignment `setUp()` makes for an existing watcher must not trigger it. Profile
            // -backed watchers never run the wizard at all, so they're excluded outright.
            guard !usesProfile else { return }
            if isProgrammaticURLChange {
                isProgrammaticURLChange = false
                return
            }
            urlDebounceTask?.cancel()
            urlDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                if Task.isCancelled { return }
                await MainActor.run { pickerModel.locate() }
            }
        }
    }

    // MARK: - Section builders

    private var siteSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Site")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: $profileId) {
                Text("Custom (choose elements yourself)").tag("")
                ForEach(profileStore.profiles.filter { !$0.hostSuffix.isEmpty }) { p in
                    Text(p.displayName).tag(p.id)
                }
                Text("Any site — tab title (N)").tag("generic.title")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: profileId) { newValue in
                applyProfile(id: newValue)
            }

            if let p = profileStore.profile(id: profileId) {
                Text(p.strategy.explanation)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Pick a known site to use a built-in recipe, or set up any page yourself below.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var advancedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selector Type
            VStack(alignment: .leading, spacing: 4) {
                Text("Selector Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $selectorType) {
                    ForEach(SelectorType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            // Selector
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(selectorType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Help") {
                        NSWorkspace.shared.open(URL(string: selectorType.helpURL)!)
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
                TextField(selectorType.placeholder, text: $selector)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Text(selectorType == .css
                    ? "Tip: Right-click element in DevTools → Copy → Copy selector"
                    : "Tip: Right-click element in DevTools → Copy → Copy XPath")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Badge Attribute (only for Badge/Number watch type)
            if watchType == .badgeNumber {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Badge Attribute (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., initial-count, data-count", text: $badgeAttribute)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text("For web components with Shadow DOM. The attribute name on the element that holds the badge value. Leave empty to use innerText.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Anchor — what makes a zero trustworthy
            if !usesProfile {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Anchor (recommended)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: runSuggestAnchors) {
                            HStack(spacing: 4) {
                                if isSuggesting {
                                    ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text("Suggest")
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                        .disabled(url.isEmpty || isSuggesting)
                    }
                    TextField("e.g., button[data-testid=\"notifications-button\"]", text: $anchorSelector)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text("An element that is always on the page, next to the badge. Without it, a missing badge is ambiguous — WebWatcher can't tell \"zero\" from \"signed out\" or \"page changed\".")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !anchorSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Candidates found on the page")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(anchorSuggestions) { s in
                                Button(action: { anchorSelector = s.selector }) {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: s.isFragile ? "exclamationmark.triangle" : "checkmark.circle")
                                            .foregroundColor(s.isFragile ? .orange : .green)
                                            .font(.caption2)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(s.selector)
                                                .font(.system(.caption2, design: .monospaced))
                                                .lineLimit(1)
                                            Text("\(s.tierName)\(s.sample.map { " — \($0)" } ?? "")")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
            }

            // Strategy — read-only, set by the assistant
            HStack {
                Text("Strategy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(strategy?.displayName ?? "Manual")
                    .font(.caption)
                Button("Clear") { strategy = nil }
                    .buttonStyle(.link)
                    .font(.caption)
                    .disabled(strategy == nil)
            }

            Toggle("Open the page automatically if no tab is found", isOn: $autoOpenEnabled)
                .font(.caption)

            // Force Refresh
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Force refresh before checking", isOn: $forceRefresh)
                Text("Reloads the Safari tab before scraping. Enable this if values appear stale or don't update (Safari suspends background tabs).")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if forceRefresh {
                    HStack {
                        Text("Settle delay:")
                            .font(.caption)
                        Slider(value: $refreshDelay, in: 0.5...5.0, step: 0.5)
                            .frame(width: 120)
                        Text(String(format: "%.1fs", refreshDelay))
                            .font(.caption)
                            .frame(width: 30)
                    }
                    .padding(.top, 4)
                    Text("Time to wait after page loads for dynamic content to update.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Action URL (optional)
            VStack(alignment: .leading, spacing: 4) {
                Text("Action URL (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("URL to open when clicking notification or row", text: $actionURL)
                    .textFieldStyle(.roundedBorder)
                Text("Leave empty to use the monitored URL")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API Lookup Command (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., curl -s https://api.example.com/messages/latest", text: $apiLookupCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Runs when opening from row click or notification. Command must print a URL to stdout. Supports {url} and {domain} placeholders.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var notificationContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Play sound with notification", isOn: $notificationSound)

            // Custom Icon
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Icon (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    if !customIconPath.isEmpty, let image = NSImage(contentsOfFile: customIconPath) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .cornerRadius(4)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }

                    TextField("Path to icon image", text: $customIconPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button("Browse...") {
                        pickIcon()
                    }

                    if !customIconPath.isEmpty {
                        Button(action: { customIconPath = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("PNG, JPG, or ICNS file. Displays in notification.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Custom Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Notification Title (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., You've got {value} LinkedIn messages", text: $notificationTitle)
                    .textFieldStyle(.roundedBorder)
                Text("Leave empty to use the watcher name. {value} and {name} work here too.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Custom Body Template
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Body Template (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., {value} new messages waiting", text: $notificationBodyTemplate)
                    .textFieldStyle(.roundedBorder)
                Text("Use {value} for the detected value, {name} for the watcher name, {previous} for the last value. Works in the title too.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Preview Notification
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: previewNotification) {
                        HStack {
                            Image(systemName: "bell.badge")
                            Text("Preview Notification")
                        }
                    }
                    Spacer()
                }

                if let status = previewStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(status.contains("Sent") ? .green : .orange)
                }
            }
        }
    }

    private var diagnosisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: runTest) {
                    HStack {
                        if isTesting {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "stethoscope")
                        }
                        Text("Run Diagnosis")
                    }
                }
                .disabled(url.isEmpty || isTesting || (!usesProfile && selector.isEmpty))

                Spacer()
            }

            if let summary = doctorSummary {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: doctorHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(doctorHealthy ? .green : .orange)
                        Text(summary)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(doctorSteps) { step in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: step.passed ? "checkmark.circle" : "xmark.circle")
                                .foregroundColor(step.passed ? .green : .red)
                                .font(.caption2)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(step.label).font(.caption2)
                                if let note = step.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }

                    if let result = testResult {
                        Text(result)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Setup

    private func setUp() {
        if let watcher = existingWatcher {
            // §9.4: this is the "programmatic initial URL assignment" `locate()` must NOT
            // fire for — set before `url` actually changes so the `.onChange` it triggers
            // sees the flag already up.
            isProgrammaticURLChange = true
            name = watcher.name
            url = watcher.url
            selector = watcher.selector
            selectorType = watcher.selectorType
            watchType = watcher.watchType
            interval = watcher.interval
            notificationSound = watcher.notificationSound
            actionURL = watcher.actionURL ?? ""
            apiLookupCommand = watcher.apiLookupCommand ?? ""
            badgeAttribute = watcher.badgeAttribute ?? ""
            anchorSelector = watcher.anchorSelector ?? ""
            profileId = watcher.profileId ?? ""
            strategy = watcher.strategy
            autoOpenEnabled = watcher.autoOpenEnabled
            customIconPath = watcher.customIconPath ?? ""
            notificationTitle = watcher.notificationTitle ?? ""
            notificationBodyTemplate = watcher.notificationBodyTemplate ?? ""
            forceRefresh = watcher.forceRefresh
            refreshDelay = watcher.refreshDelay

            // A watcher hand-configured before the assistant existed (non-empty
            // selector, nothing chosen yet this session) needs its selector visible
            // right away rather than hidden behind a collapsed disclosure group.
            if !watcher.selector.isEmpty && pickerModel.chosen == nil {
                advancedExpanded = true
            }
        }

        pickerModel.draft = { [self] in draftWatcher() }
        pickerModel.profile = { [self] in profileId.isEmpty ? nil : profileStore.profile(id: profileId) }
        pickerModel.onChoose = { [self] candidate, pageURL, pageTitle in
            applyPickerChoice(candidate, pageURL: pageURL, pageTitle: pageTitle)
        }
        pickerModel.onUndoURL = { [self] previous in url = previous }

        // §9.4: an existing custom (non-profile) watcher already has a saved recipe — open
        // straight on the Confirm card instead of re-running Page/Element.
        if let watcher = existingWatcher, profileId.isEmpty, !watcher.selector.isEmpty {
            pickerModel.openExisting(syntheticCandidate(for: watcher))
        }
    }

    /// Reconstructs an `ElementCandidate` good enough for the Confirm card's summary line
    /// out of an already-saved watcher's raw fields (§9.4) — there is no real candidate to
    /// reopen, only the recipe `WatcherRecipe.apply` left behind.
    private func syntheticCandidate(for watcher: Watcher) -> ElementCandidate {
        let strategy: CandidateStrategy
        switch watcher.watchType {
        case .subtreeChange:
            strategy = .subtree
        case .textChange:
            strategy = .text
        case .elementCount:
            strategy = .count
        case .elementExists, .elementDisappears:
            strategy = .exists
        case .badgeNumber:
            switch watcher.strategy {
            case .ariaCount:      strategy = .ariaCount
            case .autoBadge:      strategy = .autoBadge
            case .documentTitle:  strategy = .title
            case .anchoredBadge, .none:
                strategy = (watcher.badgeAttribute?.isEmpty == false) ? .badgeAttr : .badgeText
            }
        }
        return ElementCandidate(
            selector: watcher.selector,
            anchor: watcher.anchorSelector,
            strategy: strategy,
            attr: watcher.badgeAttribute,
            value: watcher.lastConclusiveValue,
            label: watcher.name.isEmpty ? watcher.selector : watcher.name,
            detail: "",
            technical: watcher.selector,
            tier: 1,
            score: 0
        )
    }

    /// Fill in everything a built-in recipe already knows.
    private func applyProfile(id: String) {
        guard let p = profileStore.profile(id: id) else { return }
        if !p.watchURL.isEmpty { url = p.watchURL }
        if let a = p.actionURL, actionURL.isEmpty { actionURL = a }
        if name.isEmpty { name = p.displayName }
        anchorSelector = p.anchorSelector ?? ""
        // documentTitle (e.g. "Any site — tab title (N)") has neither a badge nor
        // an anchor selector of its own — the value lives in `document.title` — so
        // without this branch `selector` stays "" and Save can never be enabled.
        // Mirrors WatcherRecipe.apply's own .title branch.
        if p.strategy == .documentTitle {
            selector = "title"
        } else {
            selector = p.badgeSelector ?? p.anchorSelector ?? ""
        }
        badgeAttribute = p.badgeAttribute ?? ""
        selectorType = .css
        watchType = .badgeNumber
        // Reflect the profile's own strategy so the read-only Strategy row in
        // Advanced shows it instead of always reading "Manual", and so a stale
        // assistant-picked strategy from an earlier custom selection can't survive
        // into a profile-backed (or, after "Set up manually instead", a nil-profile)
        // watcher shaped for a different strategy's fields.
        strategy = p.strategy
        // Built-in recipes target pages that update live; reloading is waste.
        forceRefresh = p.needsRefresh
        doctorSummary = nil
        doctorSteps = []
    }

    private func draftWatcher() -> Watcher {
        Watcher(
            name: name.isEmpty ? "Test" : name,
            url: url,
            selector: selector,
            selectorType: selectorType,
            watchType: watchType,
            interval: interval,
            badgeAttribute: badgeAttribute.isEmpty ? nil : badgeAttribute,
            anchorSelector: anchorSelector.isEmpty ? nil : anchorSelector,
            profileId: profileId.isEmpty ? nil : profileId,
            strategy: strategy,
            autoOpenEnabled: autoOpenEnabled,
            forceRefresh: forceRefresh,
            refreshDelay: refreshDelay
        )
    }

    // MARK: - Element Picker Assistant wiring

    /// `ElementPickerModel.onChoose`: apply the recipe to the form fields, name the
    /// watcher if it has no name yet, surface a URL change, then re-run the
    /// diagnosis so the summary reflects what was just picked/scanned.
    private func applyPickerChoice(_ candidate: ElementCandidate, pageURL: String?, pageTitle: String?) {
        var fields = WatcherDraftFields(
            name: name,
            url: url,
            selector: selector,
            selectorType: selectorType,
            watchType: watchType,
            badgeAttribute: badgeAttribute,
            anchorSelector: anchorSelector,
            profileId: profileId,
            strategy: strategy,
            forceRefresh: forceRefresh
        )
        let outcome = WatcherRecipe.apply(candidate, pageURL: pageURL, pageTitle: pageTitle, to: &fields)

        url = fields.url
        selector = fields.selector
        selectorType = fields.selectorType
        watchType = fields.watchType
        badgeAttribute = fields.badgeAttribute
        anchorSelector = fields.anchorSelector
        profileId = fields.profileId
        strategy = fields.strategy
        forceRefresh = fields.forceRefresh

        if name.isEmpty {
            name = WatcherRecipe.suggestedName(for: candidate, pageURL: pageURL, pageTitle: pageTitle)
        }

        pickerModel.noteURLChange(outcome)

        let viaPick = (pickerModel.chosenVia == .pick)
        runDiagnosisAfterChoice(viaPick: viaPick)
    }

    /// Runs the diagnosis automatically after a choice. A pick gets an 0.8s grace
    /// period first — the user likely just clicked inside an open menu/popover in
    /// Safari, and probing before it closes would test a DOM state that is about
    /// to go away (§6.1 item 9).
    private func runDiagnosisAfterChoice(viaPick: Bool) {
        let draft = draftWatcher()
        let profile = profileId.isEmpty ? nil : profileStore.profile(id: profileId)
        let delayNanos: UInt64 = viaPick ? 800_000_000 : 0

        isTesting = true
        Task {
            if delayNanos > 0 {
                try? await Task.sleep(nanoseconds: delayNanos)
            }
            let report = await SafariScraper.shared.diagnose(draft, profile: profile)
            await MainActor.run {
                isTesting = false
                applyDoctor(report, cameFromPick: viaPick)
            }
        }
    }

    private func runTest() {
        isTesting = true
        testResult = nil
        doctorSteps = []
        doctorSummary = nil

        let draft = draftWatcher()
        let profile = profileId.isEmpty ? nil : profileStore.profile(id: profileId)

        Task {
            var report = await SafariScraper.shared.diagnose(draft, profile: profile)

            // "No tab" is fixable: open the page and try again, so the diagnosis
            // reflects the page rather than its absence.
            if report.observation.cannotReason == .noTab, autoOpenEnabled {
                if await SafariScraper.shared.openBackgroundTab(for: draft, profile: profile) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    report = await SafariScraper.shared.diagnose(draft, profile: profile)
                }
            }

            await MainActor.run {
                isTesting = false
                applyDoctor(report)
            }
        }
    }

    /// `cameFromPick` is true only for the automatic diagnosis that follows a
    /// "Pick in Safari" choice — see `runDiagnosisAfterChoice`.
    private func applyDoctor(_ report: ProbeReport, cameFromPick: Bool = false) {
        var steps: [DoctorStep] = [
            DoctorStep(label: "Safari running", passed: report.observation.cannotReason != .safariClosed, note: nil),
            DoctorStep(
                label: "Tab found",
                passed: report.observation.cannotReason != .noTab,
                note: report.matchedURL
            )
        ]
        steps.append(contentsOf: report.steps)

        if !usesProfile && anchorSelector.isEmpty {
            steps.append(DoctorStep(
                label: "Zero can be confirmed",
                passed: false,
                note: "No anchor set — a missing badge is ambiguous"
            ))
        }

        if report.tabVisible == false {
            let note = forceRefresh
                ? "WebWatcher reloads the tab before each check"
                : "If values look stale, turn on Force refresh in Advanced."
            steps.append(DoctorStep(label: "Read from a background tab", passed: true, note: note))
        }

        doctorSteps = steps

        switch report.observation {
        case .value(let v):
            doctorHealthy = true
            let badge = BadgeValue.parse(v)
            doctorSummary = "Reading: \(badge?.display ?? v)"
            testResult = badge?.isCapped == true
                ? "The site caps this badge, so the exact number above \(badge!.number) isn't visible."
                : nil
        case .zero:
            doctorHealthy = true
            doctorSummary = "Confirmed zero — the anchor is present and there's no badge."
            testResult = nil
        case .cannot(let reason, let detail):
            doctorHealthy = false
            if cameFromPick, reason == .selectorMiss || reason == .anchorMissing {
                // The element that was just clicked likely only exists while the
                // menu/popover it lives in is open — it's gone now that this
                // diagnosis waited for that menu to close.
                doctorSummary = "This element may only be there while its menu is open — WebWatcher checked again after the menu closed. Try picking a part of the page that's always visible, like the button that opens the menu."
            } else {
                doctorSummary = reason.shortStatus
            }
            testResult = [reason.remedy, detail.map { "Detail: \($0)" }]
                .compactMap { $0 }
                .joined(separator: "\n")
        }

        // §5/§9.4: the Confirm card's own summary line — worded slightly differently from
        // `doctorSummary` above ("Current reading:" vs "Reading:", and a subtree watcher's
        // .zero reads as a snapshot baseline rather than a literal "no badge").
        pickerModel.setDiagnosis(
            summary: confirmCardSummary(for: report),
            healthy: doctorHealthy,
            backgroundTab: report.tabVisible == false
        )
    }

    private func confirmCardSummary(for report: ProbeReport) -> String {
        switch report.observation {
        case .value(let v):
            let badge = BadgeValue.parse(v)
            return "Current reading: \(badge?.display ?? v)"
        case .zero:
            return watchType == .subtreeChange
                ? "Snapshot taken — you'll be notified when anything inside changes."
                : "Confirmed zero — the anchor is present and there's no badge."
        case .cannot(let reason, _):
            return reason.shortStatus
        }
    }

    private func runSuggestAnchors() {
        isSuggesting = true
        anchorSuggestions = []

        let draft = draftWatcher()
        let profile = profileId.isEmpty ? nil : profileStore.profile(id: profileId)

        Task {
            var report = await SafariScraper.shared.suggestAnchors(draft, profile: profile)
            if report.observation.cannotReason == .noTab, autoOpenEnabled {
                if await SafariScraper.shared.openBackgroundTab(for: draft, profile: profile) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    report = await SafariScraper.shared.suggestAnchors(draft, profile: profile)
                }
            }
            await MainActor.run {
                isSuggesting = false
                anchorSuggestions = report.suggestedAnchors
                if report.suggestedAnchors.isEmpty {
                    doctorSummary = report.observation.cannotReason?.shortStatus
                        ?? "No obvious anchor found on the page."
                    doctorHealthy = false
                }
            }
        }
    }

    private func saveWatcher() {
        var watcher = existingWatcher ?? Watcher()
        watcher.name = name
        watcher.url = url
        watcher.selector = selector
        watcher.selectorType = selectorType
        watcher.watchType = watchType
        watcher.interval = interval
        watcher.notificationSound = notificationSound
        watcher.actionURL = actionURL.isEmpty ? nil : actionURL
        watcher.apiLookupCommand = apiLookupCommand.isEmpty ? nil : apiLookupCommand
        watcher.badgeAttribute = badgeAttribute.isEmpty ? nil : badgeAttribute
        watcher.anchorSelector = anchorSelector.isEmpty ? nil : anchorSelector
        watcher.profileId = profileId.isEmpty ? nil : profileId
        watcher.strategy = strategy
        watcher.autoOpenEnabled = autoOpenEnabled
        // Typed or legacy paths are copied into the managed folder too, so the original
        // file can move or disappear without breaking the notification image.
        watcher.customIconPath = customIconPath.isEmpty ? nil : (NotificationIconStore.importIcon(from: customIconPath) ?? customIconPath)
        watcher.notificationTitle = notificationTitle.isEmpty ? nil : notificationTitle
        watcher.notificationBodyTemplate = notificationBodyTemplate.isEmpty ? nil : notificationBodyTemplate
        watcher.forceRefresh = forceRefresh
        watcher.refreshDelay = refreshDelay

        if isEditing {
            store.update(watcher)
            watcherService.watcherUpdated(watcher)
        } else {
            watcher.isEnabled = true
            store.add(watcher)
            watcherService.watcherUpdated(watcher)
        }
    }

    private func pickIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .icns]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Select Icon Image"

        if panel.runModal() == .OK, let url = panel.url {
            customIconPath = NotificationIconStore.importIcon(from: url.path) ?? url.path
        }
    }

    private func previewNotification() {
        previewStatus = "Requesting permission..."

        Task {
            let granted = await NotificationService.shared.requestPermission()

            await MainActor.run {
                if granted {
                    let previewWatcher = Watcher(
                        name: name.isEmpty ? "Preview Watcher" : name,
                        url: url,
                        selector: selector,
                        selectorType: selectorType,
                        watchType: watchType,
                        interval: interval,
                        notificationSound: notificationSound,
                        actionURL: actionURL.isEmpty ? nil : actionURL,
                        apiLookupCommand: apiLookupCommand.isEmpty ? nil : apiLookupCommand,
                        customIconPath: customIconPath.isEmpty ? nil : customIconPath,
                        notificationTitle: notificationTitle.isEmpty ? nil : notificationTitle,
                        notificationBodyTemplate: notificationBodyTemplate.isEmpty ? nil : notificationBodyTemplate
                    )

                    NotificationService.shared.sendPreview(watcher: previewWatcher, testValue: "3")
                    previewStatus = "Sent! Check your notifications."

                    // Clear status after a few seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        previewStatus = nil
                    }
                } else {
                    previewStatus = "Permission denied. Enable in System Settings → Notifications"
                }
            }
        }
    }
}
