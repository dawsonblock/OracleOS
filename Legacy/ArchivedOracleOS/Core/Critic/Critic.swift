import Foundation

public protocol Critic: Sendable {
    func evaluate(goal: Goal, events: [any DomainEvent], state: WorldState) -> Evaluation
}

public struct Evaluation: Sendable, Equatable {
    public let success: Bool
    public let score: Double
    public let issues: [String]

    public init(success: Bool, score: Double, issues: [String]) {
        self.success = success
        self.score = score
        self.issues = issues
    }
}

public final class BasicCritic: Critic, @unchecked Sendable {
    public init() {}

    public func evaluate(goal: Goal, events: [any DomainEvent], state: WorldState) -> Evaluation {
        if state.files.isEmpty && (state.lastOutput?.isEmpty ?? true) {
            return Evaluation(
                success: false,
                score: 0.2,
                issues: ["No durable output generated for goal: \(goal.description)"]
            )
        }

        return Evaluation(success: true, score: 0.9, issues: [])
    }
}
