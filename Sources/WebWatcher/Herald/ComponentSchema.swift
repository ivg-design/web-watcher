import Foundation

/// A hand-written description of the v2 template format for agents (DESIGN 7.5, 7.6): every component
/// type, every property with its type, allowed values and default, how bindings and collapsing work, the
/// action kinds and rules, and complete examples. Served by `GET /v1/components` and the MCP
/// `component_schema` tool / `herald://docs/components` resource.
///
/// The enum value lists are generated from the Swift enums (so they cannot drift); the prose is written
/// here, next to the types it describes. `TemplateV2Tests` checks every component type, property and enum
/// value is covered and that the examples decode and validate.
public enum ComponentSchema {
    public static let schemaVersion = 2

    /// The schema document. JSON Schema flavoured (`type`, `properties`, `enum`, `default`, `required`) with
    /// extra `description`, `emptyWhen` and `example` keys, organised for reading rather than validation.
    public static func document() -> JSONValue {
        o([
            "$schema": s("https://json-schema.org/draft/2020-12/schema"),
            "title": s("Herald banner template, layoutVersion 2"),
            "schemaVersion": n(Double(schemaVersion)),
            "description": s("""
                A Herald banner is drawn from a GRID. The template has a grid (rows, columns, sizes, gap, padding, width) and a list \
                of cells; each cell sits on some rows and columns and holds ONE component. Components are bound to notification \
                fields with {token} placeholders. When a component's tokens are all absent the component is EMPTY and, depending on \
                emptyBehavior / collapseEmpty, it collapses (disappears, and an all-empty row or column collapses to zero) or keeps its space. \
                Buttons come from two sources: the issuer (payload buttons / manifest actions) and the template (actionRules, which can \
                hide, relabel, restyle, reorder issuer actions and add your own: url, command, script, Apple Shortcut, dismiss, snooze).
                """),
            "workflow": strs([
                "1. get_manifest(app) to see which fields the issuer sends (their keys are the {tokens}) and which actions it offers.",
                "2. Draft a template: choose a grid, place components in cells, bind them to {tokens}.",
                "3. validate_template, then render_preview (data: \"sample\") in light and dark; adjust until it looks right.",
                "4. Add actions: actionRules to hide/relabel issuer actions and add shortcut/script/command/url actions; list_shortcuts lists installed Shortcuts.",
                "5. put_template to save it; set the manifest's defaultTemplate so notifications from that app use it.",
            ]),
            "type": s("object"),
            "required": strs(["name", "app", "layoutVersion", "grid", "cells"]),
            "properties": templateProperties(),
            "definitions": definitions(),
            "components": components(),
            "bindings": bindings(),
            "actions": actions(),
            "examples": examples(),
        ])
    }

    /// The document as pretty-printed JSON text.
    public static func jsonString() -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? enc.encode(document()), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// The document as JSON bytes (what `GET /v1/components` returns).
    public static func jsonData() -> Data { Data(jsonString().utf8) }

    /// A short Markdown guide to the same material, for a resource an agent reads before authoring.
    public static func guide() -> String {
        var md = """
        # Herald templates (layoutVersion 2)

        A banner is a **grid**: `grid.rows` x `grid.cols` tracks sized `"auto"`, `"fill"` or a number of points, with `gap`, `padding` and a banner `width`.
        Each **cell** (`row`, `col`, `rowSpan`, `colSpan`, `align`, `padding`) holds one **component**: `{"type": "...", ...}`.

        Component types: \(HeraldComponent.typeNames.joined(separator: ", ")).

        ## Bindings
        Text-like components bind to fields with `{token}`: `"{title} - {count}"`. Tokens are the manifest's field keys, the standard fields
        (\(TemplateResolver.standardTokens.joined(separator: ", "))), `{extra.key}` for the template's own `extra` values, and dotted names into metadata (`{customer.name}`).
        A component whose tokens are all absent is **empty**.
        `{stack.count}` is the number of notifications folded into the banner's stack (DESIGN section 9); it is absent, so empty, while the banner is alone.

        ## Empty components
        `collapseEmpty` (template) and `emptyBehavior` (component, `collapse` or `keep`) decide: collapse removes the component and a row or column with nothing live collapses to zero (no gap); keep leaves the space blank.

        ## Actions
        The action list is the issuer's actions plus the template's, after `actionRules`. A rule is `{"match": "<id or label or *>", "hide": true}`, `{"match": "...", "relabel": "...", "style": "destructive", "position": 0}` or `{"add": <action>}`.
        An action is `{"id", "label", "kind", "style"?, ...}` with kind-specific fields:

        """
        for (kind, text) in actionKindDocs() { md += "- `\(kind)`: \(text)\n" }
        md += """

        Every action receives the merged payload (the notification, its resolved fields, the template's `extra`). Shortcut input is the `input` text with tokens filled, or the full JSON when `input` is omitted.

        ## Components
        """
        for t in HeraldComponent.typeNames {
            guard case .object(let all) = components(), case .object(let c)? = all[t],
                  case .string(let d)? = c["description"] else { continue }
            md += "\n- `\(t)`: \(d)"
        }
        md += "\n\nCall `component_schema` for every property, default and example.\n"
        return md
    }

