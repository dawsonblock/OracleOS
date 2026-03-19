## oracle-runtime

`oracle-runtime` is a deterministic Swift runtime kernel for controlled local execution. The repository is structured to make the runtime boundary obvious: the only first-party executable logic lives under `Sources/`, and sidecars, web projects, vendors, and older package shapes are isolated outside the runtime.

## Quick start

```bash
swift build
swift test
```

## Runtime spine

The execution contract is now:

1. `Planner` produces `Command` values only.
2. `VerifiedExecutor` is the side-effect boundary.
3. `FileEventStore` appends domain events.
4. `Reducer` rebuilds `WorldState`.
5. `Critic` evaluates results.
6. `RepairEngine` proposes follow-up commands.

Entry points should flow through:

`request -> goal -> AgentRuntime.run(goal:)`

## Repository layout

```text
oracle-runtime/
├── Sources/
│   ├── Core/               # Kernel, command, execution, event, state, critic, repair
│   ├── Interface/          # HTTP and CLI surfaces
│   ├── MultiAgent/         # Shared runtime coordination
│   └── App/                # Executable bootstrap
├── Tests/
│   └── ArchitectureEnforcement/
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
├── Legacy/                 # Archived pre-kernel package and tests
├── README.md
└── Package.swift
```

## Core rules

- `Sources/Core/Execution/VerifiedExecutor.swift` owns subprocess, filesystem mutation, and outbound network execution.
- Planner layers do not mutate state or call host APIs directly.
- State is derived from append-only events and replayable.
- Frontends and sidecars are isolated from direct runtime mutation.
- `Tests/ArchitectureEnforcement/` scans the repo for architectural bypasses.

## Documentation

Primary documents:

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [ARCHITECTURE_RULES.md](ARCHITECTURE_RULES.md)
- [docs/runtime_baseline.md](docs/runtime_baseline.md)
- [docs/runtime_spine.md](docs/runtime_spine.md)

## Status

This extraction intentionally favors a visible runtime boundary over compatibility with the archived `OracleOS` package shape. Older controllers, tests, and experimental flows have been moved under `Legacy/` so the active package can enforce a smaller deterministic contract.
