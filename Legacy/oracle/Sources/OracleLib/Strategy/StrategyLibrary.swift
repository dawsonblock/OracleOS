import Foundation

// ─────────────────────────────────────────────────────────
// StrategyLibrary — task strategy catalogue and operator family map
//
// `TaskStrategy` is the per-strategy descriptor.
// `StrategyLibrary` provides:
//   • allowedFamilies(for:) — canonical StrategyKind → OperatorFamily mapping
//   • defaultLibrary()      — built-in strategy catalogue
//
// Architecture rule: planners must not generate actions outside
// the operator families allowed by the current SelectedStrategy.
// ─────────────────────────────────────────────────────────

// MARK: – TaskStrategyKind

/// Legacy task strategy kinds — maps 1:1 to canonical `StrategyKind`.
public enum TaskStrategyKind: String, CaseIterable {
    case workflowReuse = "workflow_reuse"
    case codeRepair = "code_repair"
    case uiExploration = "ui_exploration"
    case configurationDiagnosis = "configuration_diagnosis"
    case dependencyRepair = "dependency_repair"
    case buildFix = "build_fix"
    case testFix = "test_fix"
    case navigation = "navigation"
    case recovery = "recovery"

    /// Canonical `StrategyKind` for this legacy kind.
    public var strategyKind: StrategyKind {
        switch self {
        case .workflowReuse:          return .workflowExecution
        case .codeRepair:             return .repoRepair
        case .uiExploration:          return .browserInteraction
        case .configurationDiagnosis: return .diagnosticAnalysis
        case .dependencyRepair:       return .repoRepair
        case .buildFix:               return .repoRepair
        case .testFix:                return .repoRepair
        case .navigation:             return .graphNavigation
        case .recovery:               return .recoveryMode
        }
    }
}

// MARK: – TaskStrategy

/// A high-level approach the agent can adopt for a task.
///
/// The strategy layer sits above the planner and constrains which
/// planning operators are considered.
public struct TaskStrategy {

    public let kind: TaskStrategyKind
    public let description: String
    public let applicableAgentKinds: [AgentKind]
    public let requiredConditions: [StrategyCondition]
    public let priorityScore: Double
    public let notes: [String]

    public init(
        kind: TaskStrategyKind,
        description: String,
        applicableAgentKinds: [AgentKind] = [.ui, .code, .mixed],
        requiredConditions: [StrategyCondition] = [],
        priorityScore: Double = 0.5,
        notes: [String] = []
    ) {
        self.kind = kind
        self.description = description
        self.applicableAgentKinds = applicableAgentKinds
        self.requiredConditions = requiredConditions
        self.priorityScore = priorityScore
        self.notes = notes
    }
}

// MARK: – StrategyLibrary

/// Strategy–operator family mapping and built-in catalogue.
public enum StrategyLibrary {

    // MARK: – Operator family gate (canonical)

    /// Returns the operator families allowed for a given `StrategyKind`.
    ///
    /// This is the key control constraint: plan generation and graph expansion
    /// only consider families returned here.
    public static func allowedFamilies(for kind: StrategyKind) -> [OperatorFamily] {
        switch kind {
        case .workflowExecution:
            return [.workflow, .graphEdge, .recovery]
        case .repoRepair:
            return [.repoAnalysis, .patchGeneration, .patchExperiment, .llmProposal, .recovery]
        case .browserInteraction:
            return [.browserTargeted, .llmProposal, .recovery]
        case .permissionResolution:
            return [.permissionHandling, .hostTargeted, .recovery]
        case .recoveryMode:
            return [.recovery, .graphEdge]
        case .experimentMode:
            return [.patchExperiment, .repoAnalysis, .recovery]
        case .graphNavigation:
            return [.graphEdge, .workflow, .recovery]
        case .diagnosticAnalysis:
            return [.repoAnalysis, .llmProposal]
        case .directExecution:
            return [.hostTargeted, .browserTargeted, .graphEdge]
        }
    }

    // MARK: – Default catalogue

    /// The built-in strategy catalogue used by `StrategySelector`.
    public static func defaultLibrary() -> [TaskStrategy] {
        return [
            TaskStrategy(
                kind: .workflowReuse,
                description: "Replay a previously successful workflow",
                applicableAgentKinds: [.ui, .code, .mixed],
                requiredConditions: [.workflowAvailable],
                priorityScore: 0.95,
                notes: ["Highest confidence — replay proven sequences"]
            ),
            TaskStrategy(
                kind: .buildFix,
                description: "Fix a failing build",
                applicableAgentKinds: [.code, .mixed],
                requiredConditions: [.repositoryOpen, .buildFailing],
                priorityScore: 0.85,
                notes: ["Parse build output → localise → patch → verify"]
            ),
            TaskStrategy(
                kind: .testFix,
                description: "Fix failing unit tests",
                applicableAgentKinds: [.code, .mixed],
                requiredConditions: [.repositoryOpen, .testsFailing],
                priorityScore: 0.85,
                notes: ["Parse test output → localise → patch → re-run"]
            ),
            TaskStrategy(
                kind: .codeRepair,
                description: "General code repair (lint, refactor, format)",
                applicableAgentKinds: [.code, .mixed],
                requiredConditions: [.repositoryOpen],
                priorityScore: 0.75
            ),
            TaskStrategy(
                kind: .dependencyRepair,
                description: "Resolve dependency or import issues",
                applicableAgentKinds: [.code, .mixed],
                requiredConditions: [.repositoryOpen],
                priorityScore: 0.75
            ),
            TaskStrategy(
                kind: .configurationDiagnosis,
                description: "Diagnose configuration or environment issues",
                applicableAgentKinds: [.code, .mixed],
                requiredConditions: [.repositoryOpen],
                priorityScore: 0.65
            ),
            TaskStrategy(
                kind: .uiExploration,
                description: "Explore and interact with a web page or macOS UI",
                applicableAgentKinds: [.ui, .mixed],
                requiredConditions: [],
                priorityScore: 0.70
            ),
            TaskStrategy(
                kind: .navigation,
                description: "Navigate via graph edges (general task progression)",
                applicableAgentKinds: [.ui, .code, .mixed],
                requiredConditions: [],
                priorityScore: 0.55
            ),
            TaskStrategy(
                kind: .recovery,
                description: "Bounded recovery after repeated failures",
                applicableAgentKinds: [.ui, .code, .mixed],
                requiredConditions: [.repeatedFailures],
                priorityScore: 0.90,
                notes: ["Triggered automatically — do not select manually"]
            ),
        ]
    }
}