    // MARK: - Pieces

    private static func templateProperties() -> JSONValue {
        o([
            "name": prop("string", "Template name, unique per app. Notifications select it with \"template\"."),
            "app": prop("string", "The issuer's app id."),
            "layoutVersion": prop("integer", "2 for grid templates. 1 (or absent without a grid) is a legacy fixed layout.", values: nil, def: n(2)),
            "grid": ref("grid"),
            "cells": prop("array", "The cells, each holding one component. Cells must not overlap and must fit the grid.", items: ref("cell")),
            "collapseEmpty": prop("boolean", "Default for components without their own emptyBehavior. true: an empty component disappears and an all-empty row/column collapses to zero. false: empty components keep their space.", def: b(true)),
            "actionRules": prop("array", "Rules applied in order to the issuer's actions: hide, relabel, restyle, reorder, add.", items: ref("actionRule")),
            "extra": prop("object", "Your own key/values (strings). Every action receives them as `extra`; bindings read them as {extra.key}."),
            "accentColor": prop("string", "Hex colour (#RRGGBB) for tint and `accent`-coloured components. Optional."),
            "sound": prop("string", "Default sound: a system sound name, a file path or \"none\". Payload overrides."),
            "persistent": prop("boolean", "Default persistence. Payload overrides."),
            "timeout": prop("number", "Default auto-dismiss seconds (0 = persistent). Payload overrides."),
            "snooze": prop("boolean", "Show the snooze control by default."),
            "title": prop("string", "Default title with {tokens}, used when the payload has none."),
            "subtitle": prop("string", "Default subtitle with {tokens}."),
            "body": prop("string", "Default body with {tokens}."),
            "buttons": prop("array", "Legacy default buttons {label, url|command|callback, style}, used when the payload sends none. Prefer actionRules."),
        ])
    }

