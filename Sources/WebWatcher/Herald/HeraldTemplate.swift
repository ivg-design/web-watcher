import Foundation

/// How a v1 banner is arranged. One SwiftUI view renders all four (DESIGN section 6). In v2 each of these is
/// a built-in grid template (`BuiltinTemplates`), so a v1 template keeps rendering unchanged.
public enum HeraldLayout: String, Codable, CaseIterable, Sendable {
    /// Image thumbnail on the left, text on the right. The default.
    case imageLeft
    /// Same, mirrored.
    case imageRight
    /// Image across the top at 16:9, text underneath.
    case hero
    /// One line: app icon and title. No image.
    case compact
}

// MARK: - Grid

/// A row or column size (DESIGN 7.2). JSON: `"auto"`, `"fill"` or a number of points. A numeric string such as
/// `"72"` (or `"72pt"`) is accepted on decoding too.
public enum HeraldSize: Codable, Equatable, Hashable, Sendable {
    /// As large as its content.
    case auto
    /// Shares the space left over after fixed and auto tracks, equally with the other `fill` tracks.
    case fill
    /// A fixed size in points.
    case points(Double)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { self = .points(d); return }
        let raw = try c.decode(String.self)
        var s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        switch s {
        case "auto": self = .auto; return
        case "fill": self = .fill; return
        default: break
        }
        for suffix in ["pt", "px"] where s.hasSuffix(suffix) { s.removeLast(suffix.count) }
        if let d = Double(s.trimmingCharacters(in: .whitespaces)), d.isFinite { self = .points(d); return }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "size '\(raw)' must be \"auto\", \"fill\" or a number of points")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .auto: try c.encode("auto")
        case .fill: try c.encode("fill")
        case .points(let d): try c.encode(d)
        }
    }
}

/// The grid a v2 template lays its cells on.
public struct HeraldGrid: Codable, Equatable, Sendable {
    public var rows: Int
    public var cols: Int
    /// One entry per row (`rows` of them).
    public var rowSizes: [HeraldSize]
    /// One entry per column (`cols` of them).
    public var colSizes: [HeraldSize]
    /// Space between tracks, points.
    public var gap: Double
    /// Space between the banner edge and the tracks, points.
    public var padding: Double
    /// Banner width, points.
    public var width: Double

    /// The designer's starting grid (DESIGN 7.2): 3 rows by 4 columns, a 72 pt image column and a 56 pt meta column.
    public static let standard = HeraldGrid(
        rows: 3, cols: 4, rowSizes: [.auto, .auto, .auto],
        colSizes: [.points(72), .fill, .fill, .points(56)], gap: 8, padding: 14, width: 400)

    public init(rows: Int = 3, cols: Int = 4, rowSizes: [HeraldSize]? = nil, colSizes: [HeraldSize]? = nil,
                gap: Double = 8, padding: Double = 14, width: Double = 400) {
        self.rows = rows; self.cols = cols
        self.rowSizes = rowSizes ?? Array(repeating: .auto, count: max(rows, 0))
        self.colSizes = colSizes ?? Array(repeating: .fill, count: max(cols, 0))
        self.gap = gap; self.padding = padding; self.width = width
    }

    /// The size of a row; `.auto` when the list is shorter than the grid, so a short list cannot crash a renderer.
    public func rowSize(at index: Int) -> HeraldSize { rowSizes.indices.contains(index) ? rowSizes[index] : .auto }
    /// The size of a column; `.fill` when the list is shorter than the grid.
    public func colSize(at index: Int) -> HeraldSize { colSizes.indices.contains(index) ? colSizes[index] : .fill }

    private enum CodingKeys: String, CodingKey { case rows, cols, rowSizes, colSizes, gap, padding, width }

    /// Everything is optional: rows and columns default to the length of their size list (else 3 and 4), sizes
    /// to `auto` rows and `fill` columns, gap 8, padding 14, width 400.
    ///
    /// The track counts are checked here, before the memberwise init allocates one size per track: a request
    /// body of `{"rows":40000000}` must not be able to ask for hundreds of megabytes while it is being decoded.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let maxT = HeraldTemplate.maxGridTracks
        let rowSizes = try c.decodeIfPresent([HeraldSize].self, forKey: .rowSizes)
        let colSizes = try c.decodeIfPresent([HeraldSize].self, forKey: .colSizes)
        let rows = try c.decodeIfPresent(Int.self, forKey: .rows) ?? rowSizes?.count ?? 3
        let cols = try c.decodeIfPresent(Int.self, forKey: .cols) ?? colSizes?.count ?? 4
        for (key, n) in [(CodingKeys.rows, rows), (.cols, cols), (.rowSizes, rowSizes?.count ?? 1), (.colSizes, colSizes?.count ?? 1)]
        where !(1...maxT).contains(n) {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: c, debugDescription: "\(key.stringValue) must have 1 to \(maxT) tracks")
        }
        self.init(rows: rows, cols: cols, rowSizes: rowSizes, colSizes: colSizes,
                  gap: try c.decodeIfPresent(Double.self, forKey: .gap) ?? 8,
                  padding: try c.decodeIfPresent(Double.self, forKey: .padding) ?? 14,
                  width: try c.decodeIfPresent(Double.self, forKey: .width) ?? 400)
    }
}

/// Where a component sits inside its cell.
public enum HeraldAlign: String, Codable, CaseIterable, Sendable {
    case topLeading, top, topTrailing, leading, center, trailing, bottomLeading, bottom, bottomTrailing

    public enum Horizontal: String, Sendable { case leading, center, trailing }
    public enum Vertical: String, Sendable { case top, center, bottom }

    public var horizontal: Horizontal {
        switch self {
        case .topLeading, .leading, .bottomLeading: return .leading
        case .top, .center, .bottom: return .center
        case .topTrailing, .trailing, .bottomTrailing: return .trailing
        }
    }

    public var vertical: Vertical {
        switch self {
        case .topLeading, .top, .topTrailing: return .top
        case .leading, .center, .trailing: return .center
        case .bottomLeading, .bottom, .bottomTrailing: return .bottom
        }
    }
}

/// One cell: a rectangle of grid tracks holding one component.
public struct HeraldCell: Codable, Equatable, Identifiable, Sendable {
    /// Unique within the template; validation errors name it.
    public var id: String
    /// 0-based first row and column.
    public var row: Int
    public var col: Int
    public var rowSpan: Int
    public var colSpan: Int
    public var align: HeraldAlign
    /// Inset around the component, points.
    public var padding: Double
    public var component: HeraldComponent

