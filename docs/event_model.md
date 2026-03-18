# Event Model

This document defines the event types, storage, and replay capabilities
of the Oracle OS runtime.

## Design Principles

- **Immutability** — events are append-only; once written they are never modified.
- **Deterministic replay** — the full system state can be reconstructed by
  replaying the event log from the beginning.
- **Lean traces** — normal traces store verified deltas (action proposals,
  executor results, verification outcomes, committed state changes). Full
  AX trees, DOM snapshots, and filesystem dumps are stored only in debug mode
  (Rule R11).

## Event Types

### ExecutionEvent

Defined in `Sources/OracleOS/Core/EventSourcing/DurableEventStore.swift`.

```
ExecutionEvent
  id:        UUID
  timestamp: Date
  type:      EventType
  commandId: UUID?
  payload:   [String: String]
```

Event types:
| Type | Meaning |
|------|---------|
| `command_issued` | A command was created by the planner |
| `command_validated` | The command passed `CommandValidator` checks |
| `command_executing` | Execution has started in `VerifiedActionExecutor` |
| `command_completed` | Execution finished (success or failure) |
| `state_changed` | An atomic state mutation was committed |

### TraceEvent

Defined in `Sources/OracleOS/Core/Trace/TraceEvent.swift`.

Captures one verified execution step with:
- Schema version and session/task/step IDs
- Action name, target, selected element
- Pre/post observation hashes
- Planning state ID
- Postcondition and verification status
- Success/failure classification
- Recovery strategy (if any)
- Critic verdict and code intelligence signals

### StateChange

Defined in `Sources/OracleOS/Core/Commit/CommitCoordinator.swift`.

```
StateChange
  entityId: String
  type:     created | updated | deleted
  data:     [String: String]
```

## Storage

### DurableEventStore

`Sources/OracleOS/Core/EventSourcing/DurableEventStore.swift`

Append-only JSONL file acting as the Write-Ahead Log (WAL). Events are
serialised with `JSONEncoder` and appended one per line.

### TraceStore

`Sources/OracleOS/Core/Trace/TraceStore.swift`

Persistent storage for `TraceEvent` records. Provides session-scoped
queries and replay support.

## Replay

### DeterministicReplayEngine

`Sources/OracleOS/Core/EventSourcing/DeterministicReplayEngine.swift`

Replays the event log to reconstruct system state at any point in time.
Used for debugging, regression analysis, and offline evaluation.

### TraceReplayEngine

`Sources/OracleOS/TraceReplay/TraceReplayEngine.swift`

Records execution steps as `ReplayStep` values and compares expected
traces against replayed traces. Surfaces divergences for debugging.

## Commitment Pipeline

```
VerifiedActionExecutor completes action
  → DurableEventStore.append(event:)       (WAL)
  → CommitCoordinator.commit(change:)       (state delta)
  → WorldStateModel.apply(diff:)            (in-memory model)
  → TraceRecorder.record(...)               (trace evidence)
```

State is always derivable from the event log. The in-memory
`WorldStateModel` is an optimisation — it can be rebuilt from events.
