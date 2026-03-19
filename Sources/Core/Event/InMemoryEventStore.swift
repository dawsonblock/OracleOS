import Foundation

public final class InMemoryEventStore: EventStore, @unchecked Sendable {
    private var envelopes: [EventEnvelope]
    private let encoder = JSONEncoder()

    public init(envelopes: [EventEnvelope] = []) {
        self.envelopes = envelopes
    }

    public func append(_ events: [any DomainEvent]) throws {
        for event in events {
            let payload = try DomainEventCodec.encode(event)
            envelopes.append(
                EventEnvelope(
                    id: event.id,
                    commandID: event.commandID,
                    type: event.type,
                    event: payload
                )
            )
        }
    }

    public func load() throws -> [EventEnvelope] {
        envelopes
    }

    public func reset() {
        envelopes.removeAll()
    }

    public func snapshotData() throws -> Data {
        try encoder.encode(envelopes)
    }
}