    public init(id: String, row: Int, col: Int, rowSpan: Int = 1, colSpan: Int = 1,
                align: HeraldAlign = .topLeading, padding: Double = 0, component: HeraldComponent) {
        self.id = id; self.row = row; self.col = col; self.rowSpan = rowSpan; self.colSpan = colSpan
        self.align = align; self.padding = padding; self.component = component
    }

    /// Rows this cell covers, clipped to a grid of `rows` rows.
    public func rowRange(in rows: Int) -> Range<Int> { Self.clip(row, rowSpan, rows) }
    /// Columns this cell covers, clipped to a grid of `cols` columns.
    public func colRange(in cols: Int) -> Range<Int> { Self.clip(col, colSpan, cols) }

    private static func clip(_ start: Int, _ span: Int, _ limit: Int) -> Range<Int> {
        let lo = min(max(start, 0), max(limit, 0))
        let hi = min(max(start + max(span, 1), lo), max(limit, 0))
        return lo..<hi
    }

    private enum CodingKeys: String, CodingKey { case id, row, col, rowSpan, colSpan, align, padding, component }

    /// `row`, `col` and `component` are required; spans default to 1, `align` to topLeading, `padding` to 0
    /// and `id` to "r<row>c<col>".
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let row = try c.decode(Int.self, forKey: .row)
        let col = try c.decode(Int.self, forKey: .col)
        self.init(id: try c.decodeIfPresent(String.self, forKey: .id) ?? "r\(row)c\(col)", row: row, col: col,
                  rowSpan: try c.decodeIfPresent(Int.self, forKey: .rowSpan) ?? 1,
                  colSpan: try c.decodeIfPresent(Int.self, forKey: .colSpan) ?? 1,
                  align: try c.decodeIfPresent(HeraldAlign.self, forKey: .align) ?? .topLeading,
                  padding: try c.decodeIfPresent(Double.self, forKey: .padding) ?? 0,
                  component: try c.decode(HeraldComponent.self, forKey: .component))
    }
}

// MARK: - Template

/// A reusable banner look plus default content, stored per app and referenced from a notification
/// as `"template": "<name>"`. Everything except `name` and `app` is optional on the wire, so a
/// hand-written file or a minimal PUT body decodes; `TemplateResolver` merges it with a payload.
///
/// Two generations share the type. `layoutVersion` 1 (the default when there is no `grid`) is the v1 look:
/// one of four `layout`s plus the `show*` flags. `layoutVersion` 2 is a grid of `cells`, each holding a
/// component bound to fields with `{token}` placeholders (DESIGN section 7). Both carry the default content
/// (title, buttons, sound...), `actionRules` and `extra`.
public struct HeraldTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: String { app + "/" + name }
    public var name: String
    public var app: String
    public var layout: HeraldLayout
    /// Hex colour such as `#34C759`; nil keeps the system accent.
    public var accentColor: String?
    public var showSubtitle: Bool
    public var showBody: Bool
    public var showTimestamp: Bool
    public var maxBodyLines: Int

    // Default content. `title`, `subtitle`, `body` and `url` may contain `{placeholder}` tokens.
    public var title: String?
    public var subtitle: String?
    public var body: String?
    public var image: String?
    public var url: String?
    /// Default button set, used when the payload sends no `buttons`.
    public var buttons: [HeraldButton]
    public var sound: String?
    public var persistent: Bool?
    public var timeout: Double?
    public var snooze: Bool?
    public var priority: String?
    public var reminder: HeraldReminder?

    // v2 (DESIGN section 7).
    /// 1 = one of the four v1 layouts, 2 = grid. Absent on the wire means 2 when there is a `grid`, else 1.
    public var layoutVersion: Int
    public var grid: HeraldGrid?
    public var cells: [HeraldCell]
    /// Template default for components that set no `emptyBehavior`: true collapses a component whose bindings
    /// are all absent (and a row or column left empty), false keeps its space.
    public var collapseEmpty: Bool
    /// Rules over the issuer's actions: hide, relabel, restyle, reorder, add.
    public var actionRules: [HeraldActionRule]
    /// Key/values the user authored; every action receives them (as `extra`) and bindings read them as
    /// `{extra.key}`.
    public var extra: [String: String]

    /// Line limit the pre-template banner used, so an untemplated look and a bare template match.
    public static let defaultMaxBodyLines = 8
    public static let currentLayoutVersion = 2

    public init(name: String, app: String, layout: HeraldLayout = .imageLeft) {
        self.name = name; self.app = app; self.layout = layout
        self.accentColor = nil
        self.showSubtitle = true; self.showBody = true; self.showTimestamp = true
        self.maxBodyLines = Self.defaultMaxBodyLines
        self.title = nil; self.subtitle = nil; self.body = nil; self.image = nil; self.url = nil
        self.buttons = []
        self.sound = nil; self.persistent = nil; self.timeout = nil; self.snooze = nil
        self.priority = nil; self.reminder = nil
        self.layoutVersion = 1; self.grid = nil; self.cells = []; self.collapseEmpty = true
        self.actionRules = []; self.extra = [:]
    }

    /// A v2 grid template.
    public init(name: String, app: String, grid: HeraldGrid, cells: [HeraldCell] = [],
                collapseEmpty: Bool = true, actionRules: [HeraldActionRule] = [], extra: [String: String] = [:]) {
        self.init(name: name, app: app)
        self.layoutVersion = Self.currentLayoutVersion
        self.grid = grid; self.cells = cells; self.collapseEmpty = collapseEmpty
        self.actionRules = actionRules; self.extra = extra
    }

    /// A new, empty v2 template on the standard 3 x 4 grid.
    public static func blank(name: String, app: String) -> HeraldTemplate {
        HeraldTemplate(name: name, app: app, grid: .standard)
    }

    /// True when the template is drawn from its grid (v2 with a grid); false for a v1 look.
    public var usesGrid: Bool { layoutVersion >= 2 && grid != nil }

    public func cell(withID id: String) -> HeraldCell? { cells.first { $0.id == id } }

    /// Every distinct field token the cells read, in cell order.
    public var referencedTokens: [String] {
        var seen: [String] = []
        for c in cells { for t in c.component.referencedTokens where !seen.contains(t) { seen.append(t) } }
        return seen
    }

    // `id` is derived, so the coding keys list the stored properties only. Decoding is written out
    // (instead of synthesized) because synthesis would demand every non-optional key; here a
    // template like {"name":"n","app":"a"} must decode with the documented defaults.
    private enum CodingKeys: String, CodingKey {
        case name, app, layout, accentColor, showSubtitle, showBody, showTimestamp, maxBodyLines
        case title, subtitle, body, image, url, buttons, sound, persistent, timeout, snooze
        case priority, reminder
        case layoutVersion, grid, cells, collapseEmpty, actionRules, extra
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try c.decode(String.self, forKey: .name),
                  app: try c.decode(String.self, forKey: .app),
                  layout: try c.decodeIfPresent(HeraldLayout.self, forKey: .layout) ?? .imageLeft)
        accentColor = try c.decodeIfPresent(String.self, forKey: .accentColor)
        showSubtitle = try c.decodeIfPresent(Bool.self, forKey: .showSubtitle) ?? true
        showBody = try c.decodeIfPresent(Bool.self, forKey: .showBody) ?? true
        showTimestamp = try c.decodeIfPresent(Bool.self, forKey: .showTimestamp) ?? true
        maxBodyLines = try c.decodeIfPresent(Int.self, forKey: .maxBodyLines) ?? Self.defaultMaxBodyLines
        title = try c.decodeIfPresent(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        url = try c.decodeIfPresent(String.self, forKey: .url)
        buttons = try c.decodeIfPresent([HeraldButton].self, forKey: .buttons) ?? []
        sound = try c.decodeIfPresent(String.self, forKey: .sound)
        persistent = try c.decodeIfPresent(Bool.self, forKey: .persistent)
        timeout = try c.decodeIfPresent(Double.self, forKey: .timeout)
        snooze = try c.decodeIfPresent(Bool.self, forKey: .snooze)
        priority = try c.decodeIfPresent(String.self, forKey: .priority)
        reminder = try c.decodeIfPresent(HeraldReminder.self, forKey: .reminder)
        grid = try c.decodeIfPresent(HeraldGrid.self, forKey: .grid)
        cells = try c.decodeIfPresent([HeraldCell].self, forKey: .cells) ?? []
        layoutVersion = try c.decodeIfPresent(Int.self, forKey: .layoutVersion) ?? (grid != nil ? Self.currentLayoutVersion : 1)
        collapseEmpty = try c.decodeIfPresent(Bool.self, forKey: .collapseEmpty) ?? true
        actionRules = try c.decodeIfPresent([HeraldActionRule].self, forKey: .actionRules) ?? []
        extra = try c.decodeIfPresent([String: String].self, forKey: .extra) ?? [:]
    }

    /// Writes only what is set: a v1 template stays as short as it was (plus `layoutVersion`), and a v2 one
    /// lists its grid and cells.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(app, forKey: .app)
        try c.encode(layout, forKey: .layout)
        try c.encodeIfPresent(accentColor, forKey: .accentColor)
        try c.encode(showSubtitle, forKey: .showSubtitle)
        try c.encode(showBody, forKey: .showBody)
        try c.encode(showTimestamp, forKey: .showTimestamp)
        try c.encode(maxBodyLines, forKey: .maxBodyLines)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(subtitle, forKey: .subtitle)
        try c.encodeIfPresent(body, forKey: .body)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encode(buttons, forKey: .buttons)
        try c.encodeIfPresent(sound, forKey: .sound)
        try c.encodeIfPresent(persistent, forKey: .persistent)
        try c.encodeIfPresent(timeout, forKey: .timeout)
        try c.encodeIfPresent(snooze, forKey: .snooze)
        try c.encodeIfPresent(priority, forKey: .priority)
        try c.encodeIfPresent(reminder, forKey: .reminder)
        try c.encode(layoutVersion, forKey: .layoutVersion)
        try c.encodeIfPresent(grid, forKey: .grid)
        if grid != nil || !cells.isEmpty { try c.encode(cells, forKey: .cells) }
        try c.encode(collapseEmpty, forKey: .collapseEmpty)
        if !actionRules.isEmpty { try c.encode(actionRules, forKey: .actionRules) }
        if !extra.isEmpty { try c.encode(extra, forKey: .extra) }
    }
}

