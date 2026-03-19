import Foundation

public final class ReplayEngine: Sendable {
    public let store: EventStore
    public let reducer: any Reducer

    public init(store: EventStore, reducer: any Reducer) {
        self.store = store
        self.reducer = reducer
    }

    public func rebuild() throws -> WorldState {
        let envelopes = try store.load()
        let events = try envelopes.map { try DomainEventCodec.decode(type: $0.type, data: $0.event) }
        return reducer.apply(events, to: .empty)
    }
}
