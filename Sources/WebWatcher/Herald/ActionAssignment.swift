import Foundation

/// How a button looks, and what it does before it runs. On the wire it is a string (`style`), and the old
/// `default` still means `normal`.
public enum HeraldActionStyle: String, CaseIterable, Sendable {
    /// A tinted capsule.
    case normal
    /// A filled capsule: the one action the banner is for.
    case prominent
    /// The label is drawn in red and Herald asks for confirmation before running it.
    case destructive
    /// A quiet grey capsule.
    case cancel

    /// Every spelling a template or a manifest may use.
    public static let accepted = ["default", "normal", "prominent", "destructive", "cancel"]
    public static let acceptedList = "normal, prominent, destructive or cancel"

    /// nil, `default` and anything unknown are `normal`.
    public static func parse(_ s: String?) -> HeraldActionStyle {
        guard let s, let v = HeraldActionStyle(rawValue: s.lowercased()) else { return .normal }
        return v
    }

    public static func isAccepted(_ s: String) -> Bool { accepted.contains(s) }

    /// True when pressing a button of this style first asks the user.
    public static func asksConfirmation(_ s: String?) -> Bool { parse(s) == .destructive }
}

/// Which action each cell of a template shows. An action is drawn in at most one cell:
/// - a `button` bound to an action id (`actionRef` / `actionId`) claims it;
/// - an `actions` cell with `include` claims those ids, in that order;
/// - an `actions` cell with no `include` takes every action of its `source` that nobody claimed.
/// Cells are visited top to bottom, left to right, so when two cells ask for the same action the first one wins
/// and the other shows nothing for it (validation warns about it).
public struct HeraldActionAssignment: Equatable, Sendable {
    /// Cell id -> the actions that cell shows, in order. Present for every `actions` cell and every `button`
    /// bound to an id (empty when it lost the action or the action is not in the list); absent for other cells
    /// and for a button with an inline action.
    public var byCell: [String: [HeraldResolvedAction]]
    /// Action id -> ids of the cells that asked for it explicitly (button binding or `include`), in cell order.
    public var claimants: [String: [String]]

    public func actions(forCell id: String) -> [HeraldResolvedAction]? { byCell[id] }
    /// Action ids that more than one cell asked for.
    public var contested: [String: [String]] { claimants.filter { $0.value.count > 1 } }
}

public extension HeraldTemplate {
    /// Cells in reading order (row, then column), the order the assignment is made in.
    private var readingOrder: [HeraldCell] {
        cells.sorted { ($0.row, $0.col, $0.id) < ($1.row, $1.col, $1.id) }
    }

    /// See `HeraldActionAssignment`. `actions` is the resolved list (`ActionResolver.resolveDetailed`).
    func actionAssignment(actions: [HeraldResolvedAction]) -> HeraldActionAssignment {
        var byCell: [String: [HeraldResolvedAction]] = [:]
        var claimants: [String: [String]] = [:]
        var taken = Set<String>()
        let ordered = readingOrder

        // Pass 1: explicit claims.
        for cell in ordered {
            switch cell.component {
            case .button(let b):
                guard b.action == nil, let ref = b.actionRef?.trimmingCharacters(in: .whitespaces), !ref.isEmpty else { continue }
                claimants[ref, default: []].append(cell.id)
                if !taken.contains(ref), let r = actions.first(where: { $0.action.id == ref }) {
                    taken.insert(ref)
                    byCell[cell.id] = [r]
                } else {
                    byCell[cell.id] = []
                }
            case .actions(let a):
                let ids = a.includedIDs
                guard !ids.isEmpty else { continue }
                var mine: [HeraldResolvedAction] = []
                for id in ids {
                    claimants[id, default: []].append(cell.id)
                    if !taken.contains(id), let r = actions.first(where: { $0.action.id == id && a.source.includes($0.origin) }) {
                        taken.insert(id)
                        mine.append(r)
                    }
                }
                byCell[cell.id] = mine
            default:
                continue
            }
        }
        // Pass 2: the cells that take whatever is left.
        for cell in ordered {
            guard case .actions(let a) = cell.component, a.includedIDs.isEmpty else { continue }
            let rest = actions.filter { a.source.includes($0.origin) && !taken.contains($0.action.id) }
            taken.formUnion(rest.map(\.action.id))
            byCell[cell.id] = rest
        }
        return HeraldActionAssignment(byCell: byCell, claimants: claimants)
    }

    /// Does the cell have something to show? Like `HeraldComponent.hasContent`, but an action cell only counts
    /// the actions it is assigned.
    func cellHasContent(_ cell: HeraldCell, fields: [String: HeraldFieldValue], actions: [HeraldResolvedAction],
                        assignment: HeraldActionAssignment? = nil) -> Bool {
        let mine = (assignment ?? actionAssignment(actions: actions)).actions(forCell: cell.id)
        return cell.component.hasContent(fields: fields, actions: mine ?? actions)
    }
}
