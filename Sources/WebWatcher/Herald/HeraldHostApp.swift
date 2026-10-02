import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// The application an agent's "Open" button brings to the front: the host the agent runs in. Claude Desktop is
/// `Claude.app`; Claude Code and Codex run in a terminal or an editor, which is found when the MCP client is
/// installed from the environment of the process that asked (`TERM_PROGRAM`, `__CFBundleIdentifier`, the chain
/// of parent processes), falling back to Terminal.app. The answer is written as the agent manifest's
/// `appBundleId`, which the `openApp` action reads; the user can change it to any application in Settings > MCP.
public enum HeraldHostApp {
    public static let terminalBundleID = "com.apple.Terminal"
    public static let claudeDesktopBundleID = "com.anthropic.claudefordesktop"

    /// `TERM_PROGRAM` values and the application they mean. VS Code and Cursor both say `vscode`; their
    /// `__CFBundleIdentifier` tells them apart, so that is read first.
    public static let termPrograms: [String: String] = [
        "iTerm.app": "com.googlecode.iterm2",
        "Apple_Terminal": "com.apple.Terminal",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "ghostty": "com.mitchellh.ghostty",
        "vscode": "com.microsoft.VSCode",
        "WezTerm": "com.github.wez.wezterm",
        "Hyper": "co.zeit.hyper",
        "kitty": "net.kovidgoyal.kitty",
        "Alacritty": "org.alacritty",
    ]

    /// Where the agent is running, as a bundle id. `ancestors` are the executable paths of the parent processes,
    /// nearest first (`ancestorExecutables()`); `bundleIDAt` reads an `.app`'s identifier.
    public static func detect(environment: [String: String], ancestors: [String] = [],
                              bundleIDAt: (String) -> String? = HeraldHostApp.bundleIdentifier(ofApp:)) -> String {
        func clean(_ s: String?) -> String? {
            guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, HeraldManifest.isBundleId(t),
                  !t.hasPrefix("com.ivg.herald") else { return nil }
            return t
        }
        if let b = clean(environment["__CFBundleIdentifier"]) { return b }
        if let program = environment["TERM_PROGRAM"], let b = clean(termPrograms[program]) { return b }
        for exe in ancestors {
            if let app = appBundlePath(inExecutable: exe), let b = clean(bundleIDAt(app)) { return b }
        }
        return terminalBundleID
    }

    /// `/Applications/iTerm.app` from `/Applications/iTerm.app/Contents/MacOS/iTerm2`; nil for a path outside an application.
    public static func appBundlePath(inExecutable path: String) -> String? {
        guard path.hasPrefix("/"), let r = path.range(of: ".app/") else {
            return path.hasPrefix("/") && path.hasSuffix(".app") ? path : nil
        }
        return String(path[path.startIndex..<path.index(before: r.upperBound)])
    }

    public static func bundleIdentifier(ofApp path: String) -> String? {
        NSDictionary(contentsOfFile: path + "/Contents/Info.plist")?["CFBundleIdentifier"] as? String
    }

    /// The executable paths of this process's parents, nearest first.
    public static func ancestorExecutables(limit: Int = 16) -> [String] {
        #if canImport(Darwin)
        var out: [String] = []
        var pid = getppid()
        while pid > 1, out.count < limit {
            var buf = [CChar](repeating: 0, count: 4096)
            if proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 { out.append(String(cString: buf)) }
            var info = kinfo_proc(), size = MemoryLayout<kinfo_proc>.stride
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
            guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { break }
            let parent = info.kp_eproc.e_ppid
            if parent == pid { break }
            pid = parent
        }
        return out
        #else
        return []
        #endif
    }

    /// The host of the current process, from its own environment and parents.
    public static func detectCurrent() -> String {
        detect(environment: ProcessInfo.processInfo.environment, ancestors: ancestorExecutables())
    }

    /// What a "Opens:" value means: a bundle id (`com.example.App`) or an application path (`/Applications/X.app`, `~` expanded).
    public enum Target: Equatable, Sendable {
        case bundleId(String)
        case path(String)
    }

    public static func parseTarget(_ value: String) -> Target? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if t.lowercased().hasSuffix(".app") || t.hasPrefix("/") || t.hasPrefix("~") {
            return t.lowercased().hasSuffix(".app") ? .path((t as NSString).expandingTildeInPath) : nil
        }
        return HeraldManifest.isBundleId(t) ? .bundleId(t) : nil
    }
}
