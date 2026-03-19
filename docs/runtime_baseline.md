# Runtime Baseline

Captured during the deterministic runtime extraction.

## Environment

| Property | Value |
|----------|-------|
| Swift command | `swift` not available on this cloud agent PATH |
| Package manifest | `Package.swift` |
| Package name | `oracle-runtime` |
| Runtime targets | `Core`, `Interface`, `MultiAgent`, `App` |
| Enforcement test target | `ArchitectureEnforcement` |

## Build Status

Baseline commands requested by the plan were attempted:

```bash
swift --version
swift build
swift test
```

Observed result on this agent:

- `swift --version` failed with `swift: command not found`
- `swift build` could not be executed for the same reason
- `swift test` could not be executed for the same reason

The manifest and source layout were still hardened so the package is ready to validate once a Swift toolchain is present.

## Test Counts

Active enforcement suite under `Tests/ArchitectureEnforcement/`:

| Metric | Count |
|--------|-------|
| Test files | 6 |
| Support files | 1 |
| Test methods | 10 |

## Hygiene Status

- `README.md` has no merge-conflict markers
- `.build-corrupted/` was not present
- `.build-corrupted/` remains ignored in `.gitignore`
- Legacy package sources and tests were quarantined under `Legacy/`
- Active runtime code now lives only under `Sources/Core`, `Sources/Interface`, `Sources/MultiAgent`, and `Sources/App`
