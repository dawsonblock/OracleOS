import Foundation

// ─────────────────────────────────────────────────────────
// EventBus — lightweight internal pub/sub
//
// Allows subsystems to observe runtime events without
// tight coupling. No external system subscribes here.
// ─────────────────────────────────────────────────────────

public enum RuntimeEvent {
    case planGenerated(Plan)
    case actionCompleted(ActionIntent, ExecutionResult)
    case criticEvaluated(ActionIntent, CriticEvaluation)
    case recoveryAttempted(ActionIntent, RecoveryDecision)
    case goalCompleted(Goal)
    case goalAborted(Goal, String)  // goal + reason
    case policyBlocked(ActionIntent)
    case systemStarted
    case systemStopping
}

public final class EventBus {

    public typealias Handler = (RuntimeEvent) -> Void

    private var handlers: [Handler] = []

    public init() {}

    public func subscribe(_ handler: @escaping Handler) {
        handlers.append(handler)
    }

    public func emit(_ event: RuntimeEvent) {
        for handler in handlers {
            handler(event)
        }
    }
}
