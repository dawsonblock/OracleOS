import Foundation

/// Legacy replay entry point bridged to the append-only runtime event store.
public final class DeterministicReplayEngine: Sendable {
    private let replayEngine: ReplayEngine
    private let stateDiffEngine: StateDiffEngine

    public init(
        eventStore: DurableEventStore = DurableEventStore(),
        stateDiffEngine: StateDiffEngine = StateDiffEngine()
    ) {
        _ = eventStore
        self.stateDiffEngine = stateDiffEngine
        self.replayEngine = ReplayEngine(
            store: FileEventStore(
                path: OracleProductPaths.logsDirectory
                    .appendingPathComponent("runtime-events.jsonl", isDirectory: false)
                    .path
            ),
            reducer: DefaultReducer()
        )
    }

    public func replay(until targetDate: Date) async throws -> WorldState {
        _ = targetDate
        _ = stateDiffEngine
        return try replayEngine.rebuild()
    }
}
