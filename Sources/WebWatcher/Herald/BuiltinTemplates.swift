// Vendored from ~/github/herald (Sources/HeraldClient/BuiltinTemplates.swift), keep in sync.

import Foundation

/// The four v1 layouts as grid templates (DESIGN 7.2: "the legacy v1 layouts become four built-in v2 grid
/// templates so every existing template keeps rendering"). They are generated in code, never stored:
/// `builtin.imageLeft`, `builtin.imageRight`, `builtin.hero` and `builtin.compact`.
///
/// Each reproduces its v1 structure with collapse doing what v1 did by hand: a banner without an image has
/// no image column, without a subtitle no subtitle row, without buttons no action row. Rows are one per v1
/// text line (title, subtitle, body) plus the action row, so the v1 styling of each line is kept; for that
/// reason the grids are 4 rows (hero 5, compact 2) by 4 columns rather than 3 x 4.
///
/// Spacing: the v1 meta column (close, app icon, time stacked beside the text) used to sit on the title,
/// subtitle and body rows, so each row was stretched to the height of its meta cell (+7 pt on the subtitle row
/// alone) and the card came out 6 to 13 pt taller than v1. Now the time sits beside the close button on the
/// title row, and the app icon spans the subtitle and body rows (a cell that spans rows only ever lends its
/// excess to the last of them, so it adds nothing to a banner whose text is taller than the icon). The grid
/// gap is 3.5 pt: v1 spaced its lines 2 to 3 pt apart and its action row 10 pt away, a single gap cannot be
/// both, so the action row carries the difference as an inset. That keeps the card within 2 pt of v1's
/// height for a banner with or without buttons, with or without an image (measured live, see BannerStackTests).
///
/// Differences from the v1 look: hero's image is inset by the card padding with rounded corners instead of
/// bleeding to the card edge, its close button sits in the title row instead of floating over the image, and a
/// title-only banner is no longer held open by the meta column (v1 left a 64 pt tall strip under a one-line title).
///
/// The image column exists only when there is an image to put in it (`hasImage`): the action row spans every
/// column, so a column kept alive by a collapsed image cell would push the whole text block right by the
/// image width. `named(...)` and `all(...)` are the static templates (always with the column); the
/// notification-driven `gridTemplate(for:)` that live banners use asks for the right one.
public enum BuiltinTemplates {
    public static let prefix = "builtin."

    /// `builtin.imageLeft`, `builtin.imageRight`, `builtin.hero`, `builtin.compact`.
    public static let names: [String] = HeraldLayout.allCases.map { name(for: $0) }

    public static func name(for layout: HeraldLayout) -> String { prefix + layout.rawValue }

    /// The layout a `builtin.*` name stands for; nil for any other name.
    public static func layout(forName name: String) -> HeraldLayout? {
        guard name.hasPrefix(prefix) else { return nil }
        return HeraldLayout(rawValue: String(name.dropFirst(prefix.count)))
    }

    public static func isBuiltin(_ name: String) -> Bool { layout(forName: name) != nil }

    /// The built-in template with this name, for `app` (empty by default); nil when the name is not one of the four.
    public static func named(_ name: String, app: String = "") -> HeraldTemplate? {
        layout(forName: name).map { template(layout: $0, app: app) }
    }

    /// All four, in `names` order.
    public static func all(app: String = "") -> [HeraldTemplate] {
        HeraldLayout.allCases.map { template(layout: $0, app: app) }
    }

    /// The grid template for a v1 look. The flags are the v1 template's: a hidden subtitle, body or timestamp
    /// has no cell, `maxBodyLines` limits the body, and `accentColor` colours the title as v1 did.
    public static func template(layout: HeraldLayout, app: String = "", accentColor: String? = nil,
                                showSubtitle: Bool = true, showBody: Bool = true, showTimestamp: Bool = true,
                                maxBodyLines: Int = HeraldTemplate.defaultMaxBodyLines,
                                hasImage: Bool = true) -> HeraldTemplate {
        let (grid, cells) = build(layout, accent: accentColor, showSubtitle: showSubtitle, showBody: showBody,
                                  showTimestamp: showTimestamp, maxBodyLines: maxBodyLines, hasImage: hasImage)
        var t = HeraldTemplate(name: name(for: layout), app: app, grid: grid, cells: cells)
        t.layout = layout
        t.accentColor = accentColor
        t.showSubtitle = showSubtitle; t.showBody = showBody; t.showTimestamp = showTimestamp
        t.maxBodyLines = maxBodyLines
        return t
    }

