import Foundation

public final class CommitCoordinator: Sendable {
    private let store: any EventStore

    public init(
        store: any EventStore = FileEventStore(
            path: OracleProductPaths.logsDirectory
                .appendingPathComponent("runtime-events.jsonl", isDirectory: false)
                .path
        )
    ) {
        self.store = store
    }

    public func commit(_ events: [any DomainEvent]) {
        try? store.append(events)
    }
}
