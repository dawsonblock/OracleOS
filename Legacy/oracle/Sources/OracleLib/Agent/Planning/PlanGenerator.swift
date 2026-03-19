import Foundation

// ─────────────────────────────────────────────────────────
// PlanGenerator — the single planner entry point
//
// R1: The runtime calls exactly one planner API.
// All plan generators (reasoning, LLM, graph search) are
// internal helpers consumed by PlanGenerator, never called
// directly from the runtime.
//
// Pipeline:
//   goal + context → decompose → sequence → simulate → evaluate → plan
// ─────────────────────────────────────────────────────────

public struct Plan {

    public let id: String
    public let actions: [ActionIntent]
    public let goalID: String
    public let confidence: Double

    public init(
        actions: [ActionIntent],
        goalID: String = "",
        confidence: Double = 1.0,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.actions = actions
        self.goalID = goalID
        self.confidence = confidence
    }

    public static let empty = Plan(actions: [], goalID: "", confidence: 0)
}

// ─────────────────────────────────────────────────────────
// PlanningContext — what the planner reads
// ─────────────────────────────────────────────────────────

public struct PlanningContext {

    public let goal: Goal
    public let recentActions: [ExecutionTrace]
    public let memoryHints: [String]
    public let codeContext: [String]
    public let webContext: [String]

    public static func from(goal: Goal, assembledContext: String, recentTraces: [ExecutionTrace] = []) -> PlanningContext {
        return PlanningContext(
            goal: goal,
            recentActions: recentTraces,
            memoryHints: [assembledContext],
            codeContext: [],
            webContext: []
        )
    }
}

// ─────────────────────────────────────────────────────────
// PlanGenerator
// ─────────────────────────────────────────────────────────

public final class PlanGenerator {

    public let decomposer = ActionDecomposer()
    public let reducer = GoalReducer()
    public let simulator = PlanSimulator()
    public let evaluator = PlanEvaluator()

    public init() {}

    public func generate(goal: Goal, context: String = "", recentTraces: [ExecutionTrace] = []) -> Plan {

        // 0. Reduce compound goals into atomic sub-goals
        let subGoals = reducer.reduce(goal: goal)

        // 1. Decompose each sub-goal into action sequences
        var allActions: [ActionIntent] = []
        for subGoal in subGoals {
            let planContext = PlanningContext.from(goal: subGoal, assembledContext: context, recentTraces: recentTraces)
            let actions = decomposer.decompose(context: planContext)
            allActions.append(contentsOf: actions)
        }

        // 2. Build candidate plan
        let candidate = Plan(
            actions: allActions,
            goalID: goal.id,
            confidence: 0.8
        )

        // 3. Simulate (dry run) — uses first sub-goal context for trace history
        let simContext = PlanningContext.from(goal: goal, assembledContext: context, recentTraces: recentTraces)
        let simResult = simulator.simulate(plan: candidate, context: simContext)
        guard simResult.feasible else {
            print("[planner] Plan simulation failed — returning empty plan")
            return Plan.empty
        }

        // 4. Evaluate/rank
        let scored = evaluator.score(plan: candidate, simulation: simResult)

        print("[planner] Generated plan with \(scored.actions.count) actions (confidence: \(scored.confidence))")

        return scored
    }
}

// ─────────────────────────────────────────────────────────
// ActionDecomposer — break goals into action sequences
//
// Classifies goal intent via keyword heuristics, then emits
// a structured action sequence appropriate for the domain.
// Phase 3+: LLM replaces keyword matching; graph-backed
// step retrieval augments the sequence.
// ─────────────────────────────────────────────────────────

public final class ActionDecomposer {

    public init() {}

    // ── Intent classification ───────────────────────────

    public enum GoalIntent: String {
        case readFile        // "read", "show", "display", "cat", "view"
        case writeFile       // "write", "create file", "save"
        case editCode        // "edit", "refactor", "fix", "modify", "change"
        case buildProject    // "build", "compile"
        case runTests        // "test", "run tests", "verify"
        case search          // "search", "find", "look up", "query"
        case browse          // "browse", "open url", "navigate", "visit"
        case shellCommand    // "run", "execute", "shell", "command"
        case analyze         // "analyze", "inspect", "check", "audit", "review"
        case plan            // "plan", "think", "strategy", "outline"
        case unknown
    }

    public func classify(goal: Goal) -> GoalIntent {
        let desc = goal.description.lowercased()

        // Ordered by specificity — more specific patterns first
        let patterns: [(GoalIntent, [String])] = [
            (.runTests,     ["run tests", "run test", "swift test", "test suite", "verify tests"]),
            (.buildProject, ["build", "compile", "swift build"]),
            (.editCode,     ["edit", "refactor", "fix", "modify code", "change code", "patch", "update code"]),
            (.writeFile,    ["write file", "create file", "save file", "write to"]),
            (.readFile,     ["read file", "read", "show file", "cat ", "display", "view file", "open file"]),
            (.search,       ["search", "find", "look up", "lookup", "query", "grep"]),
            (.browse,       ["browse", "open url", "navigate", "visit", "http"]),
            (.shellCommand, ["run command", "execute", "shell", "command"]),
            (.analyze,      ["analyze", "inspect", "check", "audit", "review", "examine"]),
            (.plan,         ["plan", "think", "strategy", "outline", "break down"]),
        ]

        for (intent, keywords) in patterns {
            for keyword in keywords {
                if desc.contains(keyword) { return intent }
            }
        }

        return .unknown
    }

