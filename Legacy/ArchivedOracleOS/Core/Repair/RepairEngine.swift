import Foundation

public final class RepairEngine: Sendable {
    public init() {}

    public func proposeFixes(evaluation: Evaluation) -> [Command] {
        guard !evaluation.success else { return [] }

        return [
            Command(
                type: "file.write",
                payload: [
                    "path": "fix.log",
                    "content": evaluation.issues.joined(separator: "\n"),
                ]
            )
        ]
    }
}
