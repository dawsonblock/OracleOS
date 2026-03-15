import Foundation

// ─────────────────────────────────────────────────────────
// StateDiffEngine — structural diff between world states
//
// Protected backbone per ARCHITECTURE_RULES.md.
//
// Converts an ObservationDelta (fine-grained element-level)
// into a StateDiff (high-level semantic changes) that can
// be applied to WorldStateModel.
//
// Pipeline:
//   previous snapshot + incoming observation
//     → diff(current:incoming:) → StateDiff
//     → WorldStateModel.apply(diff:)
// ─────────────────────────────────────────────────────────

/// A semantic change in the world state.
public struct StateDiff {

    public let changes: [Change]
    public let timestamp: Date
    public let observationDelta: ObservationDelta?

    public var isEmpty: Bool { changes.isEmpty }
    public var count: Int { changes.count }

    public init(
        changes: [Change] = [],
        observationDelta: ObservationDelta? = nil,
        timestamp: Date = Date()
    ) {
        self.changes = changes
        self.observationDelta = observationDelta
        self.timestamp = timestamp
    }

    /// Individual state change.
    public enum Change: Equatable {
        case applicationChanged(from: String?, to: String?)
        case windowTitleChanged(from: String?, to: String?)
        case urlChanged(from: String?, to: String?)
        case focusChanged(from: String?, to: String?)
        case elementCountChanged(from: Int, to: Int)
        case modalStateChanged(from: Bool, to: Bool)
        case branchChanged(from: String?, to: String?)
        case gitDirtyChanged(from: Bool, to: Bool)
        case buildResultChanged(from: Bool, to: Bool)
        case failingTestCountChanged(from: Int, to: Int)
        case observationHashChanged(from: String?, to: String?)
    }
}

/// Produces StateDiff values from observations and existing state.
public enum StateDiffEngine {

    /// Diff the current world snapshot against an incoming observation.
    public static func diff(
        current: WorldModelSnapshot,
        incoming: Observation
    ) -> StateDiff {
        var changes: [StateDiff.Change] = []

        if current.activeApplication != incoming.app {
            changes.append(.applicationChanged(from: current.activeApplication, to: incoming.app))
        }
        if current.windowTitle != incoming.windowTitle {
            changes.append(.windowTitleChanged(from: current.windowTitle, to: incoming.windowTitle))
        }
        if current.url != incoming.url {
            changes.append(.urlChanged(from: current.url, to: incoming.url))
        }
        if current.focusedElementID != incoming.focusedElementID {
            changes.append(.focusChanged(from: current.focusedElementID, to: incoming.focusedElementID))
        }

        let incomingCount = incoming.elements.count
        if current.visibleElementCount != incomingCount {
            changes.append(.elementCountChanged(from: current.visibleElementCount, to: incomingCount))
        }

        let incomingHash = incoming.stableHash()
        if current.observationHash != incomingHash {
            changes.append(.observationHashChanged(from: current.observationHash, to: incomingHash))
        }

        return StateDiff(changes: changes)
    }

    /// Diff using an already-computed ObservationDelta (more efficient when
    /// the change detector has already run).
    public static func diff(
        current: WorldModelSnapshot,
        incoming: Observation,
        delta: ObservationDelta
    ) -> StateDiff {
        var changes: [StateDiff.Change] = []

        if let ac = delta.applicationChanged {
            changes.append(.applicationChanged(from: ac.from, to: ac.to))
        }
        if let wc = delta.windowTitleChanged {
            changes.append(.windowTitleChanged(from: wc.from, to: wc.to))
        }
        if let uc = delta.urlChanged {
            changes.append(.urlChanged(from: uc.from, to: uc.to))
        }
        if let fc = delta.focusChanged {
            changes.append(.focusChanged(from: fc.from, to: fc.to))
        }

        let elementDeltaCount = delta.addedElements.count - delta.removedElementIDs.count
        if elementDeltaCount != 0 {
            let newCount = current.visibleElementCount + elementDeltaCount
            changes.append(.elementCountChanged(from: current.visibleElementCount, to: newCount))
        }

        // Observation hash always computed from full observation
        let incomingHash = incoming.stableHash()
        if current.observationHash != incomingHash {
            changes.append(.observationHashChanged(from: current.observationHash, to: incomingHash))
        }

        return StateDiff(changes: changes, observationDelta: delta)
    }

    /// Diff two snapshots directly (for testing / replay).
    public static func diff(
        previous: WorldModelSnapshot,
        current: WorldModelSnapshot
    ) -> StateDiff {
        var changes: [StateDiff.Change] = []

        if previous.activeApplication != current.activeApplication {
            changes.append(.applicationChanged(from: previous.activeApplication, to: current.activeApplication))
        }
        if previous.windowTitle != current.windowTitle {
            changes.append(.windowTitleChanged(from: previous.windowTitle, to: current.windowTitle))
        }
        if previous.url != current.url {
            changes.append(.urlChanged(from: previous.url, to: current.url))
        }
        if previous.focusedElementID != current.focusedElementID {
            changes.append(.focusChanged(from: previous.focusedElementID, to: current.focusedElementID))
        }
        if previous.visibleElementCount != current.visibleElementCount {
            changes.append(.elementCountChanged(from: previous.visibleElementCount, to: current.visibleElementCount))
        }
        if previous.modalPresent != current.modalPresent {
            changes.append(.modalStateChanged(from: previous.modalPresent, to: current.modalPresent))
        }
        if previous.activeBranch != current.activeBranch {
            changes.append(.branchChanged(from: previous.activeBranch, to: current.activeBranch))
        }
        if previous.isGitDirty != current.isGitDirty {
            changes.append(.gitDirtyChanged(from: previous.isGitDirty, to: current.isGitDirty))
        }
        if previous.buildSucceeded != current.buildSucceeded {
            changes.append(.buildResultChanged(from: previous.buildSucceeded, to: current.buildSucceeded))
        }
        if previous.failingTestCount != current.failingTestCount {
            changes.append(.failingTestCountChanged(from: previous.failingTestCount, to: current.failingTestCount))
        }
        if previous.observationHash != current.observationHash {
            changes.append(.observationHashChanged(from: previous.observationHash, to: current.observationHash))
        }

        return StateDiff(changes: changes)
    }
}
