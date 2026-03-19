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
            case let event as FileWriteRequestedEvent:
                newState.files[event.path] = event.content
                newState.executionTrace.append("\(event.type)#\(event.commandID.uuidString)")
            case let event as FileDeleteRequestedEvent:
                newState.files.removeValue(forKey: event.path)
                newState.executionTrace.append("\(event.type)#\(event.commandID.uuidString)")
            case let event as ShellExecutedEvent:
                newState.lastOutput = event.output
                newState.executionTrace.append("\(event.type)#\(event.commandID.uuidString)")
            case let event as HTTPResponseEvent:
                newState.lastHTTPResponseSize = event.size
                newState.lastHTTPResponseStatus = event.status
                newState.lastHTTPResponseURL = event.url
                newState.lastHTTPResponseDurationMillis = event.durationMillis
                newState.executionTrace.append("\(event.type)#\(event.commandID.uuidString)")
            case let event as CommandFailedEvent:
                newState.failureCount += 1
                newState.lastFailure = event.reason
                newState.lastFailedCommandType = event.commandType
                newState.lastFailureTimedOut = event.timedOut
                newState.executionTrace.append("\(event.type)#\(event.commandID.uuidString)")
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
