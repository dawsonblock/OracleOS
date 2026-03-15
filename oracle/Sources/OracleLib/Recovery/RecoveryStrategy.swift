import Foundation

// ─────────────────────────────────────────────────────────
// RecoveryStrategy — types for the recovery strategy system
//
// RecoveryPreparation — the output of a strategy that decided
//   it can handle a failure.
// RecoveryAttempt — the result returned to the caller of the
//   recovery engine: success, failure, or exhaustion.
// RecoveryStrategyEntry — a descriptor stored in the library.
// ─────────────────────────────────────────────────────────

// MARK: – RecoveryPreparation

/// A strategy's prepared resolution for a given failure class.
///
/// `nil` from a strategy means "I cannot handle this failure" — the
/// recovery engine skips to the next candidate.
public struct RecoveryPreparation: Equatable {

    /// The name of the strategy that produced this preparation.
    public let strategyName: String

    /// Free-text action descriptor that the executor can act on.
    public let actionHint: String

    /// Estimated cost of executing this preparation (used for ordering).
    public let estimatedCost: Double

    /// Optional notes for logging and observability.
    public let notes: [String]

    public init(
        strategyName: String,
        actionHint: String,
        estimatedCost: Double = 1.0,
        notes: [String] = []
    ) {
        self.strategyName = strategyName
        self.actionHint = actionHint
        self.estimatedCost = max(0.0, estimatedCost)
        self.notes = notes
    }
}

// MARK: – RecoveryAttempt

/// The full outcome of a recovery engine run.
public struct RecoveryAttempt: Equatable {

    /// The strategy that was selected (nil when no strategy was found).
    public let strategyName: String?

    /// The preparation produced by the strategy (nil on failure/exhaustion).
    public let preparation: RecoveryPreparation?

    /// Human-readable description of the attempt outcome.
    public let message: String

    /// Whether the attempt produced actionable output.
    public var succeeded: Bool { preparation != nil }

    public init(
        strategyName: String?,
        preparation: RecoveryPreparation?,
        message: String
    ) {
        self.strategyName = strategyName
        self.preparation = preparation
        self.message = message
    }

    // ── Convenience constructors ─────────────────────────

    public static func success(strategy: String, preparation: RecoveryPreparation) -> RecoveryAttempt {
        RecoveryAttempt(strategyName: strategy, preparation: preparation, message: "Recovery prepared: \(strategy)")
    }

    public static func exhausted() -> RecoveryAttempt {
        RecoveryAttempt(strategyName: nil, preparation: nil, message: "Recovery exhausted — no strategy applicable")
    }

    public static func noStrategy() -> RecoveryAttempt {
        RecoveryAttempt(strategyName: nil, preparation: nil, message: "No recovery strategy available")
    }

    public static func failure(strategy: String, error: String) -> RecoveryAttempt {
        RecoveryAttempt(strategyName: strategy, preparation: nil, message: "Recovery failed: \(error)")
    }
}
