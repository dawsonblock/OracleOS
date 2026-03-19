import Foundation

public protocol Reducer: Sendable {
    func apply(_ events: [any DomainEvent], to state: WorldState) -> WorldState
}

public final class DefaultReducer: Reducer, @unchecked Sendable {
    public init() {}

    public func apply(_ events: [any DomainEvent], to state: WorldState) -> WorldState {
        var newState = state

        for event in events {
            switch event.type {
            case FileWriteRequestedEvent.eventType:
                if let event = event as? FileWriteRequestedEvent {
                    newState.files[event.path] = event.content
                }
            case FileDeleteRequestedEvent.eventType:
                if let event = event as? FileDeleteRequestedEvent {
                    newState.files.removeValue(forKey: event.path)
                }
            case ShellExecutedEvent.eventType:
                if let event = event as? ShellExecutedEvent {
                    newState.lastOutput = event.output
                }
            case HTTPResponseEvent.eventType:
                if let event = event as? HTTPResponseEvent {
                    newState.lastHTTPResponseSize = event.size
                }
            default:
                continue
            }
        }

        return newState
    }
}
