import Foundation

public protocol Planner: Sendable {
    func plan(goal: Goal, state: WorldState) -> [Command]
}

public struct BasicPlanner: Planner {
    public init() {}

    public func plan(goal: Goal, state: WorldState) -> [Command] {
        let trimmed = goal.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if lowercased.hasPrefix("write file ") {
            return [planFileWrite(from: trimmed)]
        }

        if lowercased.hasPrefix("delete file ") {
            let path = String(trimmed.dropFirst("delete file ".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return [Command(type: "file.delete", payload: ["path": path])]
        }

        if lowercased.hasPrefix("run shell ") {
            let cmd = String(trimmed.dropFirst("run shell ".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return [Command(type: "shell", payload: ["cmd": cmd])]
        }

        if lowercased.hasPrefix("http ") {
            let url = String(trimmed.dropFirst("http ".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return [Command(type: "http.request", payload: ["url": url, "method": "GET"])]
        }

        if lowercased.contains("swift build") {
            return [Command(type: "shell", payload: ["cmd": "swift build"])]
        }

        if lowercased.contains("swift test") {
            return [Command(type: "shell", payload: ["cmd": "swift test"])]
        }

        let fallbackPath = state.files.isEmpty ? "runtime-goal.log" : "runtime-followup.log"
        return [Command(type: "file.write", payload: ["path": fallbackPath, "content": trimmed])]
    }

    private func planFileWrite(from goalText: String) -> Command {
        let remainder = String(goalText.dropFirst("write file ".count))
        let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let path = parts.first.map(String.init) ?? "runtime-output.txt"
        let content = parts.count > 1 ? String(parts[1]) : goalText

        return Command(
            type: "file.write",
            payload: [
                "path": path,
                "content": content,
            ]
        )
    }
}
