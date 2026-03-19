import Foundation

public struct ReplayEngine: Sendable {
    public let store: any EventStore
    public let reducer: any Reducer

    public init(store: any EventStore, reducer: any Reducer) {
        self.store = store
        self.reducer = reducer
    }

    public func rebuild() throws -> WorldState {
        let envelopes = try store.load()
        let events = try envelopes.map { envelope in
            try DomainEventCodec.decode(type: envelope.type, data: envelope.event)
        }
        return reducer.apply(events, to: .empty)
    }
}
