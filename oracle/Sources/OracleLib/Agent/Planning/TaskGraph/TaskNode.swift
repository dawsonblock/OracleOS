import Foundation

// ─────────────────────────────────────────────────────────
// TaskNode — a meaningful task state in the task graph
//
// Captures task-relevant state abstractions rather than raw
// UI noise. The planner navigates the graph by moving
// between nodes, so each node describes a recognisable
// planning position such as "repo_loaded", "tests_running",
// or "permission_dialog_active".
//
// ARCHITECTURE_RULES.md: protected backbone (TaskGraph).
// ─────────────────────────────────────────────────────────

/// Task-relevant state abstraction.
///
/// Each case represents a meaningful planning position the planner
/// can reason about. Raw UI noise (scroll offsets, focus rings,
/// minor DOM mutations) must **not** produce distinct abstract states.
/// Only task-meaningful transitions create new nodes.
public enum AbstractTaskState: String, Hashable, CaseIterable {

    // Repository lifecycle
    case repoLoaded         = "repo_loaded"
    case repoIndexed        = "repo_indexed"

    // Build lifecycle
    case buildRunning       = "build_running"
    case buildSucceeded     = "build_succeeded"
    case buildFailed        = "build_failed"

    // Test lifecycle
    case testsRunning       = "tests_running"
    case testsPassed        = "tests_passed"
    case failingTestIdentified = "failing_test_identified"

    // Patch lifecycle
    case candidatePatchGenerated = "candidate_patch_generated"
    case candidatePatchApplied   = "candidate_patch_applied"
    case patchVerified       = "patch_verified"
    case patchRejected       = "patch_rejected"

    // Browser / UI lifecycle
    case pageLoaded           = "page_loaded"
    case loginPageDetected    = "login_page_detected"
    case permissionDialogActive = "permission_dialog_active"
    case modalDialogActive    = "modal_dialog_active"
    case navigationCompleted  = "navigation_completed"
    case formVisible          = "form_visible"

    // General task states
    case taskStarted       = "task_started"
    case taskCompleted     = "task_completed"
    case goalReached       = "goal_reached"
    case recoveryNeeded    = "recovery_needed"
    case explorationActive = "exploration_active"
    case idle              = "idle"
}

/// Represents a meaningful task state in the task graph.
public final class TaskNode {

    public let id: String
    public let abstractState: AbstractTaskState
    public let label: String
    public private(set) var worldSnapshotRef: String?
    public let createdByAction: String?
    public let timestamp: TimeInterval
    public private(set) var visitCount: Int
    public private(set) var confidence: Double

    public init(
        id: String = UUID().uuidString,
        abstractState: AbstractTaskState,
        label: String? = nil,
        worldSnapshotRef: String? = nil,
        createdByAction: String? = nil,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        confidence: Double = 1.0,
        visitCount: Int = 0
    ) {
        self.id = id
        self.abstractState = abstractState
        self.label = label ?? abstractState.rawValue
        self.worldSnapshotRef = worldSnapshotRef
        self.createdByAction = createdByAction
        self.timestamp = timestamp
        self.confidence = confidence
        self.visitCount = visitCount
    }

    /// Record a visit to this node.
    public func recordVisit() {
        visitCount += 1
    }

    /// Update confidence score (clamped 0..1).
    public func updateConfidence(_ value: Double) {
        confidence = max(0, min(1, value))
    }

    /// Update world snapshot reference.
    public func updateWorldSnapshotRef(_ ref: String) {
        worldSnapshotRef = ref
    }

    /// Stable signature for merge detection.
    public var stateSignature: String {
        "\(abstractState.rawValue)|\(label)"
    }
}
