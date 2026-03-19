import Foundation

public protocol Reducer: Sendable {
    func apply(_ events: [any DomainEvent], to state: WorldState) -> WorldState
}

public struct DefaultReducer: Reducer {
    public init() {}

    public func apply(_ events: [any DomainEvent], to state: WorldState) -> WorldState {
        var newState = state

        for event in events {
            switch event {
            case let event as FileWriteEvent:
                newState.files[event.path] = event.content
                newState.executionTrace.append(event.type)
            case let event as FileDeleteEvent:
                newState.files.removeValue(forKey: event.path)
                newState.executionTrace.append(event.type)
            case let event as ShellExecutedEvent:
                newState.lastOutput = event.output
                newState.executionTrace.append(event.type)
            case let event as HTTPResponseEvent:
                newState.lastHTTPResponseURL = event.url
                newState.lastHTTPResponseSize = event.body.utf8.count
                newState.executionTrace.append(event.type)
            default:
                continue
            }

            if !newState.executedCommandIDs.contains(event.commandID) {
                newState.executedCommandIDs.append(event.commandID)
            }
        }

        return newState
    }
}
