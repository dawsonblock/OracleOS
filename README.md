# Oracle-OS — Autonomous Runtime System

> The canonical kernel for THE_ORACLE project.  
> One planner. One executor. One memory graph. No exceptions.

## Architecture

Oracle-OS follows a strict single-spine execution model:

```
Goal → Context Assembly → Plan → Policy Gate → Execute → Verify → Trace → Memory
```

### Invariants (enforced at compile time and runtime)

| Rule | Description |
|------|-------------|
| **R1** | One planner entry point — `PlanGenerator` / `DecisionCoordinator` |
| **R2** | Three memory categories — Trace, Workflow, Knowledge Graph (all in `GraphStore`) |
| **R4** | All mutations flow through `VerifiedActionExecutor` (stamps `executedThroughExecutor`) |

### Module Map

```
oracle-system/
├── Package.swift               # Swift 5.9, macOS 14+, links sqlite3
├── oracle/Sources/OracleOS/    # Entry point (main.swift)
│
├── Core/
│   ├── Runtime/                # OracleRuntime, GoalInterpreter, IntentRouter, EventBus
│   ├── Execution/              # VerifiedActionExecutor, ActionRegistry, PolicyEngine
│   ├── Policy/                 # PolicyEngine, RiskEvaluator
│   └── Observation/            # Pre/post execution observation layer
│
├── Agent/
│   ├── Planning/               # PlanGenerator, PlanSimulator (R1 entry)
│   └── Reasoning/              # ReasoningEngine
│
├── Memory/
│   ├── Graph/                  # GraphStore — SQLite truth store (R2)
│   ├── ProjectMemory/          # ArtifactStore
│   └── Retrieval/              # ContextRetriever
│
├── PromptEngine/               # ContextAssembler, PromptBuilder, TokenBudgetManager
├── Tools/                      # ShellTool, GitTool, SandboxExecutor, MacServices
├── Search/                     # SearchController, WebExtractor, SearchRanking
├── BrowserAutomation/          # BrowserController, DOMIndexer, PageSnapshot
├── HostAutomation/             # ApplicationController, WindowController, FileSystem
├── CodeIntelligence/           # RepositoryIndexer, CodeQueryEngine, RepairPipeline
├── Experiments/                # PatchExperimentRunner, WorktreeSandbox
├── MCP/                        # MCPServer, MCPToolRegistry, ContextBridge
├── Diagnostics/                # SystemDashboard, ExecutionLogger, PerformanceMonitor
│
├── sidecars/
│   ├── sandbox/                # Docker-based execution (OpenSandbox adapter)
│   ├── codeindex/              # AST code search (cocoindex adapter)
│   ├── contextdb/              # Long-horizon retrieval (OpenViking adapter)
│   ├── metasearch/             # SearXNG web search
│   └── crawler/                # URL → markdown extraction
│
├── configs/                    # YAML configuration files
├── scripts/                    # Shell scripts for build/run/index/reset
├── data/                       # SQLite databases, artifacts
└── logs/                       # Runtime logs
```

## Quick Start

### Prerequisites

- macOS 14+ (Sonoma)
- Swift 5.9+ (`swift --version`)
- Python 3.12+ (for sidecars)
- Docker (optional, for sandbox and metasearch)

### Build

```bash
cd oracle-system
swift build
```

### Run

```bash
# Build and launch runtime
./scripts/start_oracle.sh

# In another terminal: start sidecars
./scripts/start_sidecars.sh
```

### Index a Repository

```bash
./scripts/index_repository.sh /path/to/repo
```

### Reset Memory (development)

```bash
./scripts/reset_memory.sh
```

## Sidecar Ports

| Service     | Port | Protocol |
|-------------|------|----------|
| Sandbox     | 8080 | HTTP     |
| Code Index  | 8081 | HTTP     |
| Context DB  | 8082 | HTTP     |
| Crawler     | 8083 | HTTP     |
| Metasearch  | 8084 | HTTP     |
| MCP Server  | 9100 | HTTP     |

## Source Repositories

Oracle-OS integrates concepts from 13 source repositories:

| Repository | Role in Oracle |
|-----------|---------------|
| Oracle-OS-main-4 | Original Swift runtime (architecture rules, Xcode project) |
| browser-main | Ghostty browser engine (zig) — browser automation substrate |
| page-agent-main | Page Agent / Peekaboo — visual grounding, DOM interaction |
| OpenSandbox-main | Docker sandbox execution environment |
| worktrunk-main | GitButler-style virtual branch management |
| raptor-main | Multi-search engine aggregation |
| OpenViking-main | Long-context retrieval, embeddings |
| cocoindex-code-main | Code indexing and AST search |
| cody-public-snapshot-main | AI coding assistant patterns, context retrieval |
| sourcegraph-public-snapshot-main | Code search infrastructure |
| MineContext-main | IDE context extraction |
| zvec-main | SIMD vector operations |

## License

See [LICENSE](../LICENSE).
