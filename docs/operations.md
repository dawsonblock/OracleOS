# Operations

This document describes how to build, run, test, and debug Oracle OS.

## Prerequisites

- macOS 14+
- Xcode 15+ (or Swift 5.9+ toolchain)
- AXorcist dependency (resolved automatically via Swift Package Manager)

## Build

```bash
# Full build (all targets)
swift build

# Build only the oracle CLI executable
swift build --product oracle

# Or use the bootstrap script
scripts/bootstrap.sh
```

## Run

```bash
# Run the oracle CLI
swift run oracle

# Or use the helper script
scripts/run_local_cluster.sh
```

The `oracle` executable is defined in `Sources/oracle/main.swift`.

## Test

```bash
# Run all tests
swift test

# Run only governance tests (architectural rule enforcement)
swift test --filter Governance

# Run a specific test class
swift test --filter ExecutionBoundaryTests

# Run tests for a specific subsystem
swift test --filter OracleOSTests
```

## Lint

```bash
# Run available linters and governance checks
scripts/lint_all.sh
```

Requires `swift-format` or `swiftformat` for formatting checks.

## Project Structure

| Path | Purpose |
|------|---------|
| `Sources/OracleOS/` | Core runtime library |
| `Sources/OracleOS/Core/` | Execution, policy, trace, command, state, events |
| `Sources/OracleOS/Agent/` | Agent loop, planning, skills, recovery |
| `Sources/OracleOS/Runtime/` | Runtime façade, coordinators, lifecycle |
| `Sources/oracle/` | CLI executable entry point |
| `Tests/OracleOSTests/` | Unit and integration tests |
| `Tests/OracleOSEvals/` | Evaluation benchmarks |

## Debugging

### Trace Inspection

Every executed action produces a `TraceEvent` written to the trace store.
To inspect the execution history:

1. Events are stored in the `DurableEventStore` (JSONL format)
2. Trace events contain pre/post observation hashes for diffing
3. Use `TraceReplayEngine` to replay and compare execution traces

### State Inspection

The authoritative world state is always available via
`WorldStateModel.snapshot`. The snapshot includes:
- Active application and window title
- Visible element count
- Repository state (branch, dirty status)
- Build/test status
- Planning state ID

### Event Log

The `DurableEventStore` records every command lifecycle event:
- `command_issued` → `command_validated` → `command_executing` → `command_completed`
- `state_changed` for every committed mutation

### Governance Checks

Architectural rules (R1–R12) are enforced by tests in
`Tests/OracleOSTests/Governance/`. Run these to verify structural integrity:

```bash
swift test --filter Governance
```
