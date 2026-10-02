import SwiftUI

/// Top-level "Add Watcher" chooser: a segmented control switches between the existing web
/// watcher editor and the new Gmail sender editor. The two editors want different window
/// sizes, so this view reports the target size through `onKindChange` and leaves the actual
/// `NSWindow.setContentSize` call to whoever hosts it (WebWatcherApp) rather than trying to
/// resize its own host window directly from SwiftUI.
struct AddWatcherView: View {
    enum Kind: Hashable {
        case web
        case email
    }

    var store: WatcherStore
    var watcherService: WatcherService
    var gmailStore: GmailAccountStore
    var emailWatcherStore: EmailWatcherStore
    var gmailPolling: GmailPollingService?
    var onOpenSettings: () -> Void
    var onKindChange: (CGSize) -> Void

    @State private var kind: Kind = .web

    /// Height of the segmented bar plus its divider, kept as one constant so the
    /// window size and the bar layout cannot drift apart.
    static let barHeight: CGFloat = 45

    /// The window size that matches each editor's own `.frame(width:height:)` (§3.11,
    /// §9.4 — `contentHeight` on each editor is the single source of truth, so this can
    /// never drift from what the editor itself requests).
    private static func size(for kind: Kind) -> CGSize {
        // Each editor fixes its own frame; the segmented bar and its divider sit above it,
        // so the window must be taller by exactly that amount or the Save/Delete bar at the
        // bottom is clipped.
        switch kind {
        case .web:   return CGSize(width: 480, height: WatcherEditorView.contentHeight + Self.barHeight)
        case .email: return CGSize(width: 480, height: EmailWatcherEditorView.contentHeight + Self.barHeight)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $kind) {
                Text("Web page").tag(Kind.web)
                Text("Gmail sender").tag(Kind.email)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .frame(height: Self.barHeight - 1)

            Divider()
                .frame(height: 1)

            switch kind {
            case .web:
                WatcherEditorView(store: store, watcherService: watcherService, existingWatcher: nil)
            case .email:
                EmailWatcherEditorView(
                    existing: nil,
                    gmailStore: gmailStore,
                    emailWatcherStore: emailWatcherStore,
                    gmailPolling: gmailPolling,
                    onOpenSettings: onOpenSettings
                )
            }
        }
        .onAppear {
            onKindChange(Self.size(for: kind))
        }
        .onChange(of: kind) { newKind in
            onKindChange(Self.size(for: newKind))
        }
    }
}
