import Foundation

// ─────────────────────────────────────────────────────────
// RecoveryStrategySelector — maps FailureClass → RecoveryAttempt
//
// Selects the best available strategy from the library for a
// given failure class and current world snapshot, then runs
// the lightweight preparation routine.
//
// No async/await — preparation is synchronous and fast.
// The heavier async recovery path lives in RecoveryCoordinator.
// ─────────────────────────────────────────────────────────

// MARK: – RecoverySelection

/// The ordered set of strategies selected for a given failure class.
public struct RecoverySelection: Equatable {

    /// Strategies in preference order (best first).
    public let orderedEntries: [RecoveryStrategyEntry]

    /// The failure class being addressed.
    public let failureClass: FailureClass

    public init(orderedEntries: [RecoveryStrategyEntry], failureClass: FailureClass) {
        self.orderedEntries = orderedEntries
        self.failureClass = failureClass
    }
}

// MARK: – RecoveryStrategySelector

/// Selects and prepares recovery strategies for a given failure.
///
/// The selector queries `RecoveryStrategyLibrary` for candidates,
/// then runs `prepare(entry:failure:snapshot:)` on each in order
/// until one succeeds.
public struct RecoveryStrategySelector {

    private let library: RecoveryStrategyLibrary

    public init(library: RecoveryStrategyLibrary = .shared) {
        self.library = library
    }

    // ── Primary API ──────────────────────────────────────

    /// Select an ordered set of strategies for the given failure class.
    ///
    /// Entries are sorted by `baseCost` ascending (cheapest first).
    /// An optional `preferredName` biases the first position.
    public func select(
        for failure: FailureClass,
        preferredName: String? = nil
    ) -> RecoverySelection {
        var entries = library.applicable(for: failure)

        // Bias: move preferred strategy to front
        if let preferred = preferredName,
           let idx = entries.firstIndex(where: { $0.name == preferred }) {
            let entry = entries.remove(at: idx)
            entries.insert(entry, at: 0)
        }

        return RecoverySelection(orderedEntries: entries, failureClass: failure)
    }

    /// Run through ordered candidates and return the first successful `RecoveryAttempt`.
    ///
    /// Returns `.exhausted()` if every candidate returns `nil` from `prepare`.
    public func attempt(
        failure: FailureClass,
        snapshot: WorldModelSnapshot,
        preferredName: String? = nil
    ) -> RecoveryAttempt {
        let selection = select(for: failure, preferredName: preferredName)

        guard !selection.orderedEntries.isEmpty else {
            return .noStrategy()
        }

        for entry in selection.orderedEntries {
            if let prep = prepare(entry: entry, failure: failure, snapshot: snapshot) {
                return .success(strategy: entry.name, preparation: prep)
            }
        }
        return .exhausted()
    }

    // ── Preparation ──────────────────────────────────────

    /// Run lightweight synchronous preparation for a strategy entry.
    ///
    /// Returns `nil` when the entry cannot handle the failure given
    /// the current world snapshot.
    public func prepare(
        entry: RecoveryStrategyEntry,
        failure: FailureClass,
        snapshot: WorldModelSnapshot
    ) -> RecoveryPreparation? {
        guard entry.applicableFailures.contains(failure) else { return nil }

        let hint = actionHint(for: entry, snapshot: snapshot)
        return RecoveryPreparation(
            strategyName: entry.name,
            actionHint: hint,
            estimatedCost: entry.baseCost,
            notes: ["failureClass: \(failure.rawValue)", "risk: \(entry.risk)"]
        )
    }

    // ── Private ──────────────────────────────────────────

    private func actionHint(
        for entry: RecoveryStrategyEntry,
        snapshot: WorldModelSnapshot
    ) -> String {
        let app = snapshot.activeApplication ?? "unknown"
        switch entry.name {
        case "retry_with_new_target":
            return "Re-query element index and retry action (app: \(app))"
        case "refocus_window":
            return "Bring \(app) to front"
        case "dismiss_dialog":
            return "Dismiss blocking dialog via Escape key"
        case "reopen_context":
            return "Navigate back to expected context"
        case "restart_application":
            return "Quit and relaunch \(app)"
        case "rollback_patch":
            return "git checkout -- . to revert patch"
        case "rebuild_environment":
            return "swift package clean && swift build"
        case "retry_workflow":
            return "Reset workflow state and replay from step 0"
        default:
            return entry.description
        }
    }
}
