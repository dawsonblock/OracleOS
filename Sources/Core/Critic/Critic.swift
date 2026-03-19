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
        let writeEvents = events.compactMap { $0 as? FileWriteRequestedEvent }
        let deleteEvents = events.compactMap { $0 as? FileDeleteRequestedEvent }
        let httpEvents = events.compactMap { $0 as? HTTPResponseEvent }
        let failureEvents = events.compactMap { $0 as? CommandFailedEvent }

        if let failure = failureEvents.last, shellEvents.isEmpty, httpEvents.isEmpty, state.files.isEmpty {
            return Evaluation(
                success: false,
                score: 0.0,
                issues: [failure.reason]
            )
        }

        if goalText.hasPrefix("write file ") {
            let target = writeTarget(from: goal.text)
            let success = writeEvents.contains {
                $0.path == target.path && $0.content == target.content
            }
            return Evaluation(
                success: success,
                score: success ? 1.0 : 0.0,
                issues: success ? [] : [state.lastFailure.isEmpty ? "Expected file write did not complete for \(target.path)." : state.lastFailure]
            )
        }

        if goalText.hasPrefix("delete file ") {
            let path = goalPath(from: goal.text, prefix: "delete file ")
            let success = deleteEvents.contains { $0.path == path }
            return Evaluation(
                success: success,
                score: success ? 1.0 : 0.0,
                issues: success ? [] : [state.lastFailure.isEmpty ? "Expected file delete did not complete for \(path)." : state.lastFailure]
            )
        }

        if goalText.hasPrefix("run shell ") || goalText.contains("swift build") || goalText.contains("swift test") {
            let success = shellEvents.contains(where: { $0.status == 0 })
            return Evaluation(
                success: success,
                score: success ? 0.9 : 0.1,
                issues: success ? [] : [failureEvents.last?.reason ?? "Shell goal did not complete successfully."]
            )
        }

        if goalText.hasPrefix("http ") {
            let success = httpEvents.contains(where: { (200..<500).contains($0.status) })
            return Evaluation(
                success: success,
                score: success ? 0.9 : 0.1,
                issues: success ? [] : [failureEvents.last?.reason ?? "HTTP goal did not produce a valid response event."]
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

    private func writeTarget(from text: String) -> (path: String, content: String) {
        let remainder = String(text.dropFirst("write file ".count))
        let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let path = parts.first.map(String.init) ?? "runtime-output.txt"
        let content = parts.count > 1 ? String(parts[1]) : text
        return (path: path, content: content)
    }
}
