# Execution leak scan

This scan classifies remaining side-effect surfaces after the second boundary-tightening pass.

## A — allowed

These are the current authoritative locations for execution or execution-path selection:

- `Sources/OracleOS/Core/Execution/VerifiedExecutor.swift`
  - subprocess launch
  - synchronous HTTP requests
  - WebSocket request/response handling
- `Sources/OracleOS/Core/Execution/RuntimeFilesystem.swift`
  - centralized file append/save/delete helpers
- `Sources/OracleOS/Common/OracleProductPaths.swift`
  - centralized executable/path candidate lists
  - sidecar/model/install discovery paths

Current scan expectations:

- `rg "Process\(" Sources` -> only `VerifiedExecutor.swift`
- `rg "URLSession" Sources` -> only `VerifiedExecutor.swift`
- `rg "bash|sh -|/bin/" Sources` -> `VerifiedExecutor.swift` plus path-provider constants in `OracleProductPaths.swift`

## B — wrapped or isolated, but still transitional

These areas no longer instantiate `Process()` or `URLSession` directly, but still carry legacy setup/tooling behavior or file-backed persistence that is not yet fully reduced through the event spine:

### Legacy/setup surfaces

- `Sources/oracle/SetupWizard.swift`
- `Sources/oracle/Doctor.swift`
- `Sources/OracleOS/Vision/VisionBridge.swift`
- `Sources/OracleOS/Vision/VisionPerception.swift`

### File-backed persistence and tooling stores

The following persistence paths now route through `RuntimeFilesystem`, but the
callers still represent transitional file-backed state rather than pure reducer
reconstruction:

- `Sources/OracleOS/Core/Event/FileEventStore.swift`
- `Sources/OracleOS/Core/EventSourcing/DurableEventStore.swift`
- `Sources/OracleOS/Core/Trace/TraceStore.swift`
- `Sources/OracleOS/Core/Trace/FailureArtifactWriter.swift`
- `Sources/OracleOS/Core/Policy/ApprovalStore.swift`
- `Sources/OracleOS/Experiments/ExperimentManager.swift`
- `Sources/OracleOS/Recipes/RecipeStore.swift`
- `Sources/OracleOS/Diagnostics/**`
- `Sources/OracleOS/ProjectMemory/**`
- `Sources/OracleOS/Experiments/WorktreeSandbox.swift`
- `Sources/OracleController/ProductEnvironmentManager.swift`

## C — deleted or isolated

These shortcuts were removed from the active runtime boundary in this extraction:

- `Tests/OracleOSTests/Core/fix_world.py`
- direct helper scripts formerly under `scripts/` beyond the deterministic trio
- root-level duplicate runtime tree moved to `Legacy/oracle/`
- web and sidecar trees moved outside the Swift runtime into `Interface/`, `Infra/`, and `ThirdParty/`

## Progress from the previous pass

- shell and subprocess path literals were collapsed into shared providers
- `WorkspaceRunner`, repository git inspection, worktree helpers, host process launch, and vision startup now delegate through `VerifiedExecutor`
- direct `Process(` and `URLSession` creation in active runtime code was reduced to the verified boundary file
- core event, trace, approval, recipe, experiment, and project-memory stores were moved onto `RuntimeFilesystem`

## Remaining work

1. Reduce legacy setup/doctor behavior further or isolate it out of the active executable target.
2. Convert more file-backed stores from direct mutation to event-backed reducers where practical.
3. Separate persistence that is intentionally authoritative from convenience artifact writers.
