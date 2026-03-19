import Foundation

public final class CommandResolver: Sendable {
    public init() {}

    public func normalize(_ commands: [Command]) -> [Command] {
        commands.map { command in
            let normalizedType = command.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            var payload = command.payload

            switch normalizedType {
            case "shell":
                payload["cmd"] = payload["cmd"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                payload["timeout_ms"] = normalizedTimeoutMillis(payload["timeout_ms"])
            case "file.write":
                let path = payload["path"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if path.isEmpty {
                    payload["path"] = "runtime-output.txt"
                } else {
                    payload["path"] = path
                }
                payload["content"] = payload["content"] ?? ""
            case "file.delete":
                let path = payload["path"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                payload["path"] = path
            case "http.request":
                payload["url"] = payload["url"]?.trimmingCharacters(in: .whitespacesAndNewlines)
                payload["method"] = (payload["method"] ?? "GET").uppercased()
                payload["timeout_ms"] = normalizedTimeoutMillis(payload["timeout_ms"])
            default:
                break
            }

            return Command(id: command.id, type: normalizedType, payload: payload)
        }
    }

    private func normalizedTimeoutMillis(_ rawValue: String?) -> String {
        guard let rawValue,
              let parsed = Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              parsed > 0
        else {
            return String(ExecutionPolicyLimits.defaultTimeoutMillis)
        }

        return String(min(parsed, ExecutionPolicyLimits.maximumTimeoutMillis))
    }
}
