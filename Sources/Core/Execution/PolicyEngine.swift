import Foundation

public final class PolicyEngine: Sendable {
    public let policy: ExecutionPolicy

    public init(policy: ExecutionPolicy) {
        self.policy = policy
    }

    public func validate(_ command: Command) throws {
        switch command.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "shell":
            let cmd = command.stringValue(for: "cmd")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let base = cmd.split(separator: " ").first.map(String.init) ?? ""
            guard !cmd.isEmpty else {
                throw RuntimeError.policyViolation("Shell command cannot be empty")
            }
            guard policy.allowedShellCommands.contains(base) else {
                throw RuntimeError.policyViolation("Command not allowed: \(base)")
            }
        case "file.write":
            let path = command.stringValue(for: "path") ?? ""

            guard isPathAllowed(path) else {
                throw RuntimeError.policyViolation("Write path blocked: \(path)")
            }
        case "file.delete":
            let path = command.stringValue(for: "path") ?? ""

            guard isPathAllowed(path) else {
                throw RuntimeError.policyViolation("Delete path blocked: \(path)")
            }
        case "http.request":
            let urlString = command.stringValue(for: "url") ?? ""
            guard let host = URL(string: urlString)?.host,
                  policy.networkWhitelist.contains(host) else {
                throw RuntimeError.policyViolation("Network blocked: \(urlString)")
            }
        default:
            throw RuntimeError.policyViolation("Unknown command")
        }
    }

    private func isPathAllowed(_ path: String) -> Bool {
        guard let candidate = standardizedPath(path) else {
            return false
        }

        return policy.allowedWriteRoots.contains { root in
            guard let normalizedRoot = standardizedPath(root) else {
                return false
            }

            let rootPrefix = normalizedRoot.hasSuffix("/") ? normalizedRoot : normalizedRoot + "/"
            return candidate == normalizedRoot || candidate.hasPrefix(rootPrefix)
        }
    }

    private func standardizedPath(_ rawPath: String) -> String? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let baseURL = URL(fileURLWithPath: ".", isDirectory: true).standardizedFileURL
        let url: URL
        if trimmed.hasPrefix("/") {
            url = URL(fileURLWithPath: trimmed, isDirectory: false)
        } else {
            url = URL(fileURLWithPath: trimmed, relativeTo: baseURL)
        }

        return url.standardizedFileURL.path
    }
}
