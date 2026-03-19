import Foundation

public final class CommandResolver: Sendable {
    public init() {}

    public func normalize(_ commands: [Command]) -> [Command] {
        commands.map { command in
            let normalizedType = command.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            var payload = command.payload

            switch normalizedType {
            case "file.write":
                if (payload["path"] ?? "").isEmpty {
                    payload["path"] = "runtime-output.txt"
                }
                payload["content"] = payload["content"] ?? ""
            case "http.request":
                payload["method"] = (payload["method"] ?? "GET").uppercased()
            default:
                break
            }

            return Command(id: command.id, type: normalizedType, payload: payload)
        }
    }
}
