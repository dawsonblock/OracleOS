import Foundation

// ─────────────────────────────────────────────────────────
// StrategyTypes — core enums shared across the strategy layer
//
// Strategy selection is the mandatory first decision stage
// in every planning cycle. No plan generation happens before
// a strategy is selected.
//
// StrategyKind → StrategyLibrary.allowedFamilies
//             → SelectedStrategy.allowedOperatorFamilies
//             → plan generation is constrained to those families
// ─────────────────────────────────────────────────────────

// MARK: – StrategyKind

/// Top-level strategy enum defining the agent's high-level approach.
///
/// Strategy selection is the first decision stage in every planning cycle.
/// No plan generation happens before a strategy is selected.
public enum StrategyKind: String, Equatable, CaseIterable {
    /// Execute a known workflow (memory-backed, highest confidence).
    case workflowExecution = "workflow_execution"
    /// Navigate via the task graph (graph-backed steps).
    case graphNavigation = "graph_navigation"
    /// Repair a repository (build failures, test failures, patches).
    case repoRepair = "repo_repair"
    /// Analyse diagnostics before committing to a repair path.
    case diagnosticAnalysis = "diagnostic_analysis"
    /// Interact with a browser or web page.
    case browserInteraction = "browser_interaction"
    /// Handle a permission or authorisation dialog.
    case permissionResolution = "permission_resolution"
    /// Bounded failure recovery — entered when failures accumulate.
    case recoveryMode = "recovery_mode"
    /// Run controlled experiments (parallel patch testing).
    case experimentMode = "experiment_mode"
    /// Direct single-step OS action (low-cost short tasks).
    case directExecution = "direct_execution"
}

// MARK: – OperatorFamily

/// Categorises planning operators into families.
///
/// Each `StrategyKind` maps to a bounded set of allowed families via
/// `StrategyLibrary`. Plan generation filters candidates against this set,
/// preventing cross-strategy noise.
public enum OperatorFamily: String, Equatable, CaseIterable, Sendable {
    case workflow
    case graphEdge = "graph_edge"
    case browserTargeted = "browser_targeted"
    case hostTargeted = "host_targeted"
    case repoAnalysis = "repo_analysis"
    case patchGeneration = "patch_generation"
    case patchExperiment = "patch_experiment"
    case recovery
    case permissionHandling = "permission_handling"
    case exploration
    case llmProposal = "llm_proposal"
}

// MARK: – StrategyCondition

/// Conditions that influence strategy selection.
///
/// `StrategySelector` evaluates active conditions in the world state
/// and goal text before scoring candidate strategies.
public enum StrategyCondition: String, Equatable {
    case repositoryOpen = "repository_open"
    case buildFailing = "build_failing"
    case testsFailing = "tests_failing"
    case modalPresent = "modal_present"
    case wrongApplication = "wrong_application"
    case workflowAvailable = "workflow_available"
    case gitDirty = "git_dirty"
    case patchApplied = "patch_applied"
    case browserPageActive = "browser_page_active"
    case repeatedFailures = "repeated_failures"
    case permissionDialogActive = "permission_dialog_active"
}

// MARK: – StrategyReevaluationCause

/// Why a strategy should be reconsidered mid-goal.
public enum StrategyReevaluationCause: String, Equatable {
    /// No strategy has been selected yet.
    case noActiveStrategy
    /// The current plan reached a terminal step.
    case planCompleted
    /// A hard (unrecoverable) failure was detected.
    case hardFailure
    /// Strategy confidence dropped below the acceptable threshold.
    case confidenceCollapsed
    /// The task graph node changed significantly.
    case taskNodeChanged
    /// Reevaluate-after-N-steps threshold reached.
    case reevaluateThresholdReached
}
