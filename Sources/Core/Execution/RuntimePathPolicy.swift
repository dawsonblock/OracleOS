import Foundation

public enum RuntimePathPolicy {
    public static func validatedURL(for path: String) throws -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RuntimeError.invalidPayload
        }

        let workspaceRoot = workspaceRootURL()
        let candidate: URL
        if trimmed.hasPrefix("/") {
            candidate = URL(fileURLWithPath: trimmed, isDirectory: false).standardizedFileURL
        } else {
            candidate = workspaceRoot.appendingPathComponent(trimmed, isDirectory: false).standardizedFileURL
        }

        guard contains(candidate, in: workspaceRoot) else {
            throw RuntimeError.policyViolation("File commands must stay within the workspace root")
        }

        return candidate
    }

    public static func validatedPath(_ path: String) throws -> String {
        try validatedURL(for: path).path
    }

    private static func workspaceRootURL() -> URL {
        let pwd = ProcessInfo.processInfo.environment["PWD"] ?? "."
        return URL(fileURLWithPath: pwd, isDirectory: true).standardizedFileURL
    }

    private static func contains(_ candidate: URL, in root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path == root.path || candidate.path.hasPrefix(rootPath)
    }
}
