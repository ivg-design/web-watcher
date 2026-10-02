import SwiftUI

/// "Which element?" — the editor's three-step guided assistant (Page → Element → Confirm,
/// G1/§3.7, amended §9.4). Profile-backed watchers skip the wizard entirely (there's
/// nothing to locate/scan — the recipe already knows everything) and get the short
/// `profileBackedContent` instead.
struct ElementPickerSection: View {
    @ObservedObject var model: ElementPickerModel
    var usesProfile: Bool
    var profileName: String?
    var onSwitchToManual: () -> Void
    var onUndoURL: () -> Void

    /// Step 1's own URL field (§9.4: "the URL field lives inside step 1"). The editor owns
    /// the 800ms debounce + `locate()` wiring on `.onChange(of: url)` — this view only
    /// renders the field; it has no way to tell a user edit from `setUp()`'s programmatic
    /// initial assignment, which the editor does.
    @Binding var url: String
    /// The Confirm card's diagnosis detail list — owned by the editor (it already runs
    /// `SafariScraper.diagnose`), not the model, so this model stays probe-agnostic.
    var doctorSteps: [DoctorStep]
    /// Whether the watcher currently has "Force refresh" on, for the background-tab line's
    /// exact wording (§5).
    var forceRefresh: Bool
    var onTestAgain: () -> Void

    /// The choice card's own radio selection — a `WatchChoice` is only committed
    /// (`model.chooseStrategy`) when "Continue" is pressed (§3.3/§9.4), not on the radio
    /// tap itself. Reset whenever `model.pendingChoice` changes to a different candidate.
    @State private var selectedChoiceStrategy: CandidateStrategy?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Which element?")
                .font(.caption)
                .foregroundColor(.secondary)

