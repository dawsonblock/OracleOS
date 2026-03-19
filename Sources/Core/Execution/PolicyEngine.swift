import Foundation

public final class PolicyEngine: Sendable {
    public init() {}

    public func validate(_ command: Command) throws {
        switch command.type {
        case "shell":
            let cmd = command.payload["cmd"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !cmd.isEmpty else {
                throw RuntimeError.invalidPayload
            }
            _ = try validatedTimeoutMillis(command.payload["timeout_ms"])
        case "file.write":
            let path = command.payload["path"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !path.isEmpty, command.payload["content"] != nil else {
                throw RuntimeError.invalidPayload
            }
            _ = try RuntimePathPolicy.validatedURL(for: path)
        case "file.delete":
            let path = command.payload["path"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !path.isEmpty else {
                throw RuntimeError.invalidPayload
            }
            _ = try RuntimePathPolicy.validatedURL(for: path)
        case "http.request":
            let url = command.payload["url"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
                throw RuntimeError.policyViolation("HTTP commands require an explicit http(s) URL")
            }
            _ = try validatedTimeoutMillis(command.payload["timeout_ms"])
        default:
            throw RuntimeError.unknownCommand(command.type)
        }
    }

    public func validatedTimeoutMillis(_ rawValue: String?) throws -> Int {
        guard let rawValue, !rawValue.isEmpty else {
            return ExecutionPolicyLimits.defaultTimeoutMillis
        }

        guard let parsed = Int(rawValue), parsed > 0 else {
            throw RuntimeError.invalidPayload
        }

        guard parsed <= ExecutionPolicyLimits.maximumTimeoutMillis else {
            throw RuntimeError.policyViolation(
                "Execution timeout exceeds maximum allowed value of \(ExecutionPolicyLimits.maximumTimeoutMillis)ms"
            )
        }

        return parsed
    }
}
