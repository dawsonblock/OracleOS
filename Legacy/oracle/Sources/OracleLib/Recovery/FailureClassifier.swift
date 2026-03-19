import Foundation

// ─────────────────────────────────────────────────────────
// FailureClassifier — maps error descriptions → FailureClass
//
// Keyword/signal matching on the lowercased error string.
// Context boosts confidence when the same failure class was
// seen recently (pattern reinforcement).
// ─────────────────────────────────────────────────────────

// MARK: – FailureClassification

/// The result of classifying an error description.
public struct FailureClassification: Equatable {

    /// The inferred failure domain.
    public let failureClass: FailureClass

    /// Confidence in [0, 1]. Boosted when context shows a repeating pattern.
    public let confidence: Double

    /// Signal strings that triggered this classification.
    public let signals: [String]

    public init(failureClass: FailureClass, confidence: Double, signals: [String] = []) {
        self.failureClass = failureClass
        self.confidence = max(0.0, min(1.0, confidence))
        self.signals = signals
    }
}

// MARK: – FailureClassifierContext

/// Supplementary context that can boost classifier confidence.
public struct FailureClassifierContext: Equatable {

    /// The bundle ID or app name of the frontmost application.
    public let app: String?

    /// A domain hint (e.g. "browser", "code", "ui").
    public let domain: String?

    /// Recent failure classes seen in the same goal episode.
    public let recentFailureClasses: [FailureClass]

    public init(
        app: String? = nil,
        domain: String? = nil,
        recentFailureClasses: [FailureClass] = []
    ) {
        self.app = app
        self.domain = domain
        self.recentFailureClasses = recentFailureClasses
    }
}

// MARK: – FailureClassifier

/// Maps error descriptions to `FailureClass` values using keyword signals.
///
/// Classification priority order (checked top-to-bottom):
///   1. targetMissing
///   2. elementAmbiguous
///   3. wrongFocus
///   4. unexpectedDialog
///   5. permissionBlocked
///   6. patchApplyFailed
///   7. environmentMismatch
///   8. workflowReplayFailure
///   9. modalBlocking
///  10. buildFailed
///  11. testFailed
///  12. navigationFailed
///  → fallthrough: actionFailed (confidence 0.40)
public enum FailureClassifier {

    // ── Primary API ──────────────────────────────────────

    /// Classify an error description into a `FailureClassification`.
    ///
    /// - Parameters:
    ///   - errorDescription: The raw error string from the execution layer.
    ///   - context: Optional supplementary context for confidence boosting.
    public static func classify(
        errorDescription: String,
        context: FailureClassifierContext = FailureClassifierContext()
    ) -> FailureClassification {

        let lower = errorDescription.lowercased()

        // ── Keyword matching (priority order) ───────────

        if contains(lower, "target") && containsAny(lower, "missing", "not found") {
            return make(.targetMissing, 0.85, ["target", "missing"], context: context)
        }
        if contains(lower, "ambiguous") {
            return make(.elementAmbiguous, 0.80, ["ambiguous"], context: context)
        }
        if containsAny(lower, "wrong window", "wrong focus") {
            return make(.wrongFocus, 0.75, ["wrong"], context: context)
        }
        if contains(lower, "unexpected") && containsAny(lower, "dialog", "alert") {
            return make(.unexpectedDialog, 0.80, ["unexpected", "dialog"], context: context)
        }
        if containsAny(lower, "permission", "denied", "blocked") {
            return make(.permissionBlocked, 0.75, ["permission"], context: context)
        }
        if contains(lower, "patch") && containsAny(lower, "fail", "reject") {
            return make(.patchApplyFailed, 0.80, ["patch", "failed"], context: context)
        }
        if containsAny(lower, "environment", "mismatch") {
            return make(.environmentMismatch, 0.70, ["environment"], context: context)
        }
        if contains(lower, "workflow") && contains(lower, "replay") {
            return make(.workflowReplayFailure, 0.75, ["workflow", "replay"], context: context)
        }
        if containsAny(lower, "modal", "blocking") {
            return make(.modalBlocking, 0.80, ["modal"], context: context)
        }
        if contains(lower, "build") && contains(lower, "fail") {
            return make(.buildFailed, 0.80, ["build", "failed"], context: context)
        }
        if contains(lower, "test") && contains(lower, "fail") {
            return make(.testFailed, 0.80, ["test", "failed"], context: context)
        }
        if containsAny(lower, "navigate", "navigation") {
            return make(.navigationFailed, 0.65, ["navigate"], context: context)
        }
        if contains(lower, "element") && containsAny(lower, "not found", "missing") {
            return make(.elementNotFound, 0.75, ["element", "not found"], context: context)
        }
        if contains(lower, "stale") {
            return make(.staleObservation, 0.70, ["stale"], context: context)
        }

        // ── Fallthrough ──────────────────────────────────
        return FailureClassification(failureClass: .actionFailed, confidence: 0.40, signals: [])
    }

    // ── Private helpers ──────────────────────────────────

    private static func make(
        _ fc: FailureClass,
        _ base: Double,
        _ signals: [String],
        context: FailureClassifierContext
    ) -> FailureClassification {
        FailureClassification(
            failureClass: fc,
            confidence: contextBoosted(base, context: context, expected: fc),
            signals: signals
        )
    }

    /// Boosts confidence by +0.05 if the failure class was seen recently.
    private static func contextBoosted(
        _ base: Double,
        context: FailureClassifierContext,
        expected: FailureClass
    ) -> Double {
        context.recentFailureClasses.contains(expected) ? min(1.0, base + 0.05) : base
    }

    private static func contains(_ string: String, _ substring: String) -> Bool {
        string.contains(substring)
    }

    private static func containsAny(_ string: String, _ substrings: String...) -> Bool {
        substrings.contains { string.contains($0) }
    }
}
