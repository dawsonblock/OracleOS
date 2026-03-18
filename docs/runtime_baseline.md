# Runtime Baseline

Captured during the `runtime-collapse` stabilisation pass.

## Environment

| Property | Value |
|----------|-------|
| Swift tools version | 5.9 |
| Minimum platform | macOS 14 |
| Package name | OracleOS |
| External dependencies | AXorcist 0.1.0 |

## Targets

| Target | Kind | Path |
|--------|------|------|
| `OracleOS` | library | `Sources/OracleOS` |
| `OracleControllerShared` | library | `Sources/OracleControllerShared` |
| `oracle` | executable | `Sources/oracle` |
| `OracleControllerHost` | executable | `Sources/OracleControllerHost` |
| `OracleController` | executable | `Sources/OracleController` |
| `OracleOSTests` | test | `Tests/OracleOSTests` |
| `OracleOSEvals` | test | `Tests/OracleOSEvals` |
| `OracleControllerTests` | test | `Tests/OracleControllerTests` |

## Build Status

macOS-only project (requires ScreenCaptureKit, AppKit, AXorcist).
Build must be run on a macOS host with Xcode toolchain:

```bash
swift build
```

## Test Coverage Areas

Tests are organised under `Tests/OracleOSTests/`:

- **Governance** — architectural rule enforcement (R1–R12)
- **Core** — execution kernel, world model, agent loop wiring
- **Planning** — planner selection, task graph navigation
- **Runtime** — runtime lifecycle, coordinator boundaries
- **Critic** — self-evaluation loop correctness
- **Recovery** — failure classification, strategy selection
- **StateAbstraction** — compressed UI state generation
- **BrowserAutomation** — browser bridge behaviour
- **CodeIntelligence** — program knowledge graph queries
- **Memory** — state memory index operations
- **TraceReplay** — deterministic replay validation

## Cleanup Actions Taken

- Deleted `.build-corrupted/` (stale Swift build artifacts committed to repo)
- Added `.build-corrupted/` to `.gitignore`
- Populated empty scripts (`bootstrap.sh`, `lint_all.sh`, `run_local_cluster.sh`)
- Populated empty docs (`runtime_spine.md`, `event_model.md`, `operations.md`, `cluster.md`)
- Removed root-level `fix_*.py` and `fix_*.sh` patch scripts (contained hardcoded local paths)