// MARK: - Collapsing empty components

/// Which cells, rows and columns of a grid collapse for one notification (DESIGN 7.2).
public struct HeraldGridPlan: Equatable, Sendable {
    /// Ids of empty cells whose behaviour is `collapse`: not drawn at all.
    public var collapsedCells: Set<String>
    /// Rows and columns with nothing left in them: zero size, and no gap is added for them.
    public var collapsedRows: Set<Int>
    public var collapsedCols: Set<Int>

    public init(collapsedCells: Set<String> = [], collapsedRows: Set<Int> = [], collapsedCols: Set<Int> = []) {
        self.collapsedCells = collapsedCells; self.collapsedRows = collapsedRows; self.collapsedCols = collapsedCols
    }

    public func isCollapsed(cell id: String) -> Bool { collapsedCells.contains(id) }
}

public extension HeraldTemplate {
    /// What an empty component does: its own `emptyBehavior`, else the template's `collapseEmpty`.
    func behavior(for component: HeraldComponent) -> HeraldEmptyBehavior {
        component.emptyBehavior ?? (collapseEmpty ? .collapse : .keep)
    }

    /// Ids of the cells whose component has nothing to show (`HeraldComponent.hasContent`).
    func emptyCellIDs(fields: [String: HeraldFieldValue], actions: [HeraldResolvedAction]) -> Set<String> {
        Set(cells.filter { !$0.component.hasContent(fields: fields, actions: actions) }.map(\.id))
    }

    /// The collapse plan for one notification. `emptyCells` are the ids of cells with nothing to show.
    ///
    /// - An empty cell whose behaviour is `collapse` is not drawn; one whose behaviour is `keep` is drawn
    ///   blank and keeps the rows and columns it covers alive.
    /// - A row (column) collapses when every cell on it, a cell spanning it included, is collapsed: it gets
    ///   zero size and no gap.
    /// - A row (column) no cell touches at all collapses only when the template's `collapseEmpty` is on.
    ///
    /// A v1 template (no grid) has nothing to collapse.
    func plan(emptyCells: Set<String>) -> HeraldGridPlan {
        guard let g = grid else { return HeraldGridPlan() }
        let collapsed = Set(cells.filter { emptyCells.contains($0.id) && behavior(for: $0.component) == .collapse }.map(\.id))
        let live = cells.filter { !collapsed.contains($0.id) }

        func collapsedTracks(count: Int, range: (HeraldCell) -> Range<Int>) -> Set<Int> {
            var alive = Set<Int>(), touched = Set<Int>()
            for c in live { alive.formUnion(range(c)) }
            for c in cells { touched.formUnion(range(c)) }
            return Set((0..<max(count, 0)).filter { !alive.contains($0) && (touched.contains($0) || collapseEmpty) })
        }

        return HeraldGridPlan(
            collapsedCells: collapsed,
            collapsedRows: collapsedTracks(count: g.rows) { $0.rowRange(in: g.rows) },
            collapsedCols: collapsedTracks(count: g.cols) { $0.colRange(in: g.cols) })
    }

