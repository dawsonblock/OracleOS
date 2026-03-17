import Foundation

/// Validates command parameters, safety constraints, and permissions before execution.
public final class CommandValidator: Sendable {
    public enum ValidationResult: Sendable {
        case valid
        case invalid(reason: String, failureType: ExecutionFailureType)
    }

    public init() {}

    /// Perform pre-flight validation on an ActionCommand.
    public func validate(_ command: ActionCommand) -> ValidationResult {
        // 1. Check for required parameters based on action type.
        if command.intent.app.isEmpty {
            return .invalid(reason: "Command 'app' field is empty.", failureType: .preconditionViolation)
        }

        // 2. Validate action-specific constraints.
        switch command.intent.action {
        case "click" where command.intent.x == nil && command.intent.domID == nil && command.intent.query == nil:
            return .invalid(reason: "Click action requires at least one target identifier (x/y, domID, or query).", failureType: .preconditionViolation)
        case "type" where command.intent.text == nil:
             return .invalid(reason: "Type action requires 'text' parameter.", failureType: .preconditionViolation)
        default:
            break
        }

        // 3. Check for timeout sanity.
        if command.timeout <= 0 {
            return .invalid(reason: "Execution timeout must be greater than zero.", failureType: .preconditionViolation)
        }

        // 4. (Extension point) check for permission levels and policy prerequisites.
        
        return .valid
    }
}
