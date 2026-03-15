import Foundation

// ─────────────────────────────────────────────────────────
// SelectedStrategy — the result of strategy selection
//
// Constrains all downstream plan generation by declaring
// which OperatorFamily values are allowed. The planner
// must not run without a valid selected strategy.
// ─────────────────────────────────────────────────────────

/// The result of strategy selection — the first decision in every planning cycle.
///
/// `SelectedStrategy` constrains downstream plan generation by declaring
/// which `OperatorFamily` values are allowed. The planner refuses to run
/// without a valid selected strategy.
public struct SelectedStrategy: Equatable {

    /// The high-level strategy kind chosen.
    public let kind: StrategyKind

    /// Confidence in the selection (0.0 – 1.0).
    public let confidence: Double

    /// Human-readable explanation of why this strategy was chosen.
    public let rationale: String

    /// The operator families the planner may use under this strategy.
    public let allowedOperatorFamilies: [OperatorFamily]

    /// Re-evaluate the strategy after this many loop steps.
    public let reevaluateAfterStepCount: Int

    public init(
        kind: StrategyKind,
        confidence: Double,
        rationale: String,
        allowedOperatorFamilies: [OperatorFamily],
        reevaluateAfterStepCount: Int = 5
    ) {
        self.kind = kind
        self.confidence = confidence
        self.rationale = rationale
        self.allowedOperatorFamilies = allowedOperatorFamilies
        self.reevaluateAfterStepCount = reevaluateAfterStepCount
    }

    // MARK: – Equatable (ignore rationale for comparison)

    public static func == (lhs: SelectedStrategy, rhs: SelectedStrategy) -> Bool {
        lhs.kind == rhs.kind &&
        lhs.allowedOperatorFamilies == rhs.allowedOperatorFamilies &&
        lhs.reevaluateAfterStepCount == rhs.reevaluateAfterStepCount
    }

    // MARK: – Query

    /// Returns `true` if the given operator family is allowed by this strategy.
    public func allows(_ family: OperatorFamily) -> Bool {
        allowedOperatorFamilies.contains(family)
    }

    /// Returns `true` if the strategy is high-confidence (≥ 0.8).
    public var isHighConfidence: Bool { confidence >= 0.8 }
}