    /// Same, working out the empty cells from the resolved fields and actions.
    func plan(fields: [String: HeraldFieldValue], actions: [HeraldResolvedAction]) -> HeraldGridPlan {
        plan(emptyCells: emptyCellIDs(fields: fields, actions: actions))
    }
}

// MARK: - Validation

/// One problem found in a template. `path` locates it (`cells[2].component.binding`) and `cellId` names the
/// cell, so an agent can fix exactly that cell.
public struct HeraldTemplateIssue: Codable, Equatable, Sendable {
    public enum Severity: String, Codable, Sendable { case error, warning }
    public var severity: Severity
    public var path: String
    public var cellId: String?
    public var message: String
    public var isError: Bool { severity == .error }

    public init(severity: Severity, path: String, cellId: String? = nil, message: String) {
        self.severity = severity; self.path = path; self.cellId = cellId; self.message = message
    }
}

public extension HeraldTemplate {
    static let maxGridTracks = 12
    static let widthRange: ClosedRange<Double> = 160...800
    static let maxCells = 100

    /// Checks the template against the grid schema (DESIGN 7.6). Errors make the template unusable or
    /// ambiguous; warnings are likely mistakes (a token the manifest does not declare). With a `manifest`,
    /// tokens and Rive assets are checked against it too.
    func validate(manifest: HeraldManifest? = nil) -> [HeraldTemplateIssue] {
        var issues: [HeraldTemplateIssue] = []
        func err(_ path: String, _ msg: String, cell: String? = nil) {
            issues.append(.init(severity: .error, path: path, cellId: cell, message: msg))
        }
        func warn(_ path: String, _ msg: String, cell: String? = nil) {
            issues.append(.init(severity: .warning, path: path, cellId: cell, message: msg))
        }

        if name.trimmingCharacters(in: .whitespaces).isEmpty { err("name", "name is required") }
        if app.trimmingCharacters(in: .whitespaces).isEmpty { err("app", "app is required") }
        if let c = accentColor, !Self.isValidColor(c, allowKeywords: false) {
            err("accentColor", "'\(c)' is not a hex colour (#RGB, #RRGGBB or #RRGGBBAA)")
        }
        for (k, _) in extra where k.isEmpty || !HeraldManifest.isToken(k) {
            warn("extra.\(k)", "extra key '\(k)' cannot be read as {extra.\(k)}: use letters, digits, '_', '.' or '-'")
        }
        // The template's default buttons are the template author's code, not the issuer's: Herald confirms a
        // command here once per template, and says so rather than letting it look like the issuer's button.
        for (i, b) in buttons.enumerated() where !(b.command ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warn("buttons[\(i)].command", "a default button that runs a shell command is the template's own code: the user is asked to confirm it once, and again when it changes. Prefer an actionRules 'add' so it is visible as an action.")
        }
        let templateActionIDs = actionRules.compactMap { $0.add?.id }
        var knownTokens = Set(TemplateResolver.standardTokens)
        if let m = manifest { knownTokens.formUnion(m.fields.map(\.key)) }

        // Action rules.
        for (i, r) in actionRules.enumerated() {
            let p = "actionRules[\(i)]"
            let hasMatch = !(r.match ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            if !hasMatch && r.add == nil { err(p, "a rule needs a 'match' or an 'add'") }
            if hasMatch && r.hide != true && r.relabel == nil && r.style == nil && r.position == nil && r.add == nil && r.symbol == nil {
                warn(p, "the rule matches '\(r.match ?? "")' but changes nothing (set hide, relabel, style, symbol, position or add)")
            }
            if r.hide == true && (r.relabel != nil || r.style != nil || r.position != nil) {
                warn(p, "hide: true removes the action, so relabel, style and position have no effect")
            }
            if let pos = r.position, pos < 0 { err("\(p).position", "position must be 0 or greater") }
            if let s = r.style, !s.isEmpty, !Self.actionStyles.contains(s) {
                err("\(p).style", "style '\(s)' must be default, destructive or cancel")
            }
            if let a = r.add { Self.validateAction(a, path: "\(p).add", cell: nil, into: &issues) }
            if let sym = r.symbol {
                for pr in sym.problems() { issues.append(.init(severity: pr.isError ? .error : .warning, path: "\(p).symbol.\(pr.key)", message: pr.message)) }
            }
        }

        if layoutVersion != 1 && layoutVersion != Self.currentLayoutVersion {
            err("layoutVersion", "unsupported layoutVersion \(layoutVersion) (1 or \(Self.currentLayoutVersion))")
            return issues
        }
        if layoutVersion == 1 {
            if grid != nil || !cells.isEmpty {
                warn("layoutVersion", "grid and cells are ignored while layoutVersion is 1; set layoutVersion to 2 to use them")
            }
            return issues
        }
        guard let g = grid else {
            err("grid", "layoutVersion 2 needs a grid")
            return issues
        }

        // Grid.
        let maxT = Self.maxGridTracks
        if !(1...maxT).contains(g.rows) { err("grid.rows", "rows must be 1 to \(maxT)") }
        if !(1...maxT).contains(g.cols) { err("grid.cols", "cols must be 1 to \(maxT)") }
        if g.rowSizes.count != g.rows { err("grid.rowSizes", "rowSizes has \(g.rowSizes.count) entries but rows is \(g.rows)") }
        if g.colSizes.count != g.cols { err("grid.colSizes", "colSizes has \(g.colSizes.count) entries but cols is \(g.cols)") }
        for (key, sizes) in [("rowSizes", g.rowSizes), ("colSizes", g.colSizes)] {
            for (i, s) in sizes.enumerated() {
                if case .points(let d) = s, d < 0 || d > 4000 { err("grid.\(key)[\(i)]", "a size in points must be 0 to 4000") }
            }
        }
        if g.gap < 0 || g.gap > 64 { err("grid.gap", "gap must be 0 to 64") }
        if g.padding < 0 || g.padding > 64 { err("grid.padding", "padding must be 0 to 64") }
        if !Self.widthRange.contains(g.width) {
            err("grid.width", "width must be \(Int(Self.widthRange.lowerBound)) to \(Int(Self.widthRange.upperBound)) points")
        }
        if cells.count > Self.maxCells { err("cells", "too many cells (at most \(Self.maxCells))") }

        // Cells.
        var seen = Set<String>()
        var owner: [Int: String] = [:]
        var reportedOverlaps = Set<String>()
        for (i, c) in cells.prefix(Self.maxCells).enumerated() {
            let p = "cells[\(i)]"
            let cid: String? = c.id.isEmpty ? nil : c.id
            if c.id.isEmpty { err("\(p).id", "a cell needs an id") }
            else if !seen.insert(c.id).inserted { err("\(p).id", "cell id '\(c.id)' is used twice", cell: c.id) }

            var inBounds = true
            if c.row < 0 || c.col < 0 { err(p, "row and col start at 0", cell: cid); inBounds = false }
            if c.rowSpan < 1 || c.colSpan < 1 { err(p, "rowSpan and colSpan must be at least 1", cell: cid); inBounds = false }
            if inBounds && (c.row + c.rowSpan > g.rows || c.col + c.colSpan > g.cols) {
                err(p, "cell '\(c.id)' (row \(c.row), col \(c.col), \(c.rowSpan) x \(c.colSpan)) does not fit the \(g.rows) x \(g.cols) grid", cell: cid)
                inBounds = false
            }
            if c.padding < 0 || c.padding > 64 { err("\(p).padding", "padding must be 0 to 64", cell: cid) }

            if inBounds {
                for r in c.row..<(c.row + c.rowSpan) {
                    for col in c.col..<(c.col + c.colSpan) {
                        let key = r * 1000 + col
                        if let other = owner[key] {
                            let pair = [other, c.id].sorted().joined(separator: "|")
                            if reportedOverlaps.insert(pair).inserted {
                                err(p, "cell '\(c.id)' overlaps cell '\(other)' at row \(r), col \(col)", cell: cid)
                            }
                        } else {
                            owner[key] = c.id
                        }
                    }
                }
            }
            Self.validateComponent(c.component, path: "\(p).component", cell: cid, manifest: manifest,
                                   knownTokens: knownTokens, extraKeys: Set(extra.keys),
                                   templateActionIDs: templateActionIDs, into: &issues)
        }
        return issues
    }

    /// True when `validate` finds no errors.
    func isValid(manifest: HeraldManifest? = nil) -> Bool { !validate(manifest: manifest).contains { $0.isError } }

    private static let actionStyles = ["default", "destructive", "cancel"]
    private static let colorKeywords = ["accent", "primary", "secondary"]

    /// `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`, or (when allowed) `accent` / `primary` / `secondary`.
    static func isValidColor(_ s: String, allowKeywords: Bool = true) -> Bool {
        if allowKeywords, colorKeywords.contains(s) { return true }
        guard s.hasPrefix("#") else { return false }
        let hex = s.dropFirst()
        return [3, 4, 6, 8].contains(hex.count) && hex.allSatisfy { $0.isHexDigit }
    }

    private static func validateAction(_ a: HeraldAction, path p: String, cell: String?, into issues: inout [HeraldTemplateIssue]) {
        func err(_ path: String, _ msg: String) { issues.append(.init(severity: .error, path: path, cellId: cell, message: msg)) }
        func blank(_ s: String?) -> Bool { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if a.label.trimmingCharacters(in: .whitespaces).isEmpty { err("\(p).label", "an action needs a label") }
        if a.id.trimmingCharacters(in: .whitespaces).isEmpty { err("\(p).id", "an action needs an id") }
        if let s = a.style, !actionStyles.contains(s) { err("\(p).style", "style '\(s)' must be default, destructive or cancel") }
        if let sym = a.symbol {
            for pr in sym.problems() { issues.append(.init(severity: pr.isError ? .error : .warning, path: "\(p).symbol.\(pr.key)", cellId: cell, message: pr.message)) }
        }
        switch a.kind {
        case .url:
            if blank(a.url) { err("\(p).url", "a url action needs a url") }
            else if let u = a.url, !u.contains("{"), !["http://", "https://", "mailto:"].contains(where: { u.lowercased().hasPrefix($0) }) {
                err("\(p).url", "only http, https and mailto URLs can be opened")
            }
        case .command:
            if blank(a.command) { err("\(p).command", "a command action needs a command") }
        case .script:
            if blank(a.script) { err("\(p).script", "a script action needs the name of a file in Herald's scripts folder") }
            else if let s = a.script, s.contains("/") || s.contains("..") {
                err("\(p).script", "script must be a plain file name in Herald's scripts folder, not a path")
            }
        case .shortcut:
            if blank(a.shortcut) { err("\(p).shortcut", "a shortcut action needs the name of an installed Shortcut (list_shortcuts)") }
        case .snooze:
            if let m = a.snoozeMinutes, !(1...10080).contains(m) { err("\(p).snoozeMinutes", "snoozeMinutes must be 1 to 10080") }
        case .callback, .dismiss:
            break
        }
    }

    private static func validateComponent(_ comp: HeraldComponent, path p: String, cell: String?, manifest: HeraldManifest?,
                                          knownTokens: Set<String>, extraKeys: Set<String>, templateActionIDs: [String],
                                          into issues: inout [HeraldTemplateIssue]) {
        func err(_ path: String, _ msg: String) { issues.append(.init(severity: .error, path: path, cellId: cell, message: msg)) }
        func warn(_ path: String, _ msg: String) { issues.append(.init(severity: .warning, path: path, cellId: cell, message: msg)) }
        func blank(_ s: String?) -> Bool { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        func color(_ key: String, _ v: String?, keywords: Bool = true) {
            if let v, !isValidColor(v, allowKeywords: keywords) {
                err("\(p).\(key)", "'\(v)' is not a colour (#RGB, #RRGGBB, #RRGGBBAA\(keywords ? ", accent, primary or secondary" : ""))")
            }
        }
        func binding(_ key: String, _ v: String) {
            if blank(v) { err("\(p).\(key)", "a binding is required, for example \"{title}\"") }
        }
        func positive(_ key: String, _ v: Double?) {
            if let v, !(v > 0) { err("\(p).\(key)", "\(key) must be greater than 0") }
        }

        switch comp {
        case .text(let t):
            binding("binding", t.binding)
            if let m = t.maxLines, m < 1 { err("\(p).maxLines", "maxLines must be at least 1") }
            if let f = t.fontSize, !(6...72).contains(f) { err("\(p).fontSize", "fontSize must be 6 to 72") }
            color("color", t.color)
        case .image(let i):
            binding("binding", i.binding)
            positive("aspectRatio", i.aspectRatio); positive("height", i.height)
            if i.cornerRadius < 0 { err("\(p).cornerRadius", "cornerRadius must be 0 or greater") }
        case .issuerIcon(let i):
            if !(8...128).contains(i.size) { err("\(p).size", "size must be 8 to 128") }
            if let r = i.cornerRadius, r < 0 { err("\(p).cornerRadius", "cornerRadius must be 0 or greater") }
        case .timestamp(let t):
            color("color", t.color)
            if let f = t.fontSize, !(6...72).contains(f) { err("\(p).fontSize", "fontSize must be 6 to 72") }
        case .button(let b):
            if b.action == nil && blank(b.actionRef) { err(p, "a button needs an inline 'action' or an 'actionRef'") }
            if let a = b.action { validateAction(a, path: "\(p).action", cell: cell, into: &issues) }
            if let s = b.style, !actionStyles.contains(s) { err("\(p).style", "style '\(s)' must be default, destructive or cancel") }
        case .actions(let a):
            if let m = a.maxVisible, m < 1 { err("\(p).maxVisible", "maxVisible must be at least 1") }
        case .iconButton(let b):
            if blank(b.symbol) { err("\(p).symbol", "an iconButton needs an SF Symbol name, for example \"xmark\"") }
            if b.action == nil && blank(b.actionRef) { err(p, "an iconButton needs an inline 'action' or an 'actionRef'") }
            if let a = b.action { validateAction(a, path: "\(p).action", cell: cell, into: &issues) }
            color("color", b.color)
        case .badge(let b):
            binding("binding", b.binding)
            color("color", b.color); color("textColor", b.textColor)
        case .stackBadge(let b):
            color("color", b.color); color("textColor", b.textColor)
        case .progress(let b):
            binding("binding", b.binding)
            color("color", b.color); positive("height", b.height)
        case .rive(let r):
            if blank(r.asset) && blank(r.path) { err(p, "a rive component needs an 'asset' (from the manifest) or a 'path'") }
            positive("aspectRatio", r.aspectRatio); positive("height", r.height)
            if let a = r.action { validateAction(a, path: "\(p).action", cell: cell, into: &issues) }
            if let m = manifest, let id = r.asset, !id.isEmpty {
                if let asset = m.assets.first(where: { $0.id == id }) {
                    if let inputs = asset.inputs {
                        for name in r.inputBindings.keys.sorted() where !inputs.contains(name) {
                            warn("\(p).inputBindings.\(name)", "asset '\(id)' declares no input '\(name)' (inputs: \(inputs.joined(separator: ", ")))")
                        }
                    }
                } else {
                    warn("\(p).asset", "the manifest declares no asset '\(id)'")
                }
            }
            for (name, b) in r.inputBindings.sorted(by: { $0.key < $1.key }) where blank(b) {
                err("\(p).inputBindings.\(name)", "an input binding is a {token} or hover / pressed")
            }
        case .spacer:
            break
        }

        for (i, sym) in comp.symbols.enumerated() {
            for pr in sym.problems() {
                let key = comp.symbols.count > 1 ? "symbol[\(i)].\(pr.key)" : "symbol.\(pr.key)"
                if pr.isError { err("\(p).\(key)", pr.message) } else { warn("\(p).\(key)", pr.message) }
            }
        }
        // An actionRef must point at something that can exist.
        if let ref = comp.actionRef, !ref.isEmpty, let m = manifest {
            let declared = Set((0..<m.actions.count).map { m.actionID(at: $0) })
            if !declared.contains(ref) && !templateActionIDs.contains(ref) {
                warn("\(p).actionRef", "no manifest action or template-added action has the id '\(ref)'")
            }
        }
        // Tokens the manifest does not know are probably typos (they may still arrive in `metadata`).
        if manifest != nil {
            for t in comp.referencedTokens where !knownTokens.contains(t) && !t.hasPrefix("extra.") {
                warn(p, "token {\(t)} is not declared in the manifest (it only resolves if the issuer sends it)")
            }
        }
        for t in comp.referencedTokens where t.hasPrefix("extra.") && !extraKeys.contains(String(t.dropFirst(6))) {
            warn(p, "token {\(t)} has no matching key in the template's extra")
        }
    }
}

/// Merges a notification with the template it names (DESIGN section 6).
///
/// Precedence, per field: the payload wins, the template fills what the payload left out. For
/// `title` (a non-optional String on the wire) "left out" means empty. For `buttons` an explicit
/// empty array from the payload is a deliberate "no buttons" and wins over the template's set.
///
/// `{placeholder}` tokens are filled only in text that came from the template (a payload's own
/// text is the sender's literal and may legitimately contain braces). Values come from `metadata`
/// first (strings, plus numbers and booleans, which senders put there constantly; a dotted name
/// such as `{customer.name}` walks nested objects), then from the payload's own `title`,
/// `subtitle`, `body`, `app` and `id`. An unknown token becomes empty. Substituted text is never
/// rescanned, so a metadata value containing `{x}` stays as typed.
public enum TemplateResolver {
    public static func resolve(_ n: HeraldNotification, with t: HeraldTemplate?) -> HeraldNotification {
        guard let t else { return n }
        var out = n
        let values = Values(n)

        if n.title.isEmpty, let v = t.title { out.title = fill(v, values) }
        if n.subtitle == nil, let v = t.subtitle { out.subtitle = fill(v, values) }
        if n.body == nil, let v = t.body { out.body = fill(v, values) }
        if n.url == nil, let v = t.url { out.url = fill(v, values, urlSafe: true) }
        if n.image == nil { out.image = t.image }
        if n.buttons == nil, !t.buttons.isEmpty { out.buttons = t.buttons }
        if n.sound == nil { out.sound = t.sound }
        if n.persistent == nil { out.persistent = t.persistent }
        if n.timeout == nil { out.timeout = t.timeout }
        if n.snooze == nil { out.snooze = t.snooze }
        if n.priority == nil { out.priority = t.priority }
        if n.reminder == nil { out.reminder = t.reminder }

        out.layout = n.layout ?? t.layout
        out.accentColor = n.accentColor ?? t.accentColor
        out.showSubtitle = n.showSubtitle ?? t.showSubtitle
        out.showBody = n.showBody ?? t.showBody
        out.showTimestamp = n.showTimestamp ?? t.showTimestamp
        out.maxBodyLines = n.maxBodyLines ?? t.maxBodyLines
        return out
    }

    /// The distinct placeholder names in `text`, in order of first appearance. The template editor
    /// uses it to offer one sample-data row per token.
    public static func placeholders(in text: String) -> [String] {
        var names: [String] = []
        scan(text) { name in
            if !names.contains(name) { names.append(name) }
            return ""
        }
        return names
    }

    // MARK: Filling

    /// Where a token's value comes from: metadata first, then the payload's own fields.
    private struct Values {
        let metadata: [String: JSONValue]
        let fields: [String: String]

        init(_ n: HeraldNotification) {
            if case .object(let o)? = n.metadata { metadata = o } else { metadata = [:] }
            var f: [String: String] = ["title": n.title, "app": n.app]
            if let s = n.subtitle { f["subtitle"] = s }
            if let b = n.body { f["body"] = b }
            if let i = n.id { f["id"] = i }
            if let g = n.group { f["group"] = g }
            fields = f
        }

        func value(for name: String) -> String {
            if let s = Self.scalar(metadata[name]) { return s }
            if name.contains(".") {
                var current: JSONValue? = .object(metadata)
                for part in name.split(separator: ".", omittingEmptySubsequences: false) {
                    guard case .object(let o)? = current else { current = nil; break }
                    current = o[String(part)]
                }
                if let s = Self.scalar(current) { return s }
            }
            return fields[name] ?? ""
        }

        private static func scalar(_ v: JSONValue?) -> String? {
            switch v {
            case .string(let s)?: return s
            case .bool(let b)?: return b ? "true" : "false"
            case .number(let d)?:
                if d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
                return String(d)
            default: return nil   // null, arrays, objects and missing keys fall through
            }
        }
    }

    private static func fill(_ text: String, _ values: Values, urlSafe: Bool = false) -> String {
        scan(text) { name in
            let v = values.value(for: name)
            return urlSafe ? urlEscaped(v) : v
        }
    }

    /// Walks `text`, replacing each well-formed `{token}` with `lookup(token)`. Braces that do not
    /// enclose a plain name (`{}`, `{ a b }`, `{"json": 1}`) are left exactly as written.
    @discardableResult
    private static func scan(_ text: String, _ lookup: (String) -> String) -> String {
        var out = ""
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if ch == "{", let close = text[i...].firstIndex(of: "}") {
                let name = text[text.index(after: i)..<close]
                if isToken(name) {
                    out += lookup(String(name))
                    i = text.index(after: close)
                    continue
                }
            }
            out.append(ch)
            i = text.index(after: i)
        }
        return out
    }

    private static func isToken(_ s: Substring) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "-" }
    }

