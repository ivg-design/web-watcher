import Foundation

/// The identity an installed MCP client sends notifications under (issue #62): `agent.claude-code`,
/// `agent.codex`, `agent.claude-desktop`, `agent.<slug>`. Herald registers the app and its manifest when the client
/// is installed from Settings > MCP, and writes `--agent <slug>` into the server's configuration; `herald-mcp` then
/// uses that app whenever a tool call leaves `app` out.
public enum HeraldAgent {
    public static let prefix = "agent."

    /// A slug from a name the user typed: lower case letters, digits and hyphens ("My Bot!" gives "my-bot").
    public static func slug(_ name: String) -> String {
        var out = ""
        var lastDash = true
        for ch in name.lowercased() {
            if ch.isASCII, ch.isLetter || ch.isNumber { out.append(ch); lastDash = false }
            else if !lastDash { out.append("-"); lastDash = true }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return String(out.prefix(48))
    }

    /// The app id for `--agent` or `HERALD_AGENT`: `claude-code` and `agent.claude-code` both give `agent.claude-code`.
    /// nil when nothing usable is left.
    public static func appID(from value: String) -> String? {
        var v = value.trimmingCharacters(in: .whitespaces)
        if v.lowercased().hasPrefix(prefix) { v = String(v.dropFirst(prefix.count)) }
        let s = slug(v)
        return s.isEmpty ? nil : prefix + s
    }
}
