import Foundation

// ─────────────────────────────────────────────────────────
// StateCoordinator — observation → WorldModelSnapshot pipeline
//
// Owns the per-step observation intake and diff application.
// This is the ONLY subsystem that may call:
//   • WorldStateModel.apply(diff:)
//   • WorldStateModel.applyObservation(_:)
//
// Architecture rule: does NOT record outcomes or plan.
// Recording belongs to LearningCoordinator.
// Planning belongs to DecisionCoordinator.
// ─────────────────────────────────────────────────────────

/// Builds per-step world state from observations.
///
/// `StateCoordinator` is the authority for moving observations into
/// `WorldStateModel`. It runs the full perception pipeline:
///
///   observation → delta → diff → apply → `WorldModelSnapshot`
///
/// The coordinator tracks the previous observation internally so
/// callers do not need to manage that state themselves.
public final class StateCoordinator {

    // ── Dependencies ────────────────────────────────────

    private let worldModel: WorldStateModel

    // ── Internal state ──────────────────────────────────

    /// Previous observation — used for delta detection.
    private var previousObservation: Observation?

    // ── Init ────────────────────────────────────────────

    public init(worldModel: WorldStateModel) {
        self.worldModel = worldModel
    }

    // MARK: – Ingestion

    /// Ingest a new observation and return the resulting snapshot.
    ///
    /// Computes a delta from the previous observation, derives a
    /// `StateDiff`, and applies it to the `WorldStateModel`. Identical
    /// consecutive observations produce an empty diff (no-op apply).
    ///
    /// - Parameter observation: The fresh observation to ingest.
    /// - Returns: The updated `WorldModelSnapshot`.
    @discardableResult
    public func ingest(_ observation: Observation) -> WorldModelSnapshot {
        let diff: StateDiff

        if let prev = previousObservation {
            let delta = ObservationChangeDetector.detect(
                previous: prev,
                incoming: observation
            )
            diff = StateDiffEngine.diff(
                current: worldModel.snapshot,
                incoming: observation,
                delta: delta
            )
        } else {
            // First observation — full snapshot from scratch.
            diff = StateDiffEngine.diff(
                current: worldModel.snapshot,
                incoming: observation
            )
        }

        if !diff.isEmpty {
            worldModel.apply(diff: diff)
        }

        previousObservation = observation
        return worldModel.snapshot
    }

    // MARK: – Bundle assembly

    /// Build a `StateBundle` from an optional fresh observation.
    ///
    /// If `observation` is provided it is ingested first; otherwise the
    /// coordinator returns a bundle around the most recent snapshot.
    public func buildBundle(
        taskContext: TaskContext,
        observation: Observation? = nil,
        stepIndex: Int = 0,
        lastActionID: String? = nil
    ) -> StateBundle {
        let snapshot: WorldModelSnapshot
        if let obs = observation {
            snapshot = ingest(obs)
        } else {
            snapshot = worldModel.snapshot
        }

        return StateBundle(
            taskContext: taskContext,
            snapshot: snapshot,
            observation: observation,
            stepIndex: stepIndex,
            lastActionID: lastActionID
        )
    }

    // MARK: – Accessors

    /// Read-only mirror of the current world snapshot.
    public var currentSnapshot: WorldModelSnapshot {
        worldModel.snapshot
    }

    // MARK: – Lifecycle

    /// Reset the coordinator's observation history.
    ///
    /// Call this when a new goal begins so the first observation is
    /// treated as a full snapshot rather than a delta from the previous goal.
    public func reset() {
        previousObservation = nil
    }
}
