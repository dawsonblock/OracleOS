import Foundation

// ─────────────────────────────────────────────────────────
// ActionIntent — the unit of work the executor processes
//
// Every world-changing action is represented as an intent.
// Intents carry typed parameters and a domain tag for routing.
// ─────────────────────────────────────────────────────────

public enum ActionDomain: String {
    case system     // internal runtime ops
    case host       // macOS UI control
    case browser    // web automation
    case code       // code editing, builds, tests
    case search     // web search, discovery
    case tool       // registered tools (git, shell, etc.)
}

public struct ActionIntent {

    public let id: String
    public let type: String
    public let domain: ActionDomain
    public let parameters: [String: String]
    public let createdAt: Date

    public init(
        type: String,
        domain: ActionDomain = .system,
        parameters: [String: String] = [:],
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.type = type
        self.domain = domain
        self.parameters = parameters
        self.createdAt = Date()
    }
}
