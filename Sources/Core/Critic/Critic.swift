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

public struct BasicCritic: Critic {
    public init() {}

    public func evaluate(goal: Goal, events: [any DomainEvent], state: WorldState) -> Evaluation {
        let goalText = goal.text.lowercased()

        if goalText.hasPrefix("write file ") {
            let path = goalPath(from: goal.text, prefix: "write file ")
            let success = state.files[path] != nil
            return Evaluation(
                success: success,
                score: success ? 1.0 : 0.0,
                issues: success ? [] : ["Expected file write did not reach reducer state for \(path)."]
            )
        }

        if goalText.hasPrefix("delete file ") {
            let path = goalPath(from: goal.text, prefix: "delete file ")
            let success = state.files[path] == nil
            return Evaluation(
                success: success,
                score: success ? 1.0 : 0.0,
                issues: success ? [] : ["Expected file delete did not reach reducer state for \(path)."]
            )
        }

        if goalText.hasPrefix("run shell ") || goalText.contains("swift build") || goalText.contains("swift test") {
            let success = !state.lastOutput.isEmpty || !events.isEmpty
            return Evaluation(
                success: success,
                score: success ? 0.9 : 0.1,
                issues: success ? [] : ["Shell goal produced no observable output."]
            )
        }

        if goalText.hasPrefix("http ") {
            let success = state.lastHTTPResponseSize >= 0 && !events.isEmpty
            return Evaluation(
                success: success,
                score: success ? 0.9 : 0.1,
                issues: success ? [] : ["HTTP goal produced no observable response event."]
            )
        }

        let success = !state.files.isEmpty || !state.lastOutput.isEmpty || state.lastHTTPResponseSize > 0
        return Evaluation(
            success: success,
            score: success ? 0.8 : 0.2,
            issues: success ? [] : ["Goal produced no durable events or state changes."]
        )
    }

    private func goalPath(from text: String, prefix: String) -> String {
        let remainder = String(text.dropFirst(prefix.count))
        let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        return parts.first.map(String.init) ?? "runtime-output.txt"
    }
}