    /// A v1 template expressed as a grid: everything the template carries (content defaults, buttons, sound...)
    /// is kept and the grid of its `layout` is filled in. A template that already uses a grid is returned as is.
    public static func gridTemplate(for t: HeraldTemplate) -> HeraldTemplate {
        guard !t.usesGrid else { return t }
        let (grid, cells) = build(t.layout, accent: t.accentColor, showSubtitle: t.showSubtitle, showBody: t.showBody,
                                  showTimestamp: t.showTimestamp, maxBodyLines: t.maxBodyLines)
        var out = t
        out.layoutVersion = HeraldTemplate.currentLayoutVersion
        out.grid = grid; out.cells = cells; out.collapseEmpty = true
        return out
    }

    /// The grid for a notification that names no (grid) template: its own resolved v1 presentation fields
    /// (`layout`, `accentColor`, `showSubtitle`, ...) pick and tune the built-in. `hasImage` says whether the
    /// banner has a picture to show (a composer preview holds one the notification does not name); nil asks
    /// the notification, which has one when it names an image.
    public static func gridTemplate(for n: HeraldNotification, hasImage: Bool? = nil) -> HeraldTemplate {
        template(layout: n.layout ?? .imageLeft, app: n.app, accentColor: n.accentColor,
                 showSubtitle: n.showSubtitle ?? true, showBody: n.showBody ?? true,
                 showTimestamp: n.showTimestamp ?? true,
                 maxBodyLines: max(1, min(n.maxBodyLines ?? HeraldTemplate.defaultMaxBodyLines, 30)),
                 hasImage: hasImage ?? !(n.image ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: Building

    private static let width = 380.0
    /// v1 put its action row 10 pt under the text and its text lines 2 to 3 pt apart; the grid has one gap for
    /// both, so the action row carries the difference as an inset (1.5 pt on each side, which also keeps the
    /// card as tall as v1 when there is no action row).
    private static let actionsInset = 2.0

    private static func build(_ layout: HeraldLayout, accent: String?, showSubtitle: Bool, showBody: Bool,
                              showTimestamp: Bool, maxBodyLines: Int, hasImage: Bool = true) -> (HeraldGrid, [HeraldCell]) {
        let lines = max(1, min(maxBodyLines, 30))

        func title(size: Double? = nil, maxLines: Int = 2) -> HeraldComponent {
            .text(HeraldTextComponent(binding: "{title}", style: .title, maxLines: maxLines, color: validAccent(accent), fontSize: size))
        }
        let subtitle = HeraldComponent.text(HeraldTextComponent(binding: "{subtitle}", style: .subtitle, maxLines: 2))
        let body = HeraldComponent.text(HeraldTextComponent(binding: "{body}", style: .body, maxLines: lines, markdown: true))
        let image = HeraldComponent.image(HeraldImageComponent(binding: "{image}", fit: .cover, cornerRadius: 10, aspectRatio: 1))
        let heroImage = HeraldComponent.image(HeraldImageComponent(binding: "{image}", fit: .cover, cornerRadius: 10, aspectRatio: 16.0 / 9.0))
        let icon = HeraldComponent.issuerIcon(HeraldIssuerIconComponent(size: 22, cornerRadius: 5, shape: .rounded))
        let smallIcon = HeraldComponent.issuerIcon(HeraldIssuerIconComponent(size: 18, cornerRadius: 4, shape: .rounded))
        let time = HeraldComponent.timestamp(HeraldTimestampComponent(style: .caption, fontSize: 10))
        // 16 pt, not v1's 18: it sits on the title row, which is 16 pt (one line of 13 pt semibold), so a larger
        // button would stretch the row.
        let close = HeraldComponent.iconButton(HeraldIconButtonComponent(
            symbol: "xmark", action: HeraldAction(id: "dismiss", label: "Dismiss", kind: .dismiss, style: "cancel"),
            size: 16, tooltip: "Dismiss"))
        let compactClose = HeraldComponent.iconButton(HeraldIconButtonComponent(
            symbol: "xmark", action: HeraldAction(id: "dismiss", label: "Dismiss", kind: .dismiss, style: "cancel"),
            size: 18, tooltip: "Dismiss"))
        let actions = HeraldComponent.actions(HeraldActionsComponent(source: .merged, layout: .wrap))

        func cell(_ id: String, _ row: Int, _ col: Int, rows: Int = 1, cols: Int = 1,
                  align: HeraldAlign = .topLeading, padding: Double = 0, _ component: HeraldComponent) -> HeraldCell {
            HeraldCell(id: id, row: row, col: col, rowSpan: rows, colSpan: cols, align: align, padding: padding, component: component)
        }

        switch layout {
        case .imageLeft, .imageRight:
            // Columns (image on the left): image 72 | text | time | meta (close, icon). Rows: title (+ time and
            // close), subtitle, body, actions. The icon spans the subtitle and body rows, top right, under the
            // close button as in v1. The subtitle and body also run under the time column.
            // Without an image the first column is not there at all (see the header).
            let left = layout == .imageLeft
            let t = hasImage ? (left ? 1 : 0) : 0            // text column
            let timeCol = t + 1 + (hasImage && !left ? 1 : 0) // right of the image on the right-hand layout
            let metaCol = timeCol + 1
            let cols = metaCol + 1
            var cells = [
                cell("title", 0, t, title()),
                cell("close", 0, metaCol, align: .topTrailing, close),
                cell("icon", 1, metaCol, rows: 2, align: .topTrailing, icon),
                cell("actions", 3, 0, cols: cols, padding: actionsInset, actions),
            ]
            if hasImage { cells.append(cell("image", 0, left ? 0 : t + 1, rows: 3, align: .topLeading, image)) }
            // The text spans up to, not into, the image on the right-hand layout.
            let textSpan = (hasImage && !left) ? 1 : 2
            if showSubtitle { cells.append(cell("subtitle", 1, t, cols: textSpan, subtitle)) }
            if showBody { cells.append(cell("body", 2, t, cols: textSpan, body)) }
            if showTimestamp { cells.append(cell("time", 0, timeCol, align: .trailing, time)) }
            var sizes = [HeraldSize](repeating: .auto, count: cols)
            sizes[t] = .fill
            if hasImage { sizes[left ? 0 : t + 1] = .points(72) }
            return (HeraldGrid(rows: 4, cols: cols, rowSizes: Array(repeating: .auto, count: 4), colSizes: sizes,
                               gap: 3.5, padding: 12, width: width), ordered(cells))

        case .hero:
            // Rows: image, title (+ time, close), subtitle, body, actions. The icon spans the subtitle and body rows.
            var cells = [
                cell("image", 0, 0, cols: 4, heroImage),
                cell("title", 1, 0, cols: 2, title(size: 14)),
                cell("close", 1, 3, align: .topTrailing, close),
                cell("icon", 2, 3, rows: 2, align: .topTrailing, icon),
                cell("actions", 4, 0, cols: 4, padding: actionsInset, actions),
            ]
            if showSubtitle { cells.append(cell("subtitle", 2, 0, cols: 3, subtitle)) }
            if showBody { cells.append(cell("body", 3, 0, cols: 3, body)) }
            if showTimestamp { cells.append(cell("time", 1, 2, align: .trailing, time)) }
            return (HeraldGrid(rows: 5, cols: 4, rowSizes: Array(repeating: .auto, count: 5),
                               colSizes: [.fill, .fill, .auto, .auto], gap: 3.5, padding: 12, width: width), ordered(cells))

        case .compact:
            // One line: icon | title | time | close, then the actions. No image, subtitle or body, as in v1.
            var cells = [
                cell("icon", 0, 0, align: .center, smallIcon),
                cell("title", 0, 1, align: .leading, title(maxLines: 1)),
                cell("close", 0, 3, align: .center, compactClose),
                cell("actions", 1, 0, cols: 4, actions),
            ]
            if showTimestamp { cells.append(cell("time", 0, 2, align: .center, time)) }
            return (HeraldGrid(rows: 2, cols: 4, rowSizes: [.auto, .auto], colSizes: [.auto, .fill, .auto, .auto],
                               gap: 8, padding: 10, width: width), ordered(cells))
        }
    }

    /// Reading order (row, then column), so the cell list reads like the banner.
    private static func ordered(_ cells: [HeraldCell]) -> [HeraldCell] {
        cells.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
    }

    /// The accent only when it is a usable hex colour; v1 ignored a bad one the same way.
    private static func validAccent(_ s: String?) -> String? {
        guard let s, HeraldTemplate.isValidColor(s, allowKeywords: false) else { return nil }
        return s
    }
}
