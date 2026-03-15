import Foundation

// ─────────────────────────────────────────────────────────
// GoalClassifier — infer AgentKind from a goal description
//
// Scans the goal text for keyword signals and returns the
// most likely kind of agent work needed. The classifier is
// intentionally conservative: unknown goals default to .ui
// rather than code because OS actions are lower risk.
// ─────────────────────────────────────────────────────────

/// Classifies a natural-language goal description into an `AgentKind`.
public enum GoalClassifier {

    // Keywords that signal code / engineering work.
    private static let codeSignals: [String] = [
        "fix", "build", "test", "compile", "refactor",
        "repository", "repo", "patch", "commit", "branch",
        "push", "pull", "lint", "format", "debug", "error",
        "swift", "xcode", "gradle", "npm", "cargo", "make",
        "deploy", "release", "merge", "diff", "coverage",
    ]

    // Keywords that signal macOS UI / OS interaction.
    private static let uiSignals: [String] = [
        "open", "click", "focus", "browser", "finder",
        "slack", "mail", "download", "upload", "window",
        "tab", "app", "drag", "scroll", "type", "press",
        "safari", "chrome", "screenshot", "menu", "dock",
    ]

    /// Classify a goal description into an `AgentKind`.
    ///
    /// - Parameters:
    ///   - description: The natural-language goal text.
    ///   - workspaceRoot: When non-nil, a workspace is present and
    ///     code-signal matches are weighted more heavily.
    /// - Returns: The inferred `AgentKind`.
    public static func classify(
        description: String,
        workspaceRoot: String? = nil
    ) -> AgentKind {
        let lower = description.lowercased()
        let codeMatches = codeSignals.filter { lower.contains($0) }.count
        let uiMatches   = uiSignals.filter   { lower.contains($0) }.count

        if codeMatches > 0 && uiMatches > 0 {
            return .mixed
        }
        if codeMatches > 0 || workspaceRoot != nil && codeMatches > 0 {
            return .code
        }
        if uiMatches > 0 {
            return .ui
        }
        // Default: treat as UI (lower-risk default).
        return .ui
    }
}
