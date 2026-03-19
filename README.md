## Oracle OS

Oracle OS is a Swift runtime kernel for controlled local execution. The repository is structured to make the runtime boundary obvious: core runtime code stays in `Sources/`, tests stay Swift-only in `Tests/`, and sidecars, web projects, vendors, and legacy trees are isolated outside the runtime.

## Quick start

```bash
swift build
swift test
```

## Runtime spine

The execution contract is now:

1. `Planner` produces commands only.
2. `VerifiedExecutor` is the side-effect boundary.
3. `CommitCoordinator` appends domain events.
4. `Reducer` rebuilds `WorldState`.
5. `Critic` evaluates results.
6. `RepairEngine` proposes follow-up commands.

Entry points should flow through:

```text
request -> goal -> AgentRuntime.run(goal:)
```

## Repository layout

```text
oracle-runtime/
├── Sources/                # Swift runtime and executables
├── Tests/                  # Swift-only tests
├── docs/                   # Centralized documentation
├── scripts/                # Minimal deterministic helper scripts
├── Interface/
│   └── Web/                # Isolated frontend and browser projects
├── Observability/
│   ├── Diagnostics/        # Diagnostic artifacts and baselines
│   └── Memory/             # Project memory and historical notes
├── Infra/
│   └── Sidecars/           # Sidecars and non-runtime infrastructure
├── ThirdParty/
│   ├── OpenViking/
│   └── Vendor/
├── Legacy/
│   └── oracle/
├── ARCHITECTURE.md
├── ARCHITECTURE_RULES.md
├── README.md
└── Package.swift
```

## Core rules

- `Sources/OracleOS/Core/Execution/VerifiedExecutor.swift` owns subprocess and network execution.
- Planner layers do not mutate state or call host APIs directly.
- State is derived from append-only events and replayable.
- Frontends and sidecars are isolated from direct runtime mutation.

## Documentation

Primary documents:

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [ARCHITECTURE_RULES.md](ARCHITECTURE_RULES.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/runtime_spine.md](docs/runtime_spine.md)
- [docs/event_model.md](docs/event_model.md)
- [docs/operations.md](docs/operations.md)
- [docs/governance.md](docs/governance.md)
- [docs/runtime_baseline.md](docs/runtime_baseline.md)
- [docs/rollout_plan.md](docs/rollout_plan.md)

Additional notes such as change history, contribution guidance, and MCP references now live under `docs/`.

## Status

This extraction intentionally favors a visible runtime boundary over compatibility with old sidecars, repair scripts, and frontend shortcuts. Some integrations may remain broken until they are reintroduced through controlled interfaces.
