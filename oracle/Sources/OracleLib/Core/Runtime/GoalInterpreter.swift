import Foundation

// ─────────────────────────────────────────────────────────
// Goal — the unit of work the runtime processes
// ─────────────────────────────────────────────────────────

public struct Goal {

    public let id: String
    public let description: String
    public let priority: GoalPriority
    public let createdAt: Date
    /// Optional target application name for OS-level goals.
    public let targetApp: String?
    /// Optional target URL domain for browser goals.
    public let targetDomain: String?

    public init(
        description: String,
        priority: GoalPriority = .normal,
        id: String = UUID().uuidString,
        targetApp: String? = nil,
        targetDomain: String? = nil
    ) {
        self.id = id
        self.description = description
        self.priority = priority
        self.createdAt = Date()
        self.targetApp = targetApp
        self.targetDomain = targetDomain
    }
}

public enum GoalPriority: String {
    case low
    case normal
    case high
    case critical
}

// ─────────────────────────────────────────────────────────
// GoalInterpreter — receives goals from external surfaces
//
// Surfaces (future):
//   • CLI
//   • MCP commands
//   • UI controller
//   • Recipe triggers
//   • Network/voice input
// ─────────────────────────────────────────────────────────

public final class GoalInterpreter {

    private static var pendingGoals: [Goal] = []

    public static func enqueue(_ goal: Goal) {
        pendingGoals.append(goal)
    }

    public static func nextGoal() -> Goal? {
        guard !pendingGoals.isEmpty else { return nil }
        return pendingGoals.removeFirst()
    }

    public static func hasPendingGoals() -> Bool {
        return !pendingGoals.isEmpty
    }
}
