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
        case "file.write":
            let path = command.payload["path"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !path.isEmpty, command.payload["content"] != nil else {
                throw RuntimeError.invalidPayload
            }
        case "file.delete":
            let path = command.payload["path"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !path.isEmpty else {
                throw RuntimeError.invalidPayload
            }
        case "http.request":
            let url = command.payload["url"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
                throw RuntimeError.policyViolation("HTTP commands require an explicit http(s) URL")
            }
        default:
            throw RuntimeError.unknownCommand(command.type)
        }
    }
}