    // ── Decomposition ───────────────────────────────────

    public func decompose(context: PlanningContext) -> [ActionIntent] {
        let intent = classify(goal: context.goal)
        let desc = context.goal.description

        switch intent {

        case .readFile:
            let path = extractPath(from: desc) ?? "/tmp/unknown"
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Reading file: \(path)"
                ]),
                ActionIntent(type: "read_file", domain: .code, parameters: [
                    "path": path
                ]),
            ]

        case .writeFile:
            let path = extractPath(from: desc) ?? "/tmp/output"
            let content = extractQuoted(from: desc) ?? ""
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Writing to: \(path)"
                ]),
                ActionIntent(type: "write_file", domain: .code, parameters: [
                    "path": path,
                    "content": content,
                ]),
            ]

        case .editCode:
            let path = extractPath(from: desc) ?? ""
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Edit operation: \(desc)"
                ]),
                ActionIntent(type: "read_file", domain: .code, parameters: [
                    "path": path
                ]),
                ActionIntent(type: "write_file", domain: .code, parameters: [
                    "path": path,
                    "content": "// Phase 3+: LLM-generated edit"
                ]),
            ]

        case .buildProject:
            let workspace = extractPath(from: desc) ?? "."
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Building project in: \(workspace)"
                ]),
                ActionIntent(type: "shell_command", domain: .tool, parameters: [
                    "command": "swift build",
                    "workspace": workspace,
                ]),
            ]

        case .runTests:
            let workspace = extractPath(from: desc) ?? "."
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Running tests in: \(workspace)"
                ]),
                ActionIntent(type: "run_tests", domain: .code, parameters: [
                    "command": "swift test",
                    "workspace": workspace,
                ]),
            ]

        case .search:
            let query = desc
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Searching: \(query)"
                ]),
                ActionIntent(type: "search_query", domain: .search, parameters: [
                    "query": query
                ]),
            ]

        case .browse:
            let url = extractURL(from: desc) ?? "https://example.com"
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Browsing: \(url)"
                ]),
                ActionIntent(type: "browser_navigate", domain: .browser, parameters: [
                    "url": url
                ]),
            ]

        case .shellCommand:
            let command = extractQuoted(from: desc) ?? desc
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Executing: \(command)"
                ]),
                ActionIntent(type: "shell_command", domain: .tool, parameters: [
                    "command": command
                ]),
            ]

        case .analyze:
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Analyzing: \(desc)"
                ]),
                ActionIntent(type: "list_directory", domain: .code, parameters: [
                    "path": extractPath(from: desc) ?? "."
                ]),
            ]

        case .plan:
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Planning: \(desc)"
                ]),
            ]

        case .unknown:
            // Fallback: emit a cautious log-only action
            return [
                ActionIntent(type: "log", domain: .system, parameters: [
                    "message": "Processing: \(desc)"
                ]),
            ]
        }
    }

    // ── Extraction helpers ──────────────────────────────

    private func extractPath(from text: String) -> String? {
        // Match common path patterns: /foo/bar, ./foo, ~/foo
        let patterns = [
            "(?:^|\\s)(/[\\w./-]+)",
            "(?:^|\\s)(\\./[\\w./-]+)",
            "(?:^|\\s)(~/[\\w./-]+)",
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                return String(text[match]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func extractURL(from text: String) -> String? {
        if let match = text.range(of: "https?://[^\\s]+", options: .regularExpression) {
            return String(text[match])
        }
        return nil
    }

    private func extractQuoted(from text: String) -> String? {
        if let match = text.range(of: "\"[^\"]+\"", options: .regularExpression) {
            var s = String(text[match])
            s.removeFirst()
            s.removeLast()
            return s
        }
        return nil
    }
}

// ─────────────────────────────────────────────────────────
// GoalReducer — simplify compound goals
//
// Splits compound goals (joined by "and", "then", ";")
// into atomic sub-goals that the decomposer handles individually.
// ─────────────────────────────────────────────────────────

public final class GoalReducer {

    public init() {}

    public func reduce(goal: Goal) -> [Goal] {
        let desc = goal.description

        // Split on common conjunctions/separators
        let separators = [" and then ", " then ", " and ", "; "]
        for sep in separators {
            if desc.lowercased().contains(sep) {
                let parts = desc.components(separatedBy: sep)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if parts.count > 1 {
                    return parts.map { Goal(description: $0, priority: goal.priority) }
                }
            }
        }

        return [goal]
    }
}
