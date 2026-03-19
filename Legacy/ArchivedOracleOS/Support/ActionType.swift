// Placeholder to ensure the module compiles once we start redirecting imports.
// This is Phase 1 (hardening) - we've already split out the major types.
public enum ActionType: String, Codable, Sendable {
    case uiAction
    case fileAction
    case shellAction
    case toolAction
    case perception
}

public struct Effect: Codable, Sendable {
    public let type: ActionType
    public let description: String
    public init(type: ActionType, description: String) {
        self.type = type
        self.description = description
    }
}
