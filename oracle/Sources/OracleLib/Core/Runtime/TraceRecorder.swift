import Foundation

// ─────────────────────────────────────────────────────────
// TraceRecorder — immutable execution evidence
//
// Stores verified deltas: action proposals, executor results,
// verification outcomes, committed state changes.
// Full AX trees, DOM snapshots, large filesystem dumps excluded
// from normal traces (debug mode only).
// ─────────────────────────────────────────────────────────

public enum TraceOutcome: String {
    case success
    case failure
    case blocked
    case unknown
}

public struct TraceEvent {

    public let id: String
    public let timestamp: Date
    public let action: ActionIntent
    public let outcome: TraceOutcome
    public let detail: String

    public init(
        action: ActionIntent,
        outcome: TraceOutcome,
        detail: String = "",
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.timestamp = Date()
        self.action = action
        self.outcome = outcome
        self.detail = detail
    }
}

public final class TraceRecorder {

    private var events: [TraceEvent] = []

    public init() {}

    public func record(_ event: TraceEvent) {
        events.append(event)
        print("[trace] \(event.outcome.rawValue): \(event.action.type) — \(event.detail)")
    }

    public func recentEvents(limit: Int = 50) -> [TraceEvent] {
        return Array(events.suffix(limit))
    }

    public func eventCount() -> Int {
        return events.count
    }

    public func eventsForAction(type: String) -> [TraceEvent] {
        return events.filter { $0.action.type == type }
    }
}
