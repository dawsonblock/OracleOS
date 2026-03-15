import Foundation

// ─────────────────────────────────────────────────────────
// StrategyEvaluator — tracks active strategy and decides when to re-evaluate
//
// Maintains per-run strategy persistence state so the loop
// does not re-select on every step (which would cause thrashing).
//
// Reevaluation triggers:
//   • Plan completed
//   • Hard failure
//   • Confidence collapsed
//   • Task node changed significantly
//   • Reevaluate-after threshold reached
// ─────────────────────────────────────────────────────────

// MARK: – StrategyEvaluation

/// Record of a completed strategy episode — stored for trend analysis.
public struct StrategyEvaluation {

    public let kind: StrategyKind
    public let steps: Int
    public let succeeded: Bool
    public let confidence: Double
    public let timestamp: Date

    public init(
        kind: StrategyKind,
        steps: Int,
        succeeded: Bool,
        confidence: Double,
        timestamp: Date = Date()
    ) {
        self.kind = kind
        self.steps = steps
        self.succeeded = succeeded
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

// MARK: – StrategyEvaluator

/// Tracks the active strategy and decides when to re-evaluate.
///
/// Call `setCurrentStrategy(_:atStep:)` when a strategy is selected,
/// `recordStep()` each loop iteration, and `shouldReevaluate(...)` to
/// check whether conditions warrant a new strategy selection.
///
/// - Note: Not thread-safe by default. Wrap in a lock or actor for
///   concurrent use.
public final class StrategyEvaluator {

    // ── Persistence state ────────────────────────────────

    private var currentStrategy: SelectedStrategy?
    private var strategyStartStep: Int = 0
    private var stepsSinceSelection: Int = 0

    // ── Historical record ────────────────────────────────

    private var evaluations: [StrategyEvaluation] = []

    public init() {}

    // MARK: – Persistence management

    /// Record the current strategy and reset the step counter.
    ///
    /// Call this whenever a new strategy is selected at the top of
    /// the planning cycle.
    public func setCurrentStrategy(_ strategy: SelectedStrategy, atStep step: Int = 0) {
        currentStrategy = strategy
        strategyStartStep = step
        stepsSinceSelection = 0
    }

    /// Increment the step counter for the current strategy.
    ///
    /// Call once per loop iteration.
    public func recordStep() {
        stepsSinceSelection += 1
    }

    /// The currently active strategy, or `nil` if none has been selected.
    public func activeStrategy() -> SelectedStrategy? {
        currentStrategy
    }

    /// Number of loop steps executed since the current strategy was selected.
    public func stepsSinceStrategySelection() -> Int {
        stepsSinceSelection
    }

    // MARK: – Reevaluation decision

    /// Check whether conditions warrant a new strategy selection.
    ///
    /// Returns a `StrategyReevaluationCause` when reevaluation is needed,
    /// or `nil` when the current strategy should continue.
    ///
    /// - Parameters:
    ///   - planCompleted: Pass `true` when the active plan finished.
    ///   - hardFailure: Pass `true` on an unrecoverable failure.
    ///   - confidenceCollapsed: Pass `true` when confidence falls below 0.3.
    ///   - taskNodeChanged: Pass `true` when the task graph node shifts.
    public func shouldReevaluate(
        planCompleted: Bool = false,
        hardFailure: Bool = false,
        confidenceCollapsed: Bool = false,
        taskNodeChanged: Bool = false
    ) -> StrategyReevaluationCause? {
        guard let strategy = currentStrategy else {
            return .noActiveStrategy
        }

        if planCompleted    { return .planCompleted }
        if hardFailure      { return .hardFailure }
        if confidenceCollapsed { return .confidenceCollapsed }
        if taskNodeChanged  { return .taskNodeChanged }

        if stepsSinceSelection >= strategy.reevaluateAfterStepCount {
            return .reevaluateThresholdReached
        }

        return nil
    }

    // MARK: – Historical record

    /// Persist a completed strategy evaluation episode.
    public func record(evaluation: StrategyEvaluation) {
        evaluations.append(evaluation)
    }

    /// Success rate for the given strategy kind (0.0 if no history).
    public func successRate(for kind: StrategyKind) -> Double {
        let relevant = evaluations.filter { $0.kind == kind }
        guard !relevant.isEmpty else { return 0.0 }
        let successes = relevant.filter { $0.succeeded }.count
        return Double(successes) / Double(relevant.count)
    }

    /// Most recent evaluations (newest last).
    public func recentEvaluations(limit: Int = 10) -> [StrategyEvaluation] {
        Array(evaluations.suffix(limit))
    }

    // MARK: – Lifecycle

    /// Reset persistence state (call at goal start).
    public func reset() {
        currentStrategy = nil
        strategyStartStep = 0
        stepsSinceSelection = 0
    }
}
