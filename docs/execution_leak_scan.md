# Execution leak scan

This scan classifies remaining side-effect surfaces after the runtime extraction.

## A — allowed

These are the current authoritative execution boundary locations:

- `Sources/OracleOS/Core/Execution/VerifiedExecutor.swift`
  - subprocess launch
  - synchronous HTTP requests
  - WebSocket request/response handling

## B — wrapped, but still visible at call sites

These paths no longer instantiate `Process()` or `URLSession` directly, but still carry shell or executable path details that should be collapsed behind higher-level command factories in a follow-up pass:

- `Sources/oracle/SetupWizard.swift`
- `Sources/oracle/Doctor.swift`
- `Sources/OracleOS/Vision/VisionBridge.swift`
- `Sources/OracleOS/CodeExecution/WorkspaceRunner.swift`
- `Sources/OracleOS/CodeIntelligence/RepositoryIndexer.swift`
- `Sources/OracleOS/Experiments/WorktreeSandbox.swift`
- `Sources/OracleController/HostProcessClient.swift`
- command-spec producers under `Sources/OracleOS/Agent/**` and `Sources/OracleOS/CodeExecution/**`

## C — deleted or isolated

These shortcuts were removed from the active runtime boundary in this pass:

- `Tests/OracleOSTests/Core/fix_world.py`
- direct helper scripts formerly under `scripts/` beyond the deterministic trio
- root-level duplicate runtime tree moved to `Legacy/oracle/`
- web and sidecar trees moved outside the Swift runtime into `Interface/`, `Infra/`, and `ThirdParty/`

## Remaining work

1. Collapse shell path literals into command factories so scan output becomes semantic rather than path-based.
2. Route remaining file mutation stores through explicit event-backed reducers where practical.
3. Remove or further isolate setup/doctor behavior if they remain outside the trusted runtime spine.
