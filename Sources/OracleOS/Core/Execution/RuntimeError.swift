import Foundation

public enum RuntimeError: Error, LocalizedError, Sendable {
    case invalidPayload
    case unknownCommand(String)
    case unknownEvent(String)
    case policyViolation(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid command payload"
        case let .unknownCommand(type):
            return "Unknown command: \(type)"
        case let .unknownEvent(type):
            return "Unknown event: \(type)"
        case let .policyViolation(reason):
            return reason
        }
    }
}
