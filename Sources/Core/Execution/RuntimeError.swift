import Foundation

public enum RuntimeError: Error, LocalizedError, Sendable {
    case unknownCommand
    case unknownEvent(String)
    case policyViolation(String)
    case timeout
    case invalidURL
    case serverFailure(String)

    public var errorDescription: String? {
        switch self {
        case .unknownCommand:
            return "Unknown command"
        case let .unknownEvent(type):
            return "Unknown event type: \(type)"
        case let .policyViolation(reason):
            return reason
        case .timeout:
            return "Execution timed out"
        case .invalidURL:
            return "Invalid URL"
        case let .serverFailure(reason):
            return reason
        }
    }
}