    /// Characters a substituted value may keep: everything that can appear in some part of a URL, including
    /// `#` so a whole link supplied in metadata (`https://x.com/a?q=1#top`) keeps its fragment. `%` is not in
    /// the set; `urlEscaped` handles it, so an existing `%20` is left alone and a bare `%` becomes `%25`.
    private static let urlLegal: CharacterSet = {
        var s = CharacterSet.urlHostAllowed
        for part in [CharacterSet.urlPathAllowed, .urlQueryAllowed, .urlFragmentAllowed, .urlUserAllowed] { s.formUnion(part) }
        s.insert(charactersIn: "#")
        s.remove(charactersIn: "%")
        return s
    }()

    /// Escapes characters that cannot appear in a URL (space, quotes, non-ASCII...), so a substituted
    /// `https://host` stays intact while "Acme Corp" becomes "Acme%20Corp" and the click target still parses.
    /// A `%` that already starts a valid escape (`%20`) is kept; any other `%` is escaped to `%25`.
    private static func urlEscaped(_ s: String) -> String {
        let chars = Array(s)
        var out = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "%", i + 2 < chars.count, chars[i + 1].isHexDigit, chars[i + 2].isHexDigit {
                out += "%\(chars[i + 1])\(chars[i + 2])"
                i += 3
                continue
            }
            out += c == "%" ? "%25" : (String(c).addingPercentEncoding(withAllowedCharacters: urlLegal) ?? String(c))
            i += 1
        }
        return out
    }
}

