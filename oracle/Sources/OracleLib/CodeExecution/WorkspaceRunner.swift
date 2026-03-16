import Foundation

public enum WorkspaceRunnerError: Error, LocalizedError, Sendable, Equatable {
    case unsupportedCommand(String)
    case scopeViolation(String)
    case forbiddenGitOperation(String)
    case networkNotAllowed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedCommand(let summary):
            return "Unsupported command: \(summary)"
        case .scopeViolation(let message):
            return message
        case .forbiddenGitOperation(let detail):
            return "Forbidden git operation: \(detail)"
        case .networkNotAllowed(let detail):
            return "Network access not allowed: \(detail)"
        }
    }
}

public enum GitAccessLevel: Sendable {
    case readOnly
    case localWrite
    case network
}

public final class WorkspaceRunner: @unchecked Sendable {
    public init() {}

    public func execute(spec: CommandSpec) throws -> CommandResult {
        guard isAllowed(spec) else { throw WorkspaceRunnerError.unsupportedCommand(spec.summary) }
        try validateGitPolicy(spec)
        if derivedTouchesNetwork(spec) {
            throw WorkspaceRunnerError.networkNotAllowed("Command \(spec.category.rawValue) requires network access which is not permitted")
        }

        let scope = try WorkspaceScope(rootURL: URL(fileURLWithPath: spec.workspaceRoot, isDirectory: true))
        _ = try scope.resolve(relativePath: spec.workspaceRelativePath)

        let start = Date()
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: spec.executable)
        process.arguments = spec.arguments
        process.currentDirectoryURL = scope.rootURL
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = sanitizedEnvironment()

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            succeeded: process.terminationStatus == 0,
            exitCode: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            elapsedMs: Date().timeIntervalSince(start) * 1000.0,
            workspaceRoot: spec.workspaceRoot,
            category: spec.category,
            summary: spec.summary
        )
    }

    static let gitSubcommandPolicy: [String: GitAccessLevel] = [
        "status": .readOnly,
        "log": .readOnly,
        "diff": .readOnly,
        "show": .readOnly,
        "branch": .readOnly,
        "rev-parse": .readOnly,
        "ls-files": .readOnly,
        "blame": .readOnly,
        "stash": .localWrite,
        "add": .localWrite,
        "commit": .localWrite,
        "checkout": .localWrite,
        "switch": .localWrite,
        "merge": .localWrite,
        "rebase": .localWrite,
        "reset": .localWrite,
        "restore": .localWrite,
        "tag": .localWrite,
        "push": .network,
        "pull": .network,
        "fetch": .network,
        "clone": .network,
        "remote": .network,
    ]

    static let forbiddenGitFlags: Set<String> = [
        "--force", "-f", "--force-with-lease", "--mirror", "--bare", "--delete", "--prune-tags",
    ]

    static func parseGitSubcommand(from arguments: [String]) -> String? {
        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            if arg == "-C" || arg == "-c" || arg == "--git-dir" || arg == "--work-tree" {
                index += 2
                continue
            }
            if arg.hasPrefix("-") {
                index += 1
                continue
            }
            return arg
        }
        return nil
    }

    private func validateGitPolicy(_ spec: CommandSpec) throws {
        guard spec.category.isGit else { return }
        guard let subcommand = Self.parseGitSubcommand(from: spec.arguments) else {
            throw WorkspaceRunnerError.forbiddenGitOperation("could not parse git subcommand")
        }
        guard Self.gitSubcommandPolicy[subcommand] != nil else {
            throw WorkspaceRunnerError.forbiddenGitOperation("git subcommand '\(subcommand)' is not in the allowed set")
        }

        for arg in spec.arguments where arg.hasPrefix("-") {
            for forbidden in Self.forbiddenGitFlags {
                if arg == forbidden || arg.hasPrefix(forbidden + "=") {
                    throw WorkspaceRunnerError.forbiddenGitOperation("flag '\(arg)' is forbidden on git commands")
                }
                if forbidden.hasPrefix("-"), !forbidden.hasPrefix("--"), forbidden.count == 2, arg.hasPrefix("-"), arg.count > 2 {
                    let shortFlagChar = forbidden.dropFirst()
                    if arg.dropFirst().contains(shortFlagChar) {
                        throw WorkspaceRunnerError.forbiddenGitOperation("flag '\(arg)' is forbidden on git commands")
                    }
                }
            }
        }
    }

    func derivedTouchesNetwork(_ spec: CommandSpec) -> Bool {
        guard spec.category.isGit else { return false }
        guard let subcommand = Self.parseGitSubcommand(from: spec.arguments) else { return false }
        return Self.gitSubcommandPolicy[subcommand] == .network
    }

    private func isAllowed(_ spec: CommandSpec) -> Bool {
        switch spec.category {
        case .build, .test, .formatter, .linter, .gitStatus, .gitBranch, .gitCommit, .gitPush:
            return allowedExecutable(spec.executable)
        case .indexRepository, .searchCode, .openFile, .editFile, .writeFile, .generatePatch, .parseBuildFailure, .parseTestFailure, .search, .lint, .format:
            return true
        }
    }

    private func allowedExecutable(_ executable: String) -> Bool {
        ["/usr/bin/env", "/usr/bin/git"].contains(executable)
    }

    private func sanitizedEnvironment() -> [String: String] {
        let source = ProcessInfo.processInfo.environment
        let keys = ["PATH", "HOME", "LANG", "LC_ALL", "TMPDIR", "DEVELOPER_DIR"]
        return Dictionary(uniqueKeysWithValues: keys.compactMap { key in source[key].map { (key, $0) } })
    }
}
