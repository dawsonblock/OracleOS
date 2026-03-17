import Foundation

/// Centralized manager for collecting and exporting runtime telemetry (Phase 16).
public final class TelemetryManager: Sendable {
    private let eventStore: DurableEventStore
    
    public init(eventStore: DurableEventStore = DurableEventStore()) {
        self.eventStore = eventStore
    }

    /// Records a specific performance metric.
    public func record(metricName: String, value: Double, tags: [String: String] = [:]) {
        // Log telemetry as specific events in the event store for auditing
        try? eventStore.append(event: ExecutionEvent(
            id: UUID(),
            timestamp: Date(),
            type: .stateChanged, // Tagged under telemetry in metadata
            commandId: nil,
            payload: [
                "telemetry_metric": metricName,
                "telemetry_value": String(value),
                "telemetry_tags": tags.description
            ]
        ) )
    }
}