// MARK: - Fields and bindings (v2)

/// Bindings read named fields. A field is a top-level payload key (title, subtitle, body, image, url, ...)
/// or a `metadata` key; `fields(for:)` flattens both into one dictionary, top-level first, and `bind`
/// substitutes them into a `{token}` string.
public extension TemplateResolver {
    /// Tokens every notification can provide without a manifest declaring them.
    static let standardTokens = ["title", "subtitle", "body", "image", "url", "app", "appName", "id",
                                 "priority", "sound", "group", "deliveredAt", stackCountToken]

    /// The number of notifications folded into the banner's stack (DESIGN section 9). Not a payload field: the
    /// banner supplies it while it is drawn, and only while the count is above 1 (it is absent, so empty, for a
    /// banner that is alone). Templates read it as `{stack.count}`, or with a `stackBadge` component.
    static let stackCountToken = "stack.count"

    /// A field value as display text: numbers without a trailing ".0", booleans as true/false, lists joined
    /// with ", ".
    static func string(for value: HeraldFieldValue) -> String {
        switch value {
        case .text(let s): return s
        case .number(let d): return number(d)
        case .bool(let b): return b ? "true" : "false"
        case .list(let l): return l.joined(separator: ", ")
        }
    }

    /// Substitutes each `{token}` in `binding` from `fields`. Returns nil when the binding has tokens and every
    /// one of them is absent (a missing key, or a blank value): that is how a component knows it is empty. A
    /// binding without any token is a literal and returns itself (nil when blank). Otherwise absent tokens
    /// become empty text and the result is trimmed, so "{title} {count}" with no count is just the title.
    static func bind(_ binding: String, fields: [String: HeraldFieldValue]) -> String? {
        var sawToken = false, anyPresent = false
        let out = scan(binding) { name in
            sawToken = true
            guard let v = fields[name] else { return "" }
            let s = string(for: v)
            if isBlank(s) { return "" }
            anyPresent = true
            return s
        }
        if sawToken && !anyPresent { return nil }
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Like `bind` but always returns text: absent tokens are empty and nothing is trimmed. For action input.
    static func fill(_ text: String, fields: [String: HeraldFieldValue]) -> String {
        scan(text) { name in fields[name].map { string(for: $0) } ?? "" }
    }

    /// The resolved fields of a notification: its top-level keys (title, subtitle, body, image, url, app, id,
    /// priority, sound), then `appName` from the manifest, then every scalar and list in `metadata`, nested
    /// objects flattened to dotted names (`customer.name`). An earlier source wins over a later one, and blank
    /// values are left out, so "absent" and "empty" are the same thing. `extra` (the template's authored
    /// key/values) is added as `extra.<key>` and `deliveredAt` as an ISO 8601 string.
    ///
    /// With a `manifest`, a declared `number` or `bool` field sent as text ("2", "true") is converted.
    /// Manifest samples are NOT used here: see `sampleFields`.
    static func fields(for n: HeraldNotification, manifest: HeraldManifest? = nil,
                       extra: [String: String] = [:], deliveredAt: Date? = nil) -> [String: HeraldFieldValue] {
        var out: [String: HeraldFieldValue] = [:]
        func put(_ key: String, _ value: String?) {
            if let value, !isBlank(value) { out[key] = .text(value) }
        }
        put("title", n.title); put("subtitle", n.subtitle); put("body", n.body)
        put("image", n.image); put("url", n.url); put("app", n.app); put("id", n.id)
        put("priority", n.priority); put("sound", n.sound); put("group", n.group)
        if let m = manifest { put("appName", m.appName) }
        if let d = deliveredAt { out["deliveredAt"] = .text(ISODate.string(from: d)) }

        if case .object(let o)? = n.metadata {
            for key in o.keys.sorted() { flatten(o[key] ?? .null, key: key, into: &out, depth: 0) }
        }
        for (k, v) in extra where !k.isEmpty && !isBlank(v) { out["extra.\(k)"] = .text(v) }

        if let m = manifest {
            for f in m.fields {
                guard case .text(let s)? = out[f.key] else { continue }
                let t = s.trimmingCharacters(in: .whitespaces)
                switch f.type {
                case .number:
                    if let d = Double(t), d.isFinite { out[f.key] = .number(d) }
                case .bool:
                    switch t.lowercased() {
                    case "true", "yes", "1": out[f.key] = .bool(true)
                    case "false", "no", "0": out[f.key] = .bool(false)
                    default: break
                    }
                default: break
                }
            }
        }
        return out
    }

    /// Preview data for the designer: each manifest field's `sample`, and for a declared field without one a
    /// stand-in by type ("Sender", 3, an ISO date now, https://example.com, true, ["One","Two","Three"]; an
    /// `image` field gets none, since there is no picture to invent). Also `app` and `appName`. With no
    /// manifest, a generic title, subtitle and body so a built-in layout has something to show.
    static func sampleFields(manifest: HeraldManifest?) -> [String: HeraldFieldValue] {
        guard let m = manifest else {
            return ["title": .text("Notification title"), "subtitle": .text("A short subtitle"),
                    "body": .text("Body text goes here, with a [link](https://example.com).")]
        }
        var out: [String: HeraldFieldValue] = ["app": .text(m.app), "appName": .text(m.appName)]
        for f in m.fields {
            if let s = f.sample {
                if !isBlank(string(for: s)) { out[f.key] = s }
                continue
            }
            switch f.type {
            case .text:
                switch f.key {
                case "title": out[f.key] = .text("Notification title")
                case "subtitle": out[f.key] = .text("A short subtitle")
                case "body": out[f.key] = .text("Body text goes here.")
                default: out[f.key] = .text(humanize(f.key))
                }
            case .number: out[f.key] = .number(3)
            case .date: out[f.key] = .text(ISODate.string(from: Date()))
            case .url: out[f.key] = .text("https://example.com")
            case .bool: out[f.key] = .bool(true)
            case .list: out[f.key] = .list(["One", "Two", "Three"])
            case .image: break
            }
        }
        return out
    }

    /// A date from a bound value: ISO 8601 (see `ISODate.parse`) or seconds (or milliseconds) since 1970.
    static func date(from text: String) -> Date? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = ISODate.parse(t) { return d }
        guard let n = Double(t), n.isFinite, n > 0 else { return nil }
        return Date(timeIntervalSince1970: n > 1e11 ? n / 1000 : n)
    }

