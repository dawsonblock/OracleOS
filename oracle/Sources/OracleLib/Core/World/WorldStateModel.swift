import Foundation

// ─────────────────────────────────────────────────────────
// WorldStateModel — authoritative committed world state
//
// Protected backbone per ARCHITECTURE_RULES.md.
//
// The WorldModelSnapshot is an immutable value type
// capturing everything the planner needs to know about
// the current environment. The WorldStateModel class
// maintains a rolling history of snapshots and provides
// copy-on-write-style mutation through apply(diff:).
//
// Pipeline:
//   StateDiffEngine.diff() → StateDiff → apply(diff:) → new snapshot
// ─────────────────────────────────────────────────────────

/// Immutable point-in-time snapshot of the world.
public struct WorldModelSnapshot: Equatable {

    // ── Application layer ───────────────────────────────

    public var activeApplication: String?
    public var windowTitle: String?
    public var url: String?
    public var visibleElementCount: Int
    public var modalPresent: Bool
    public var focusedElementID: String?
    /// Visible element labels for OS target resolution (e.g. from AX/Observation).
    public var elementLabels: [String]

    // ── Code / repository layer ─────────────────────────

    public var repositoryRoot: String?
    public var activeBranch: String?
    public var isGitDirty: Bool
    public var buildSucceeded: Bool
    public var failingTestCount: Int

    // ── Observation fingerprint ─────────────────────────

    public var observationHash: String?

    // ── Timestamp ───────────────────────────────────────

    public var timestamp: Date

    public init(
        activeApplication: String? = nil,
        windowTitle: String? = nil,
        url: String? = nil,
        visibleElementCount: Int = 0,
        modalPresent: Bool = false,
        focusedElementID: String? = nil,
        elementLabels: [String] = [],
        repositoryRoot: String? = nil,
        activeBranch: String? = nil,
        isGitDirty: Bool = false,
        buildSucceeded: Bool = true,
        failingTestCount: Int = 0,
        observationHash: String? = nil,
        timestamp: Date = Date()
    ) {
        self.activeApplication = activeApplication
        self.windowTitle = windowTitle
        self.url = url
        self.visibleElementCount = visibleElementCount
        self.modalPresent = modalPresent
        self.focusedElementID = focusedElementID
        self.elementLabels = elementLabels
        self.repositoryRoot = repositoryRoot
        self.activeBranch = activeBranch
        self.isGitDirty = isGitDirty
        self.buildSucceeded = buildSucceeded
        self.failingTestCount = failingTestCount
        self.observationHash = observationHash
        self.timestamp = timestamp
    }

    /// Copy-on-write helper — returns a mutable clone.
    public func copy() -> WorldModelSnapshot {
        return self // struct semantics — already a value copy
    }

    /// Compact summary for logging.
    public var summary: String {
        let app = activeApplication ?? "none"
        let branch = activeBranch ?? "none"
        let tests = failingTestCount > 0 ? "FAIL(\(failingTestCount))" : "OK"
        let build = buildSucceeded ? "BUILD-OK" : "BUILD-FAIL"
        let dirty = isGitDirty ? "dirty" : "clean"
        return "[\(app)] branch=\(branch) \(build) tests=\(tests) git=\(dirty) elements=\(visibleElementCount)"
    }
}

/// Manages the authoritative world state and its history.
public final class WorldStateModel {

    // ── Current snapshot ────────────────────────────────

    public private(set) var snapshot: WorldModelSnapshot

    // ── History ─────────────────────────────────────────

    private var history: [WorldModelSnapshot] = []
    private let maxHistory: Int

    public init(maxHistory: Int = 20) {
        self.snapshot = WorldModelSnapshot()
        self.maxHistory = maxHistory
    }

    // ── Mutation ─────────────────────────────────────────

    /// Apply a StateDiff to produce the next snapshot.
    public func apply(diff: StateDiff) {
        var next = snapshot.copy()
        next.timestamp = Date()

        for change in diff.changes {
            switch change {
            case .applicationChanged(_, let to):
                next.activeApplication = to
            case .windowTitleChanged(_, let to):
                next.windowTitle = to
            case .urlChanged(_, let to):
                next.url = to
            case .focusChanged(_, let to):
                next.focusedElementID = to
            case .elementCountChanged(_, let to):
                next.visibleElementCount = to
            case .modalStateChanged(_, let to):
                next.modalPresent = to
            case .branchChanged(_, let to):
                next.activeBranch = to
            case .gitDirtyChanged(_, let to):
                next.isGitDirty = to
            case .buildResultChanged(_, let to):
                next.buildSucceeded = to
            case .failingTestCountChanged(_, let to):
                next.failingTestCount = to
            case .observationHashChanged(_, let to):
                next.observationHash = to
            }
        }

        pushHistory(snapshot)
        snapshot = next
    }

    /// Apply raw observation metadata directly (for bootstrap or override).
    public func applyObservation(_ observation: Observation) {
        var next = snapshot.copy()
        next.timestamp = Date()
        next.activeApplication = observation.app
        next.windowTitle = observation.windowTitle
        next.url = observation.url
        next.focusedElementID = observation.focusedElementID
        next.visibleElementCount = observation.elements.count
        next.observationHash = observation.stableHash()

        pushHistory(snapshot)
        snapshot = next
    }

    /// Reset to a blank snapshot.
    public func reset() {
        pushHistory(snapshot)
        snapshot = WorldModelSnapshot()
    }

    // ── History queries ─────────────────────────────────

    /// Most recent N snapshots (newest first).
    public func recentHistory(limit: Int = 5) -> [WorldModelSnapshot] {
        Array(history.suffix(limit).reversed())
    }

    /// Total number of snapshots in history (capped at maxHistory).
    public var historyCount: Int { history.count }

    // ── Private ─────────────────────────────────────────

    private func pushHistory(_ snap: WorldModelSnapshot) {
        history.append(snap)
        if history.count > maxHistory {
            history.removeFirst(history.count - maxHistory)
        }
    }
}
