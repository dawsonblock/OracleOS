# Runtime Spine

This document defines the canonical execution path through Oracle OS.
Every environment-mutating action must follow this spine. No side paths.

## Authoritative Execution Chain

```
Goal
  → Planner (via DecisionCoordinator)
  → ActionIntent
  → PolicyEngine.evaluate(intent:)
  → VerifiedActionExecutor.execute(command:perform:)
  → CriticLoop.evaluate(...)
  → TraceRecorder / DurableEventStore
  → WorldStateModel.apply(diff:)
  → Recovery (if needed)
```

## Key Components

### 1. Entry — `OracleRuntime`

`Sources/OracleOS/Runtime/OracleRuntime.swift`

Thin façade that owns subsystem references and provides lifecycle management.
Does **not** contain execution logic — delegates to `AgentLoop`.

### 2. Agent Loop — `AgentLoop`

`Sources/OracleOS/Agent/Loop/AgentLoop.swift`

The single orchestration loop. Coordinates:
- State observation (via `StateCoordinator`)
- World model update (via `StateDiffEngine` → `WorldStateModel`)
- Planning decision (via `DecisionCoordinator` → `Planner`)
- Execution (via `ExecutionCoordinator` → `VerifiedActionExecutor`)
- Learning (via `LearningCoordinator`)
- Recovery (via `RecoveryCoordinator`)

### 3. Planning — `Planner` / `PlanGenerator`

`Sources/OracleOS/Agent/Planning/Planner.swift`

One planner entry point (Rule R1). Chooses between OS, code, or mixed
planning paths. Produces `ActionIntent` — never executes directly.

### 4. Policy — `PolicyEngine`

`Sources/OracleOS/Core/Policy/PolicyEngine.swift`

Evaluates every `ActionIntent` before execution. Classifies risk as
`low`, `risky`, or `blocked`. Operates in three modes: `open`,
`confirmRisky`, `lockedDown`.

### 5. Verified Execution — `VerifiedActionExecutor`

`Sources/OracleOS/Core/Execution/VerifiedActionExecutor.swift`

The **sole authority** for environment mutations (Rule R4). Every action:
1. Is validated by `CommandValidator`
2. Captures pre-observation hash
3. Executes through the trust boundary
4. Captures post-observation hash
5. Verifies postconditions
6. Records events to `DurableEventStore`
7. Stamps `executedThroughExecutor = true`

The runtime rejects any `ActionResult` without the executor stamp.

### 6. Critic — `CriticLoop`

`Sources/OracleOS/Critic/CriticLoop.swift`

Post-action evaluation. Compares pre/post state to classify outcome as
`SUCCESS`, `PARTIAL_SUCCESS`, `FAILURE`, or `UNKNOWN`. Drives:
- Task graph edge promotion/demotion
- State memory updates
- Planning graph refinement

### 7. State Commitment

`Sources/OracleOS/Core/Commit/CommitCoordinator.swift`

Records atomic state changes to `DurableEventStore`. State advances
only through `WorldStateModel.apply(diff:)`.

### 8. Trace

`Sources/OracleOS/Core/Trace/TraceRecorder.swift`

Records verified deltas (not raw snapshots). Lean traces per Rule R11.

## Hard Rules

1. No file executes external actions except `VerifiedActionExecutor`
2. No state mutation outside the commitment pipeline
3. Planners choose structure — they never execute
4. The planner reads only committed world state (`WorldStateModel.snapshot`)
5. No frontend or script may bypass the executor
6. Every action result must carry `executedThroughExecutor = true`
