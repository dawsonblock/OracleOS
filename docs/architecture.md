# Runtime Architecture

The Oracle OS v2 runtime is designed as a deterministic, event-sourced, cluster-capable platform.

## Execution Spine

1. **Goal**: User or capsule intent.
2. **Planner**: Selects strategy and produces a **PlannerDecision**.
3. **Command**: Validated instructions for execution.
4. **VerifiedActionExecutor**: The singular authority for side-effects.
5. **CommitCoordinator**: Orchestrates durable event logging (WAL).
6. **Reducers**: Pure, deterministic functions that derive state from the event log.
7. **World State**: A structured projection of reality.

## Invariants

- **Single Execution Path**: Side effects only occur via `VerifiedActionExecutor`.
- **Authoritative Event Log**: All state must be reproducible from the committed event stream.
- **Raft Consensus**: In cluster mode, only majority-committed entries are applied to state.