    private static func definitions() -> JSONValue {
        o([
            "size": o([
                "description": s("A row or column size."),
                "oneOf": a([
                    o(["const": s("auto"), "description": s("As large as its content.")]),
                    o(["const": s("fill"), "description": s("Shares the leftover space equally with other fill tracks.")]),
                    o(["type": s("number"), "description": s("A fixed size in points, 0 to 4000.")]),
                ]),
                "examples": a([s("auto"), s("fill"), n(72)]),
            ]),
            "align": o([
                "type": s("string"), "enum": strs(HeraldAlign.allCases.map(\.rawValue)),
                "default": s("topLeading"),
                "description": s("Where the component sits inside its cell when the cell is larger than the component."),
            ]),
            "emptyBehavior": o([
                "type": s("string"), "enum": strs(HeraldEmptyBehavior.allCases.map(\.rawValue)),
                "description": s("collapse: the empty component disappears and a row/column left with nothing collapses to zero. keep: it stays, blank, and its cell keeps its size. Omit to follow the template's collapseEmpty."),
            ]),
            "color": o([
                "type": s("string"),
                "description": s("#RGB, #RRGGBB or #RRGGBBAA, or the keywords accent (the template accentColor, else the system accent), primary, secondary."),
            ]),
            "grid": o([
                "type": s("object"), "required": strs(["rows", "cols"]),
                "description": s("The grid. rowSizes has exactly `rows` entries and colSizes exactly `cols`; rows and cols are 1 to \(HeraldTemplate.maxGridTracks)."),
                "properties": o([
                    "rows": prop("integer", "Number of rows.", min: 1, max: Double(HeraldTemplate.maxGridTracks), def: n(3)),
                    "cols": prop("integer", "Number of columns.", min: 1, max: Double(HeraldTemplate.maxGridTracks), def: n(4)),
                    "rowSizes": prop("array", "One size per row.", items: ref("size")),
                    "colSizes": prop("array", "One size per column.", items: ref("size")),
                    "gap": prop("number", "Space between tracks, points (0-64).", def: n(8)),
                    "padding": prop("number", "Space between the banner edge and the tracks, points (0-64).", def: n(14)),
                    "width": prop("number", "Banner width in points (\(Int(HeraldTemplate.widthRange.lowerBound))-\(Int(HeraldTemplate.widthRange.upperBound))). Live banners are 380 wide.", def: n(400)),
                ]),
                "example": jsonValue(#"{"rows":3,"cols":4,"rowSizes":["auto","auto","auto"],"colSizes":[72,"fill","fill",56],"gap":8,"padding":14,"width":400}"#),
            ]),
            "cell": o([
                "type": s("object"), "required": strs(["id", "row", "col", "component"]),
                "description": s("One cell. Rows and columns are 0-based; the cell covers rowSpan x colSpan tracks starting at (row, col) and must fit the grid. Cells must not overlap."),
                "properties": o([
                    "id": prop("string", "Unique within the template. put_template / validate_template errors name cells by id."),
                    "row": prop("integer", "First row, 0-based.", min: 0),
                    "col": prop("integer", "First column, 0-based.", min: 0),
                    "rowSpan": prop("integer", "Rows covered.", min: 1, def: n(1)),
                    "colSpan": prop("integer", "Columns covered.", min: 1, def: n(1)),
                    "align": ref("align"),
                    "padding": prop("number", "Inset around the component, points (0-64).", def: n(0)),
                    "component": o(["description": s("One component object: {\"type\": \"text\" | ...}. See `components`."),
                                    "oneOf": a(HeraldComponent.typeNames.map { ref("component." + $0) })]),
                ]),
            ]),
            "symbol": symbolDefinition(),
            "action": actionDefinition(),
            "actionRule": o([
                "type": s("object"),
                "description": s("Applied in order to the action list. Needs a match or an add. With match: hide removes the matched actions; otherwise relabel / style change them and position (0-based, clamped) moves them. With add: appends a template-owned action (at `position` when the rule has no match); an added action whose id already exists replaces it."),
                "properties": o([
                    "match": prop("string", "An action id or label (case-insensitive), or \"*\" for every action."),
                    "hide": prop("boolean", "Remove the matched actions."),
                    "relabel": prop("string", "New label for the matched actions."),
                    "style": prop("string", "New style for the matched actions.", values: ["default", "destructive", "cancel"]),
                    "position": prop("integer", "0-based index to move the matched actions to, or where to insert an added action.", min: 0),
                    "add": ref("action"),
                    "symbol": ref("symbol"),
                ]),
                "examples": a([
                    jsonValue(#"{"match":"markRead","hide":true}"#),
                    jsonValue(#"{"match":"archive","relabel":"Archive it","style":"destructive","position":0}"#),
                    jsonValue(#"{"add":{"id":"shortcut-followup","label":"Follow up","kind":"shortcut","shortcut":"Create follow-up","input":"{title}\n{url}"}}"#),
                ]),
            ]),
        ])
    }

    private static func actionDefinition() -> JSONValue {
        o([
            "type": s("object"), "required": strs(["id", "label", "kind"]),
            "description": s("One action (a button's behaviour). `kind` selects what it does; only the matching fields are used. kind may be omitted when exactly one of shortcut/script/command/callback/url is present; id defaults to a slug of the label."),
            "properties": o([
                "id": prop("string", "Stable name rules (`match`) and components (`actionRef`) refer to."),
                "label": prop("string", "Button text."),
                "kind": prop("string", "What pressing it does.", values: HeraldActionKind.allCases.map(\.rawValue)),
                "style": prop("string", "Button look.", values: ["default", "destructive", "cancel"], def: s("default")),
                "url": prop("string", "kind url: http, https or mailto URL; may contain {tokens}."),
                "callback": prop("object", "kind callback: {url?, payload?}; POSTed to the issuer's callback URL."),
                "command": prop("string", "kind command: shell command line run with /bin/zsh -lc (template-authored commands need one confirmation per template)."),
                "script": prop("string", "kind script: file name in Application Support/Herald/scripts; receives the merged payload JSON on stdin."),
                "shortcut": prop("string", "kind shortcut: name of an installed Apple Shortcut (see list_shortcuts)."),
                "input": prop("string", "kind shortcut: text passed as the Shortcut's input, with {tokens} filled. Omit to pass the full merged payload as JSON."),
                "snoozeMinutes": prop("integer", "kind snooze: minutes (1-10080), default \(HeraldAction.defaultSnoozeMinutes).", min: 1, max: 10080),
                "symbol": ref("symbol"),
            ]),
        ])
    }

    private static func actionKindDocs() -> [(String, String)] {
        [
            (HeraldActionKind.url.rawValue, "open `url` (http, https, mailto)."),
            (HeraldActionKind.callback.rawValue, "tell the issuing app (POST to its callback URL); the issuer decides what happens."),
            (HeraldActionKind.command.rawValue, "run `command` through /bin/zsh -lc."),
            (HeraldActionKind.script.rawValue, "run a file from Herald's scripts folder with the merged payload JSON on stdin."),
            (HeraldActionKind.shortcut.rawValue, "run the Apple Shortcut named `shortcut`; input is the `input` text, or the full payload JSON."),
            (HeraldActionKind.dismiss.rawValue, "close the banner."),
            (HeraldActionKind.snooze.rawValue, "hide the banner and bring it back after `snoozeMinutes`."),
        ]
    }

    private static func actions() -> JSONValue {
        o([
            "description": s("Resolved actions = the issuer's actions (payload buttons, or the manifest's actions) with the template's actionRules applied. Issuer actions can only be url, callback, command or dismiss; script, shortcut and snooze come from the template (they are yours). Components show them: `actions` lists them all; `button` / `iconButton` show one, by actionRef (an id in the resolved list) or inline."),
            "kinds": .object(Dictionary(uniqueKeysWithValues: actionKindDocs().map { ($0.0, s($0.1)) })),
            "payload": s("Every action receives {app, id, action:{id,label,kind}, fields:{token: value}, extra:{key: value}, notification:{...}} - the merged payload."),
        ])
    }

    private static func symbolDefinition() -> JSONValue {
        o([
            "description": s("An SF Symbol: a plain name (\"bell.badge\") or an object with the styling below. Effects need macOS 14 and are off under Reduce Motion; static renders (render_preview) show weight, scale, rendering mode and colours only. An unknown name is a warning: the default look is drawn."),
            "oneOf": a([o(["type": s("string"), "description": s("An SF Symbol name.")]), o(["type": s("object")])]),
            "required": strs(["name"]),
            "properties": o([
                "name": prop("string", "SF Symbol name, e.g. \"bell.badge\", \"checkmark.circle.fill\"."),
                "weight": prop("string", "Stroke weight.", values: HeraldSymbolWeight.allCases.map(\.rawValue), def: s("regular")),
                "scale": prop("string", "Size relative to the text.", values: HeraldSymbolScale.allCases.map(\.rawValue), def: s("medium")),
                "placement": prop("string", "Beside a label: leading, trailing, or only (label dropped). Default leading.", values: HeraldSymbolPlacement.allCases.map(\.rawValue)),
                "renderingMode": prop("string", "monochrome: one colour; hierarchical: shades of one colour; palette: 2-3 colours; multicolor: the symbol's own colours.", values: HeraldSymbolRenderingMode.allCases.map(\.rawValue), def: s("monochrome")),
                "colors": prop("array", "1-3 colours for hierarchical / palette: #RGB, #RRGGBB, #RRGGBBAA, accent, primary, secondary, or a {token} whose value is one of those.", items: o(["type": s("string")])),
                "variableValue": prop("string", "0-1 for symbols that support it (wifi, speaker.wave.3, ...): a number, or a {token} bound to a numeric field such as \"{progress}\".", min: 0, max: 1),
                "effect": o(["type": s("object"), "description": s("macOS 14+ symbol effect."), "required": strs(["kind"]), "properties": o([
                    "kind": prop("string", "bounce, pulse, variableColor, scale, appear, disappear, or replace (swaps the symbol when its bound value changes).", values: HeraldSymbolEffectKind.allCases.map(\.rawValue)),
                    "trigger": prop("string", "When it plays: onAppear (default), onChange (when a bound value changes), onHover, or repeating.", values: HeraldSymbolTrigger.allCases.map(\.rawValue), def: s("onAppear")),
                    "speed": prop("number", "Playback speed multiplier.", min: 0.25, max: 4, def: n(1)),
                    "cumulative": prop("boolean", "variableColor only: layers stay on."),
                    "reversing": prop("boolean", "variableColor only: plays back and forth."),
                ])]),
            ]),
            "examples": a([
                jsonValue(##""bell.badge""##),
                jsonValue(#"{"name":"wifi","weight":"semibold","renderingMode":"hierarchical","colors":["accent"],"variableValue":"{signal}"}"#),
                jsonValue(##"{"name":"bell.badge","renderingMode":"palette","colors":["#FF3B30","primary"],"effect":{"kind":"bounce","trigger":"onChange"}}"##),
            ]),
        ])
    }

    private static func bindings() -> JSONValue {
        o([
            "syntax": s("{token} inside text. A token is letters, digits, '_', '.', '-'. Absent tokens are empty; a binding whose every token is absent makes its component empty."),
            "standardTokens": strs(TemplateResolver.standardTokens),
            "tokenSources": strs([
                "Top-level payload keys (title, subtitle, body, image, url, app, id, priority, sound), then the manifest's appName, then metadata keys (nested objects as dotted names: {customer.name}); earlier sources win.",
                "{extra.key} reads the template's own `extra` values.",
                "{deliveredAt} is the delivery time (ISO 8601). A timestamp component with no binding shows the delivery time.",
                "{stack.count} is the number of notifications folded into the banner's stack: present only while 2 or more are stacked, so it is empty (and its component collapses) for a lone banner. The stackBadge component binds it for you.",
                "Manifest fields (get_manifest) list the tokens an issuer sends, their types and sample values (used by render_preview with data: \"sample\").",
            ]),
            "valueFormatting": s("Numbers print without a trailing .0, booleans as true/false, lists joined with \", \". Blank values count as absent."),
            "collapsing": s("An empty component with behaviour collapse is removed. A row or column collapses when every cell on it (a cell spanning it included) is collapsed; a row/column no cell touches collapses only if collapseEmpty is true."),
        ])
    }

    private static func components() -> JSONValue {
        let empty = ["emptyBehavior": ref("emptyBehavior")]
        func comp(_ type: String, _ description: String, required: [String] = [], emptyWhen: String,
                  _ props: KeyValuePairs<String, JSONValue>, example: String) -> (String, JSONValue) {
            var p = Dictionary(uniqueKeysWithValues: props.map { ($0.key, $0.value) })
            p["type"] = o(["const": s(type)])
            if type != "spacer" { for (k, v) in empty { p[k] = v } }
            return (type, o([
                "type": s("object"), "description": s(description),
                "required": strs(["type"] + required), "emptyWhen": s(emptyWhen),
                "properties": .object(p), "example": jsonValue(example),
            ]))
        }
        let color = ref("color")
        let all: [(String, JSONValue)] = [
            comp("text", "Text from a binding, e.g. a title, subtitle or body line. Style sets font, size and default colour.",
                 required: ["binding"], emptyWhen: "every {token} in binding is absent", [
                "binding": prop("string", "Text with {tokens}, e.g. \"{title}\" or \"{count} new from {sender}\"."),
                "style": prop("string", "Typography preset.", values: HeraldTextStyle.allCases.map(\.rawValue), def: s("body")),
                "maxLines": prop("integer", "Line limit; omit for the style's default.", min: 1),
                "color": color,
                "fontSize": prop("number", "Points (6-72); omit for the style's size."),
                "weight": prop("string", "Font weight; omit for the style's weight.", values: HeraldFontWeight.allCases.map(\.rawValue)),
                "alignment": prop("string", "Horizontal text alignment inside the cell.", values: HeraldTextAlignment.allCases.map(\.rawValue)),
                "markdown": prop("boolean", "Render inline Markdown ([text](url) links). Default true for style body, false otherwise."),
            ], example: #"{"type":"text","binding":"{title}","style":"title","maxLines":2}"#),
            comp("image", "A picture from a binding (file path, data: URI or https URL).",
                 emptyWhen: "the binding's token is absent", [
                "binding": prop("string", "Default \"{image}\"."),
                "fit": prop("string", "fit letterboxes, fill stretches, cover crops to fill.", values: HeraldImageFit.allCases.map(\.rawValue), def: s("cover")),
                "cornerRadius": prop("number", "Points.", def: n(0)),
                "aspectRatio": prop("number", "Width / height (1 = square, 1.7778 = 16:9). Fixes the height when the column width is fixed."),
                "height": prop("number", "Fixed height in points; wins over aspectRatio."),
            ], example: #"{"type":"image","binding":"{image}","fit":"cover","cornerRadius":10,"aspectRatio":1}"#),
            comp("issuerIcon", "The issuing app's icon.", emptyWhen: "never empty", [
                "size": prop("number", "Points (8-128).", def: n(22)),
                "cornerRadius": prop("number", "Points; default 22% of size. Ignored for circle."),
                "shape": prop("string", "Icon shape.", values: HeraldIconShape.allCases.map(\.rawValue), def: s("rounded")),
                "symbol": ref("symbol"),
            ], example: #"{"type":"issuerIcon","size":22,"shape":"rounded"}"#),
            comp("timestamp", "A time. Shows the bound date field, or the banner's delivery time when binding is omitted.",
                 emptyWhen: "a binding is set and its token is absent (never empty without a binding)", [
                "binding": prop("string", "A date field such as \"{receivedAt}\" (ISO 8601 or epoch seconds). Omit for the delivery time."),
                "relative": prop("boolean", "\"3 min ago\" instead of a clock time.", def: b(false)),
                "style": prop("string", "Typography preset.", values: HeraldTextStyle.allCases.map(\.rawValue), def: s("caption")),
                "color": color,
                "fontSize": prop("number", "Points."),
            ], example: #"{"type":"timestamp","binding":"{receivedAt}","relative":true}"#),
            comp("button", "One button. Give an inline action, or actionRef to show an issuer / template action by id.",
                 emptyWhen: "actionRef names an action that is not in the resolved list (hidden by a rule, or not sent); an inline action is never empty", [
                "action": ref("action"),
                "actionRef": prop("string", "Id of an action in the resolved list (e.g. an issuer action id such as \"markRead\")."),
                "style": prop("string", "Overrides the action's style.", values: ["default", "destructive", "cancel"]),
                "symbol": ref("symbol"),
            ], example: #"{"type":"button","actionRef":"markRead","symbol":{"name":"checkmark.circle","weight":"semibold"}}"#),
            comp("actions", "The action row: all resolved actions from `source`, as buttons.",
                 emptyWhen: "the source yields no actions", [
                "source": prop("string", "issuer: only the issuer's actions; template: only actions added by actionRules; merged: all.", values: HeraldActionSource.allCases.map(\.rawValue), def: s("merged")),
                "layout": prop("string", "row: one line; wrap: flows onto more lines; stack: one per line.", values: HeraldActionsLayout.allCases.map(\.rawValue), def: s("wrap")),
                "maxVisible": prop("integer", "Show at most this many.", min: 1),
                "symbol": ref("symbol"),
            ], example: #"{"type":"actions","source":"merged","layout":"wrap"}"#),
            comp("iconButton", "A round icon-only button with an SF Symbol, e.g. a close or snooze button.",
                 required: ["symbol"], emptyWhen: "actionRef names an action that is not in the resolved list; an inline action is never empty", [
                "symbol": ref("symbol"),
                "action": ref("action"),
                "actionRef": prop("string", "Id of an action in the resolved list."),
                "size": prop("number", "Diameter in points; default 18."),
                "color": color,
                "tooltip": prop("string", "Hover text."),
            ], example: #"{"type":"iconButton","symbol":"xmark","action":{"id":"dismiss","label":"Dismiss","kind":"dismiss"}}"#),
            comp("badge", "A small pill with a value, e.g. an unread count.",
                 required: ["binding"], emptyWhen: "every {token} in binding is absent", [
                "binding": prop("string", "Text with {tokens}, e.g. \"{count}\"."),
                "color": prop("string", "Pill colour: hex or accent. Default accent."),
                "textColor": prop("string", "Text colour: hex or primary. Default: legible on the pill."),
                "symbol": ref("symbol"),
            ], example: ##"{"type":"badge","binding":"{count}","color":"#FF3B30"}"##),
            comp("stackBadge", "The stack counter: a pill showing {stack.count}, the number of notifications folded into this banner's stack (empty while the banner is alone). Click it to expand the stack. A template without one gets the counter at the top right of the stacked card.",
                 emptyWhen: "the banner is not stacked ({stack.count} is absent below 2)", [
                "color": prop("string", "Pill colour: hex or accent. Default accent."),
                "textColor": prop("string", "Text colour: hex or primary. Default: legible on the pill."),
            ], example: ##"{"type":"stackBadge","color":"#FF3B30"}"##),
            comp("progress", "A progress bar. The bound value is 0...1, or a percentage when greater than 1.",
                 required: ["binding"], emptyWhen: "every {token} in binding is absent", [
                "binding": prop("string", "e.g. \"{percent}\"."),
                "color": color,
                "height": prop("number", "Bar thickness in points; default 4."),
            ], example: #"{"type":"progress","binding":"{percent}"}"#),
            comp("rive", "A Rive animation (a manifest asset or a .riv file) whose state machine inputs follow fields and the pointer.",
                 emptyWhen: "neither asset nor path is set", [
                "asset": prop("string", "Id of a manifest asset (get_manifest -> assets)."),
                "path": prop("string", "Path to a .riv file, instead of asset."),
                "stateMachine": prop("string", "State machine name; default the asset's."),
                "artboard": prop("string", "Artboard name; default the file's default."),
                "inputBindings": prop("object", "State machine input name -> \"{token}\" (number, boolean or trigger by value) or the keyword \"hover\" / \"pressed\" (driven by the pointer)."),
                "action": ref("action"),
                "actionRef": prop("string", "Clicking the animation runs this action (inline `action` or an id)."),
                "loop": prop("boolean", "Override looping."),
                "aspectRatio": prop("number", "Width / height."),
                "height": prop("number", "Fixed height in points."),
            ], example: #"{"type":"rive","asset":"bell","stateMachine":"Main","inputBindings":{"count":"{count}","hover":"hover"},"height":40}"#),
            comp("spacer", "Empty space that fills its cell. Never empty, never collapses.", emptyWhen: "never empty", [:],
                 example: #"{"type":"spacer"}"#),
        ]
        var byName: [String: JSONValue] = [:]
        for (t, v) in all { byName[t] = v }
        return .object(byName)
    }

    private static func examples() -> JSONValue {
        a([
            o(["name": s("Email, accumulated"),
               "note": s("Icon, sender line, subject and a count badge; Mark as Read is the issuer's action (kept, relabelled), Archive is hidden, and a template-owned Shortcut is added. Empty rows collapse."),
               "template": jsonValue(emailExample)]),
            o(["name": s("Compact, keep spacing"),
               "note": s("collapseEmpty false: an absent subtitle keeps its blank row, so banners from the same issuer line up."),
               "template": jsonValue(keepExample)]),
        ])
    }

    public static let emailExample = """
    {"name":"email-accumulated","app":"webwatcher.email","layoutVersion":2,"collapseEmpty":true,
     "grid":{"rows":3,"cols":4,"rowSizes":["auto","auto","auto"],"colSizes":[40,"fill","fill","auto"],"gap":6,"padding":12,"width":380},
     "cells":[
      {"id":"icon","row":0,"col":0,"rowSpan":2,"align":"topLeading","component":{"type":"issuerIcon","size":32}},
      {"id":"title","row":0,"col":1,"colSpan":2,"component":{"type":"text","binding":"{title}","style":"title","maxLines":2}},
      {"id":"count","row":0,"col":3,"align":"topTrailing","component":{"type":"badge","binding":"{count}","color":"#FF3B30"}},
      {"id":"subject","row":1,"col":1,"colSpan":2,"component":{"type":"text","binding":"{sender}: {subject}","style":"body","maxLines":3}},
      {"id":"time","row":1,"col":3,"align":"topTrailing","component":{"type":"timestamp","binding":"{receivedAt}","relative":true}},
      {"id":"actions","row":2,"col":0,"colSpan":4,"component":{"type":"actions","source":"merged","layout":"wrap"}}],
     "actionRules":[
      {"match":"markRead","relabel":"Mark as read","position":0},
      {"match":"archive","hide":true},
      {"add":{"id":"shortcut-followup","label":"Follow up","kind":"shortcut","shortcut":"Create follow-up","input":"{title}\\n{url}"}}],
     "extra":{"queue":"inbox"}}
    """

    public static let keepExample = """
    {"name":"status-line","app":"bidbot","layoutVersion":2,"collapseEmpty":false,
     "grid":{"rows":3,"cols":2,"rowSizes":["auto","auto","auto"],"colSizes":["fill","auto"],"gap":4,"padding":12,"width":380},
     "cells":[
      {"id":"title","row":0,"col":0,"component":{"type":"text","binding":"{title}","style":"title"}},
      {"id":"close","row":0,"col":1,"align":"topTrailing","component":{"type":"iconButton","symbol":"xmark","action":{"id":"dismiss","label":"Dismiss","kind":"dismiss"}}},
      {"id":"subtitle","row":1,"col":0,"colSpan":2,"component":{"type":"text","binding":"{subtitle}","style":"subtitle"}},
      {"id":"progress","row":2,"col":0,"colSpan":2,"component":{"type":"progress","binding":"{percent}","emptyBehavior":"collapse"}}]}
    """

    // MARK: - DSL

    private static func s(_ v: String) -> JSONValue { .string(v) }
    private static func n(_ v: Double) -> JSONValue { .number(v) }
    private static func b(_ v: Bool) -> JSONValue { .bool(v) }
    private static func a(_ v: [JSONValue]) -> JSONValue { .array(v) }
    private static func strs(_ v: [String]) -> JSONValue { .array(v.map { .string($0) }) }
    private static func o(_ pairs: KeyValuePairs<String, JSONValue>) -> JSONValue {
        .object(Dictionary(uniqueKeysWithValues: pairs.map { ($0.key, $0.value) }))
    }

    /// A reference to a definition (`definitions.<name>`) or a component schema (`components.<type>`).
    private static func ref(_ name: String) -> JSONValue {
        if name.hasPrefix("component.") { return o(["$ref": s("#/components/" + name.dropFirst("component.".count))]) }
        return o(["$ref": s("#/definitions/" + name)])
    }

    private static func prop(_ type: String, _ description: String, values: [String]? = nil, min: Double? = nil, max: Double? = nil,
                             def: JSONValue? = nil, items: JSONValue? = nil) -> JSONValue {
        var d: [String: JSONValue] = ["type": s(type), "description": s(description)]
        if let values { d["enum"] = strs(values) }
        if let def { d["default"] = def }
        if let min { d["minimum"] = n(min) }
        if let max { d["maximum"] = n(max) }
        if let items { d["items"] = items }
        return .object(d)
    }

    /// Parses a JSON literal written in this file. A typo here is a bug the tests catch (every literal is
    /// part of `document()`); at run time it degrades to an error marker rather than crashing the server.
    private static func jsonValue(_ text: String) -> JSONValue {
        guard let v = try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)) else {
            return .object(["error": .string("schema literal failed to parse")])
        }
        return v
    }
}