            if usesProfile {
                profileBackedContent
            } else {
                guidedContent
            }
        }
    }

    // MARK: - Profile-backed

    private var profileBackedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Using the built-in recipe for \(profileName ?? "this site").")
                .font(.caption)
            Button("Set up manually instead", action: onSwitchToManual)
                .buttonStyle(.link)
                .font(.caption)
        }
    }

    // MARK: - Guided assistant

    private var guidedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            stepHeader(.page, title: "1 · Page")
            if model.step == .page {
                pageCard
            }

            stepHeader(.element, title: "2 · Element")
            if model.step == .element {
                elementCard
            }

            stepHeader(.confirm, title: "3 · Confirm")
            if model.step == .confirm {
                confirmCard
            }

            if let notice = model.urlNotice {
                HStack {
                    Text(notice)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Undo", action: onUndoURL)
                        .buttonStyle(.link)
                        .font(.caption2)
                }
            }
        }
    }

    /// A step's numbered header — a checkmark once it's behind the current step, and
    /// clickable (via `back(to:)`) whenever it is (§9.4: "clickable completed step headers").
    private func stepHeader(_ step: ElementPickerModel.Step, title: String) -> some View {
        let isComplete = step < model.step
        let isCurrent = step == model.step
        return HStack(spacing: 6) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .secondary)
                .font(.caption2)
            if isComplete {
                Button(title, action: { model.back(to: step) })
                    .buttonStyle(.link)
                    .font(.caption.weight(isCurrent ? .semibold : .regular))
            } else {
                Text(title)
                    .font(.caption.weight(isCurrent ? .semibold : .regular))
                    .foregroundColor(isCurrent ? .primary : .secondary)
            }
        }
    }

    // MARK: - Step 1: Page

    @ViewBuilder
    private var pageCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("https://example.com/page", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Text(tabStatusLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if case .checking = model.tab {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                }
            }

            switch model.tab {
            case .notOpen:
                Button("Open it", action: model.openTab)
                    .buttonStyle(.link)
                    .font(.caption)
            case .failed:
                Button("Try again", action: model.locate)
                    .buttonStyle(.link)
                    .font(.caption)
            default:
                EmptyView()
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.06))
        .cornerRadius(6)
    }

    private var tabStatusLine: String {
        switch model.tab {
        case .unknown:
            return "Enter a URL above to get started."
        case .checking:
            return "Looking for the page in Safari…"
        case .found(let title, _, let visible):
            let name = title.isEmpty ? "the page" : title
            return "Found in Safari: \(name)" + (visible ? "" : " · background tab")
        case .notOpen:
            return "Not open in Safari"
        case .opening:
            return "Opening the page in Safari…"
        case .reloading:
            return "Tab unloaded — reloading…"
        case .failed(let message):
            return message
        }
    }

    // MARK: - Step 2: Element

    @ViewBuilder
    private var elementCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button("Pick in Safari", action: model.beginPick)
                    .disabled(isBusy)
                Button("Rescan", action: model.scan)
                    .disabled(isBusy)
                if isBusy {
                    Button("Cancel", action: model.cancel)
                        .buttonStyle(.link)
                }
                Spacer()
            }

            // Suppressed once the candidate groups below are about to show their own
            // empty-state copy (§9.4) — `model.statusLine`'s "No badges or counters found…"
            // (unchanged for the pre-existing scan-list UI/tests) would otherwise say the
            // same thing twice.
            if let status = model.statusLine, !candidatesAreEmptyAfterScan {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The app-side "Use this" — always works even when the page's CSP blocks the
            // in-page toolbar's own confirm button (§9.2).
            if model.selection != nil {
                Button("Use this", action: model.confirmSelection)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            if !model.choices.isEmpty {
                choiceCard
            } else if !isBusy {
                candidateGroups
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.06))
        .cornerRadius(6)
    }

    private var isBusy: Bool {
        switch model.phase {
        case .scanning, .reloading, .opening, .picking: return true
        case .idle, .applied: return false
        }
    }

    /// True only once a scan has settled on zero candidates (`.idle`, not mid-pick/scan/
    /// reload/open) — NOT during `.picking`, where `statusLine` carries the pick session's
    /// own status ("Click the element…", "Selected: …") and must never be suppressed just
    /// because the last scan (if any) happened to be empty.
    private var candidatesAreEmptyAfterScan: Bool {
        model.phase == .idle && model.choices.isEmpty && model.candidates.isEmpty
    }

    @ViewBuilder
    private var candidateGroups: some View {
        let groups = model.groupedCandidates
        if groups.showingNumber.isEmpty && groups.couldGetBadge.isEmpty && groups.other.isEmpty {
            Text("Nothing that looks like a counter. Click “Pick in Safari” — point at any element, even one with nothing showing yet, and choose “Anything changes inside” next.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    candidateGroup("Showing a number now", groups.showingNumber)
                    candidateGroup("Could get a badge later", groups.couldGetBadge)
                    candidateGroup("Other", groups.other)
                }
            }
            .frame(maxHeight: 220)
        }
    }

    @ViewBuilder
    private func candidateGroup(_ title: String, _ items: [ElementCandidate]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                VStack(spacing: 0) {
                    ForEach(items) { candidate in
                        candidateRow(candidate)
                        if candidate.id != items.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color.gray.opacity(0.05))
                .cornerRadius(6)
            }
        }
    }

    private func candidateRow(_ c: ElementCandidate) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(c.displayValue)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 1) {
                Text(c.label)
                    .font(.caption)
                    .lineLimit(1)
                Text(c.detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button(action: { model.highlight(c) }) {
                Image(systemName: "eye")
                    .font(.caption2)
            }
            .buttonStyle(.link)

            Button("Use", action: { model.useCandidate(c) })
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .help(c.technical)
    }

    /// "How should WebWatcher watch it?" (§3.3/§9.4) — shown once `useCandidate` finds more
    /// than one `WatchChoice` for the candidate just picked/scanned.
    @ViewBuilder
    private var choiceCard: some View {
        // The recommended choice is the sensible default the first time this card appears
        // for a given candidate — `.onChange` below re-seeds it whenever `pendingChoice`
        // changes so a stale radio selection can never survive into a different candidate's
        // choice set.
        let effectiveSelection = selectedChoiceStrategy ?? model.choices.first(where: { $0.recommended })?.id ?? model.choices.first?.id

        return VStack(alignment: .leading, spacing: 8) {
            Text("How should WebWatcher watch it?")
                .font(.caption)
                .fontWeight(.semibold)

            if let pending = model.pendingChoice {
                Text("You picked: \(pending.label)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .help(pending.technical)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.choices) { choice in
                    Button(action: { selectedChoiceStrategy = choice.id }) {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: effectiveSelection == choice.id ? "largecircle.fill.circle" : "circle")
                                .font(.caption2)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(choice.title).font(.caption)
                                    if choice.recommended {
                                        Text("Recommended")
                                            .font(.caption2)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                Text(choice.detail)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Continue") {
                    if let strategy = effectiveSelection {
                        model.chooseStrategy(strategy)
                    }
                    selectedChoiceStrategy = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(6)
        .onChange(of: model.pendingChoice) { _ in
            selectedChoiceStrategy = nil
        }
    }

    // MARK: - Step 3: Confirm

    @ViewBuilder
    private var confirmCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("Editing \(url) · ")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Change")
                    .foregroundColor(.accentColor)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .onTapGesture { model.back(to: .page) }

            if let chosen = model.chosen {
                HStack(alignment: .top) {
                    Text(WatcherRecipe.summary(for: chosen))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(6)
            }

            if let summary = model.diagnosisSummary {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: model.diagnosisHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(model.diagnosisHealthy ? .green : .orange)
                        Text(summary)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if model.diagnosisBackgroundTab {
                        Text(forceRefresh
                             ? "Read from a background tab — WebWatcher reloads it before each check."
                             : "Read from a background tab — turn on Force refresh in Advanced if values look stale.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let warning = fingerprintWarning {
                        Text(warning)
                            .font(.caption2)
                            .foregroundColor(.orange)
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
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }

            HStack {
                Button("Test again", action: onTestAgain)
                    .buttonStyle(.link)
                    .font(.caption)
                Button("Change element", action: model.changeElement)
                    .buttonStyle(.link)
                    .font(.caption)
                Spacer()
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.06))
        .cornerRadius(6)
    }

    /// §9.4: "when the diagnosis' Fingerprint step reports n > 150 elements" — the JS side
    /// (§3.5/9.2) reports the subtree's real descendant count as `"<n> elements"` in the
    /// Fingerprint step's note regardless of the 400-node traversal cap, specifically so
    /// this warning can fire on the true size.
    private var fingerprintWarning: String? {
        guard let step = doctorSteps.first(where: { $0.label == "Fingerprint" }),
              let note = step.note else { return nil }
        let digits = note.prefix(while: { $0.isNumber })
        guard let n = Int(digits), n > 150 else { return nil }
        return "This area has \(n) elements — a busy container may notify more often than you want. Consider picking a smaller part (↑/↓ in Safari)."
    }
}