    // MARK: Helpers

    private static func isBlank(_ s: String) -> Bool { s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private static func number(_ d: Double) -> String {
        if d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
        return String(d)
    }

    /// Adds one metadata value under `key` unless that name is already taken. Arrays of scalars become lists;
    /// nested objects recurse (to three levels) with dotted names; nulls and mixed arrays are skipped.
    private static func flatten(_ v: JSONValue, key: String, into out: inout [String: HeraldFieldValue], depth: Int) {
        switch v {
        case .string(let s):
            if !isBlank(s), out[key] == nil { out[key] = .text(s) }
        case .number(let d):
            if out[key] == nil { out[key] = .number(d) }
        case .bool(let b):
            if out[key] == nil { out[key] = .bool(b) }
        case .array(let items):
            var list: [String] = []
            for item in items {
                switch item {
                case .string(let s): if !isBlank(s) { list.append(s) }
                case .number(let d): list.append(number(d))
                case .bool(let b): list.append(b ? "true" : "false")
                default: break
                }
            }
            if !list.isEmpty, out[key] == nil { out[key] = .list(list) }
        case .object(let o):
            guard depth < 3 else { return }
            for k in o.keys.sorted() { flatten(o[k] ?? .null, key: "\(key).\(k)", into: &out, depth: depth + 1) }
        case .null:
            break
        }
    }

    /// A stand-in value for a token no manifest sample covers ("receivedAt" -> "Received at"), so the Designer can
    /// show a bound component drawn instead of an empty box.
    static func sampleText(forKey key: String) -> String { humanize(key) }

    /// "receivedAt" becomes "Received at".
    private static func humanize(_ key: String) -> String {
        var words: [String] = []
        var current = ""
        for ch in key {
            if ch == "_" || ch == "-" || ch == "." {
                if !current.isEmpty { words.append(current); current = "" }
            } else if ch.isUppercase, !current.isEmpty {
                words.append(current); current = String(ch).lowercased()
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { words.append(current) }
        guard let first = words.first else { return key }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + words.dropFirst()).joined(separator: " ")
    }
}
