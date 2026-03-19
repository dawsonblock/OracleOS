import Foundation

// ─────────────────────────────────────────────────────────
// RecoveryStrategyLibrary — built-in recovery descriptors
//
// Maps FailureClass values to ordered, cost-sorted strategy
// entries. The selector uses this to rank and prepare
// recovery candidates.
//
// Built-in entries mirror the reference implementation:
//   retry_with_new_target, refocus_window, dismiss_dialog,
//   reopen_context, restart_application, rollback_patch,
//   rebuild_environment, retry_workflow
// ─────────────────────────────────────────────────────────

// MARK: – RecoveryStrategyEntry

/// A descriptor for one recovery strategy stored in the library.
///
/// Entries are pure data — they describe what a strategy does and
/// which failure classes it handles. Actual preparation logic lives
/// in `RecoveryStrategySelector.prepare(entry:failure:snapshot:)`.
public struct RecoveryStrategyEntry: Equatable {

    /// Unique name, kebab-case (used as `RecoveryPreparation.strategyName`).
    public let name: String

    /// Failure classes this strategy can address.
    public let applicableFailures: [FailureClass]

    /// Human-readable description (shown in diagnostics).
    public let description: String

    /// Estimated execution cost — lower is preferred by the selector.
    public let baseCost: Double

    /// Estimated risk of side effects (0.0 – 1.0).
    public let risk: Double

    public init(
        name: String,
        applicableFailures: [FailureClass],
        description: String,
        baseCost: Double = 1.0,
        risk: Double = 0.1
    ) {
        self.name = name
        self.applicableFailures = applicableFailures
        self.description = description
        self.baseCost = max(0.0, baseCost)
        self.risk = max(0.0, min(1.0, risk))
    }
}

// MARK: – RecoveryStrategyLibrary

/// Registry of built-in recovery strategy descriptors.
///
/// Query via `applicable(for:)` to get cost-sorted candidates
/// for a given `FailureClass`.
public final class RecoveryStrategyLibrary {

    // ── Shared instance ──────────────────────────────────

    public static let shared: RecoveryStrategyLibrary = RecoveryStrategyLibrary()

    // ── Storage ──────────────────────────────────────────

    public let entries: [RecoveryStrategyEntry]

    // ── Init ─────────────────────────────────────────────

    /// Initialise with explicit entries, or nil for the default built-in library.
    public init(entries: [RecoveryStrategyEntry]? = nil) {
        self.entries = entries ?? RecoveryStrategyLibrary.defaultEntries()
    }

    // ── Queries ──────────────────────────────────────────

    /// Returns entries that handle `failure`, sorted by `baseCost` ascending.
    public func applicable(for failure: FailureClass) -> [RecoveryStrategyEntry] {
        entries
            .filter { $0.applicableFailures.contains(failure) }
            .sorted { $0.baseCost < $1.baseCost }
    }

    /// Look up an entry by name.
    public func entry(named name: String) -> RecoveryStrategyEntry? {
        entries.first { $0.name == name }
    }

    // ── Default library ──────────────────────────────────

    private static func defaultEntries() -> [RecoveryStrategyEntry] {
        [
            RecoveryStrategyEntry(
                name: "retry_with_new_target",
                applicableFailures: [.elementNotFound, .elementAmbiguous, .targetMissing, .staleObservation],
                description: "Re-query the element index and retry with an updated target selector.",
                baseCost: 0.6,
                risk: 0.08
            ),
            RecoveryStrategyEntry(
                name: "refocus_window",
                applicableFailures: [.wrongFocus, .navigationFailed],
                description: "Bring the target application window to the front and retry.",
                baseCost: 0.4,
                risk: 0.03
            ),
            RecoveryStrategyEntry(
                name: "dismiss_dialog",
                applicableFailures: [.modalBlocking, .unexpectedDialog],
                description: "Dismiss the blocking dialog (Escape / Cancel) and retry the action.",
                baseCost: 0.3,
                risk: 0.02
            ),
            RecoveryStrategyEntry(
                name: "reopen_context",
                applicableFailures: [.navigationFailed, .staleObservation, .wrongFocus],
                description: "Navigate back to the expected context (URL, view, or file) and re-observe.",
                baseCost: 0.8,
                risk: 0.06
            ),
            RecoveryStrategyEntry(
                name: "restart_application",
                applicableFailures: [.wrongFocus, .environmentMismatch, .actionFailed],
                description: "Quit and relaunch the target application to reset its state.",
                baseCost: 1.5,
                risk: 0.15
            ),
            RecoveryStrategyEntry(
                name: "rollback_patch",
                applicableFailures: [.patchApplyFailed, .buildFailed, .testFailed],
                description: "Revert the last applied patch using `git checkout` and retry with a clean tree.",
                baseCost: 1.2,
                risk: 0.08
            ),
            RecoveryStrategyEntry(
                name: "rebuild_environment",
                applicableFailures: [.environmentMismatch, .buildFailed],
                description: "Clean and rebuild the environment (e.g. `swift package clean && swift build`).",
                baseCost: 2.0,
                risk: 0.20
            ),
            RecoveryStrategyEntry(
                name: "retry_workflow",
                applicableFailures: [.workflowReplayFailure, .verificationFailed],
                description: "Reset workflow state and retry the promoted plan from the beginning.",
                baseCost: 0.9,
                risk: 0.10
            ),
        ]
    }
}
