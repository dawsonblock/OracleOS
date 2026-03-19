import Foundation

// ─────────────────────────────────────────────────────────
// FileSystemAdapter — safe filesystem operations (Phase 8)
//
// All writes go through VerifiedActionExecutor (via ActionRegistry).
// This adapter handles path resolution and safety checks.
// ─────────────────────────────────────────────────────────

public final class FileSystemAdapter {

    private let sandboxRoot: String

    public init(sandboxRoot: String = ".") {
        self.sandboxRoot = sandboxRoot
    }

    /// Resolve a path, ensuring it doesn't escape sandbox root.
    public func resolve(path: String) -> String? {
        let resolved = (sandboxRoot as NSString).appendingPathComponent(path)
        let canonical = (resolved as NSString).standardizingPath
        guard canonical.hasPrefix((sandboxRoot as NSString).standardizingPath) else {
            return nil  // path escape attempt
        }
        return canonical
    }

    public func readFile(path: String) -> String? {
        guard let safe = resolve(path: path) else { return nil }
        return try? String(contentsOfFile: safe, encoding: .utf8)
    }

    public func fileExists(path: String) -> Bool {
        guard let safe = resolve(path: path) else { return false }
        return FileManager.default.fileExists(atPath: safe)
    }
}
