import Foundation

public enum RuntimeError: Error, LocalizedError, Sendable {
    case invalidPayload
    case unknownCommand(String)
    case unknownEvent(String)
    case policyViolation(String)
    case executionTimedOut(String, Int)
    case serverFailure(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid command payload"
        case let .unknownCommand(type):
            return "Unknown command type: \(type)"
        case let .unknownEvent(type):
            return "Unknown event type: \(type)"
        case let .policyViolation(reason):
            return reason
        case let .executionTimedOut(commandType, milliseconds):
            return "\(commandType) execution timed out after \(milliseconds)ms"
        case let .serverFailure(reason):
            return reason
        }
    }
}
