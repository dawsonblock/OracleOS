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
        let shellEvents = events.compactMap { $0 as? ShellExecutedEvent }
        let httpEvents = events.compactMap { $0 as? HTTPResponseEvent }

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
            let success = shellEvents.contains(where: { $0.status == 0 })
            return Evaluation(
                success: success,
                score: success ? 0.9 : 0.1,
                issues: success ? [] : ["Shell goal did not complete successfully."]
            )
        }

        if goalText.hasPrefix("http ") {
            let success = httpEvents.contains(where: { (200..<500).contains($0.status) })
            return Evaluation(
                success: success,
                score: success ? 0.9 : 0.1,
                issues: success ? [] : ["HTTP goal did not produce a valid response event."]
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
