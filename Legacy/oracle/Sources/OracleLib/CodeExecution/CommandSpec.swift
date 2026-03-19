import Foundation

// ─────────────────────────────────────────────────────────
// CommandSpec — typed process execution contract
//
// Every subprocess the runtime launches is described by a
// CommandSpec. Free-form shell strings are forbidden.
//
// Blueprint ref: Gate 1, §1.4
// ─────────────────────────────────────────────────────────

public struct CommandSpec: Codable, Sendable, Equatable {
    public let category: CodeCommandCategory
    public let executable: String
    public let arguments: [String]
    public let workspaceRoot: String
    public let workspaceRelativePath: String?
    public let summary: String
    public let mutatesWorkspace: Bool
    public let touchesNetwork: Bool

    /// Allowlisted environment variable names (only these are forwarded).
    public let allowlistedEnvVars: [String]

    /// Maximum seconds before the process is killed. Zero means no limit.
    public let timeout: TimeInterval

    /// Optional expected outputs for postcondition verification.
    public let expectedOutputs: [String]

    public init(
        category: CodeCommandCategory,
        executable: String,
        arguments: [String],
        workspaceRoot: String,
        workspaceRelativePath: String? = nil,
        summary: String,
        mutatesWorkspace: Bool? = nil,
        touchesNetwork: Bool = false,
        allowlistedEnvVars: [String] = [],
        timeout: TimeInterval = 60,
        expectedOutputs: [String] = []
    ) {
        self.category = category
        self.executable = executable
        self.arguments = arguments
        self.workspaceRoot = workspaceRoot
        self.workspaceRelativePath = workspaceRelativePath
        self.summary = summary
        self.mutatesWorkspace = mutatesWorkspace ?? category.isWrite
        self.touchesNetwork = touchesNetwork
        self.allowlistedEnvVars = allowlistedEnvVars
        self.timeout = timeout
        self.expectedOutputs = expectedOutputs
    }

    /// Resolve the full executable path for `Process()`.
    /// Searches common binary locations if the executable is not absolute.
    public func resolvedExecutableURL() -> URL? {
        if executable.hasPrefix("/") {
            return URL(fileURLWithPath: executable)
        }
        // Search standard binary paths
        let searchPaths = [
            "/usr/bin", "/usr/local/bin", "/opt/homebrew/bin",
            "/usr/sbin", "/bin", "/sbin",
        ]
        for dir in searchPaths {
            let candidate = "\(dir)/\(executable)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }

    /// Build a filtered environment dictionary containing only allowlisted vars.
    public func filteredEnvironment() -> [String: String]? {
        guard !allowlistedEnvVars.isEmpty else { return nil }
        let current = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]
        for key in allowlistedEnvVars {
            if let value = current[key] {
                env[key] = value
            }
        }
        // Always pass PATH for executable resolution
        if env["PATH"] == nil, let path = current["PATH"] {
            env["PATH"] = path
        }
        return env
    }
}
