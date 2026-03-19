import Foundation

public enum RuntimeViewBuilder {
    public static func stateSummary(from state: WorldState) -> RuntimeStateSummary {
        RuntimeStateSummary(
            fileCount: state.files.count,
            commandCount: state.executedCommandIDs.count,
            traceCount: state.executionTrace.count,
            failureCount: state.failureCount,
            lastFailure: state.lastFailure,
            lastFailedCommandType: state.lastFailedCommandType,
            lastFailureTimedOut: state.lastFailureTimedOut,
            lastHTTPResponseStatus: state.lastHTTPResponseStatus,
            lastHTTPResponseURL: state.lastHTTPResponseURL,
            lastHTTPResponseDurationMillis: state.lastHTTPResponseDurationMillis,
            lastHTTPResponseSize: state.lastHTTPResponseSize,
            lastOutputPreview: preview(state.lastOutput),
            lastTraceEntry: state.executionTrace.last ?? ""
        )
    }

    public static func eventSummary(from envelope: EventEnvelope) throws -> RuntimeEventSummary {
        let event = try DomainEventCodec.decode(type: envelope.type, data: envelope.event)

        switch event {
        case let event as ShellExecutedEvent:
            return RuntimeEventSummary(
                id: envelope.id,
                commandID: envelope.commandID,
                timestamp: envelope.timestamp,
                type: envelope.type,
                success: event.status == 0,
                timedOut: false,
                summary: "shell exited \(event.status): \(preview(event.command, limit: 80))",
                details: [
                    "command": event.command,
                    "status": String(event.status),
                    "duration_ms": String(event.durationMillis),
                ]
            )
        case let event as FileWriteRequestedEvent:
            return RuntimeEventSummary(
                id: envelope.id,
                commandID: envelope.commandID,
                timestamp: envelope.timestamp,
                type: envelope.type,
                success: true,
                timedOut: false,
                summary: "wrote \(event.path)",
                details: [
                    "path": event.path,
                    "bytes": String(event.content.utf8.count),
                ]
            )
        case let event as FileDeleteRequestedEvent:
            return RuntimeEventSummary(
                id: envelope.id,
                commandID: envelope.commandID,
                timestamp: envelope.timestamp,
                type: envelope.type,
                success: true,
                timedOut: false,
                summary: "deleted \(event.path)",
                details: ["path": event.path]
            )
        case let event as HTTPResponseEvent:
            return RuntimeEventSummary(
                id: envelope.id,
                commandID: envelope.commandID,
                timestamp: envelope.timestamp,
                type: envelope.type,
                success: (200..<500).contains(event.status),
                timedOut: false,
                summary: "http \(event.status): \(preview(event.url, limit: 80))",
                details: [
                    "url": event.url,
                    "status": String(event.status),
                    "size": String(event.size),
                    "duration_ms": String(event.durationMillis),
                ]
            )
        case let event as CommandFailedEvent:
            return RuntimeEventSummary(
                id: envelope.id,
                commandID: envelope.commandID,
                timestamp: envelope.timestamp,
                type: envelope.type,
                success: false,
                timedOut: event.timedOut,
                summary: event.reason,
                details: [
                    "command_type": event.commandType,
                    "timed_out": String(event.timedOut),
                ]
            )
        default:
            throw RuntimeError.unknownEvent(envelope.type)
        }
    }

    public static func eventSummaries(from envelopes: [EventEnvelope]) throws -> [RuntimeEventSummary] {
        try envelopes.map(eventSummary(from:))
    }

    private static func preview(_ text: String, limit: Int = 120) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: "\\n")
        guard normalized.count > limit else {
            return normalized
        }
        let index = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<index]) + "..."
    }
}
