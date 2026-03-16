# 🔮 Oracle-OS

> **The Autonomous Agent Kernel for macOS**
>
> *One planner. One executor. One memory graph. Zero hallucination-loops.*

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14+-black.svg?logo=apple)](https://apple.com)
[![Architecture: Kernel/Sidecar](https://img.shields.io/badge/Arch-Kernel%2FSidecar-blue.svg)](#-architecture)
[![Tests: 636 passing](https://img.shields.io/badge/Tests-636%20passing-brightgreen.svg)](#-testing)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](#-license)

**Oracle-OS** is a canonical Swift implementation of an autonomous execution runtime. Engineered as a high-speed "brain" (kernel) governing Python and Docker "hands and eyes" (sidecars), it consolidates the capabilities of an entire suite of disparate AI tools into a single, unified, strictly typed, and policy-governed execution spine.

---

## ✨ Features

| | |
| :--- | :--- |
| **🧠 Strict Execution Spine** | Every goal flows through a deterministic pipeline: `Goal → Context Assembly → Plan → Gate → Execute → Trace → Memory`. No random loops. |
| **🛡️ Verified Execution (R4)** | No mutation fires without passing through `VerifiedActionExecutor` and `PolicyEngine` with `.safe`, `.low`, and `.critical` runtime gates. |
| **📊 Task Graph Planning** | `TaskGraph` / `TaskNode` / `TaskEdge` maintain a persistent state-space graph. `GraphScorer` and `GraphNavigator` perform multi-factor beam-search for optimal action sequencing. |
| **🔄 Workflow Learning** | `WorkflowSynthesizer` → `WorkflowPromoter` → `WorkflowMatcher` pipeline automatically discovers, promotes, and reuses successful action sequences. |
| **🧩 Strategy System** | `StrategySelector` picks from `StrategyLibrary` entries (direct, browser, recovery, repo-repair, permission-resolution) with runtime confidence tracking via `StrategyEvaluator`. |
| **💾 Unified Memory (R2)** | Native `sqlite3` `GraphStore` merges episodic traces, semantic workflow maps, knowledge graphs, and project memory into a single database. |
| **🔧 Recovery Engine** | `FailureClassifier` → `RecoveryStrategySelector` → `RecoveryCoordinator` automatically diagnoses and recovers from build failures, modal blocks, permission errors, and more. |
| **🔗 Hybrid Microservices** | Sub-10ms Swift core commanding Python sidecars (code sandbox, AST indexing, web crawling) via HTTP REST. |
| **👁️ Vision Layer** | `VisionPerception` + `VisionBridge` + `ScreenCapture` for visual grounding through CDP and native macOS accessibility. |
| **🔌 Native MCP** | Embedded Model Context Protocol HTTP listener exposing kernel functions to remote agents on port `9100`. |
| **📝 Recipe Engine** | Declarative YAML/JSON recipes with parameter substitution, preconditions, and skip-on-failure policies for repeatable task automation. |
| **🏗️ Architecture Engine** | `ArchitectureEngine` enforces structural rules and reviews code changes against project conventions. |

---

## 🏗️ Architecture

Instead of falling into the standard "spaghetti code" trap of endless Python LLM loops, Oracle-OS operates fundamentally like a Unix Kernel.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Goal Input                               │
└──────────────────────────┬──────────────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  GoalClassifier → StrategySelector → ContextAssembler            │
│                    (StrategyLibrary)   (TokenBudgetManager)       │
└──────────────────────────┬───────────────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  PlanGenerator ← ReasoningEngine ← ProposalEngine                │
│       │            (OperatorRegistry)                             │
│       ├── TaskGraph (StateAbstractor → GraphScorer → Navigator)  │
│       ├── WorkflowMatcher (reuse promoted plans)                 │
│       └── PlanSimulator (simulate outcomes)                      │
└──────────────────────────┬───────────────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  PolicyEngine → VerifiedActionExecutor → CriticLoop              │
│  (.safe/.low/.critical)   (ActionRegistry)    (PostconditionV.)  │
└──────────────────────────┬───────────────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  TraceRecorder → MemoryRouter → GraphStore                       │
│     │              (MemoryScorer, DecayPolicy)                   │
│     ├── WorkflowSynthesizer → WorkflowPromoter                  │
│     ├── StateMemoryIndex (state → action recall)                 │
│     └── PatternMemoryStore (failure patterns)                    │
└──────────────────────────────────────────────────────────────────┘
```

### System Layers

| Layer | Role | Key Types |
| :--- | :--- | :--- |
| **Core/Runtime** | Lifecycle, configuration, event bus | `OracleRuntime`, `RuntimeConfig`, `RuntimeContext`, `RuntimeLifecycle` |
| **Core/Execution** | Action schema, verification, tracing | `ActionIntent`, `ActionRegistry`, `VerifiedActionExecutor`, `CriticLoop` |
| **Core/Policy** | Risk gating and sandbox routing | `PolicyEngine` |
| **Core/Observation** | UI element parsing, change detection | `Observation`, `UnifiedElement`, `ElementCandidate` |
| **Core/World** | World-state model, state diffing | `WorldStateModel`, `StateDiffEngine`, `StateCoordinator` |
| **Agent/Planning** | Plan generation, task graph, simulation | `PlanGenerator`, `TaskGraph`, `TaskGraphStore`, `PlanningGraphEngine` |
| **Agent/Reasoning** | LLM-backed plan proposals | `ReasoningEngine`, `ProposalEngine`, `OperatorRegistry` |
| **Agent/Loop** | Autonomous execution driver | `AgentLoop`, `AgentExecutionDriver` |
| **Strategy** | Goal-driven strategy selection | `StrategySelector`, `StrategyLibrary`, `StrategyEvaluator` |
| **Memory** | Persistence, retrieval, decay | `GraphStore`, `MemoryRouter`, `MemoryScorer`, `StateMemoryIndex` |
| **Workflows** | Workflow synthesis and reuse | `WorkflowSynthesizer`, `WorkflowPromoter`, `WorkflowMatcher`, `WorkflowIndex` |
| **Recovery** | Failure classification and recovery | `FailureClassifier`, `RecoveryStrategySelector`, `RecoveryCoordinator` |
| **Vision** | Screen understanding, element grounding | `VisionPerception`, `VisionBridge`, `CDPBridge` |
| **PromptEngine** | Context assembly, token budgeting | `ContextAssembler`, `PromptBuilder`, `TokenBudgetManager` |
| **HostAutomation** | macOS application/window/menu control | `ApplicationController`, `WindowController`, `MenuController` |
| **Diagnostics** | Telemetry, trace replay, dashboards | `TraceReplayEngine`, `MetricsRecorder`, `SystemDashboard` |
| **Recipes** | Declarative task automation | `RecipeEngine`, `RecipeStore` |
| **MCP** | Model Context Protocol server | `MCPServer`, `MCPHTTPListener` |
| **Search** | Multi-source search aggregation | `SearchController` |
| **BrowserAutomation** | Headless browser bridging | `PerceptionEngine` |

### The Invariants (Core Rules)

Oracle-OS strictly adheres to its founding integration commandments:

1. **R1 (One Planner):** One central entry point (`PlanGenerator`) — all plan candidates flow through a single ranking pipeline.
2. **R2 (Unified Memory):** All state changes persist natively inside `GraphStore` — no shadow state.
3. **R3 (Action Abstraction):** Every tool conforms to the `ActionIntent` schema and is routed by `ActionRegistry`.
4. **R4 (Verified Execution):** All external mutations carry the `executedThroughExecutor` stamp from `VerifiedActionExecutor`.

---

## 🚀 Quick Start

### 1. Prerequisites

- **macOS 14+** (Sonoma or later)
- **Swift 5.9+** (`swift --version` to verify)
- **Python 3.12+** (for sidecars)
- **Docker** (required for the `OpenSandbox` code-execution sidecar)

### 2. Build & Setup

```bash
git clone https://github.com/dawsonblock/OracleOS.git
cd OracleOS

# Build the Swift package
make build
```

### 3. Running the Sidecars

Sidecars are necessary for advanced capabilities (code execution, AST parsing, web retrieval).

```bash
make sidecars
```

*(Boots the microservices on ports `8080` through `8084`)*

### 4. Running Oracle

Start the interactive Oracle CLI shell REPL:

```bash
.build/debug/oracle run
```

Or check the health of your overall configuration:

```bash
.build/debug/oracle health
```

---

## 💻 CLI Command Reference

The `OracleCLI` orchestrates directly with the runtime.

| Command | Description |
| :--- | :--- |
| `oracle run` | Drops you into the autonomous `/repl` environment |
| `oracle goal "..."` | Feed a single direct goal for one-shot execution |
| `oracle health` | Pings system databases, sidecars, and internal pipelines |
| `oracle logs` | Analyzes local telemetry and traces |
| `oracle actions` | Lists all `ActionIntents` registered in the kernel |
| `oracle mcp` | Starts the headless HTTP MCP server on port `9100` |

### Interactive REPL Subcommands

Once inside `oracle run`:

| Subcommand | Description |
| :--- | :--- |
| `/status` | Overview of memory, traces, and runtime health |
| `/history` | Local history log of action inputs and context frames |
| `/health` | Rapid sidecar and database connectivity checks |
| `/quit` | Gracefully exits the kernel |

---

## 🗂️ System Module Map

```text
OracleOS/
├── Makefile
├── Package.swift
├── oracle/
│   ├── Sources/
│   │   ├── OracleOS/                    # CLI entry point (thin executable)
│   │   └── OracleLib/                   # The Kernel
│   │       ├── Core/
│   │       │   ├── Runtime/             # OracleRuntime, RuntimeConfig, EventBus
│   │       │   ├── Execution/           # ActionIntent, ActionRegistry, VerifiedActionExecutor
│   │       │   ├── Policy/              # PolicyEngine (.safe/.low/.critical gates)
│   │       │   ├── Observation/         # Observation, UnifiedElement, ElementCandidate
│   │       │   ├── World/               # WorldStateModel, StateDiffEngine
│   │       │   ├── PlanningState/       # PlannerDecision, StateBundle
│   │       │   ├── ActionSchema/        # ActionContract, ActionDomain
│   │       │   └── StateAbstraction/    # StateAbstractionEngine
│   │       ├── Agent/
│   │       │   ├── Planning/            # PlanGenerator, PlanSimulator, PlanningGraphEngine
│   │       │   │   └── TaskGraph/       # TaskGraph, TaskNode, TaskEdge, GraphScorer, GraphNavigator
│   │       │   ├── Reasoning/           # ReasoningEngine, ProposalEngine, OperatorRegistry
│   │       │   ├── Loop/               # AgentLoop, AgentExecutionDriver
│   │       │   └── Skills/             # OS-level skill implementations
│   │       ├── Strategy/               # StrategySelector, StrategyLibrary, StrategyEvaluator
│   │       ├── Memory/
│   │       │   ├── Graph/              # GraphStore (sqlite3), StateNode, EdgeTransition
│   │       │   ├── Retrieval/          # MemoryRouter, MemoryScorer
│   │       │   ├── Learning/           # WorkflowPatternMiner
│   │       │   └── ProjectMemory/      # Long-term project context
│   │       ├── Workflows/              # WorkflowSynthesizer, WorkflowPromoter, WorkflowMatcher
│   │       ├── Recovery/               # FailureClassifier, RecoveryStrategySelector
│   │       ├── Vision/                 # VisionPerception, VisionBridge, ScreenCapture
│   │       ├── PromptEngine/           # ContextAssembler, TokenBudgetManager
│   │       ├── HostAutomation/         # ApplicationController, WindowController, MenuController
│   │       ├── Diagnostics/            # TraceReplayEngine, MetricsRecorder, SystemDashboard
│   │       ├── Recipes/                # RecipeEngine, RecipeStore
│   │       ├── Search/                 # SearchController, CandidateGenerator
│   │       ├── BrowserAutomation/      # PerceptionEngine, headless browser bridging
│   │       ├── MCP/                    # MCPServer, MCPHTTPListener
│   │       ├── CodeExecution/          # Sandbox client, code runner
│   │       ├── CodeIntelligence/       # AST analysis client
│   │       ├── Engineering/            # PatchPipeline
│   │       ├── Experiments/            # PatchExperimentRunner
│   │       ├── Architecture/           # ArchitectureEngine, rule enforcement
│   │       ├── Actions/                # Action definitions, FocusManager
│   │       ├── Graph/                  # CandidateGraph, StableGraph, GraphPruner
│   │       ├── Tools/                  # Additional tool integrations
│   │       └── Common/                 # Shared utilities
│   └── Tests/
│       └── OracleTests/                # 636 tests — XCTest suite
├── sidecars/                           # Python microservices
│   ├── sandbox/                        # (8080) Docker code-execution isolation
│   ├── codeindex/                      # (8081) Tree-sitter AST navigation
│   ├── contextdb/                      # (8082) Long-horizon embeddings
│   ├── crawler/                        # (8083) Web page parsing
│   └── metasearch/                     # (8084) SearXNG web retrieval
├── configs/                            # Model parameters and configuration
├── scripts/                            # Helper scripts (sidecars, indexing, reset)
├── data/                               # Runtime data stores
└── logs/                               # Execution logs
```

---

## 🧪 Testing

The project maintains **636 tests** across 60+ test suites covering every subsystem — from low-level `TaskEdge` statistics to full `PipelineIntegration` end-to-end validation.

```bash
make test
# Executes: swift test

# Tests complete in ~1.7 seconds on arm64
```

Key test coverage areas:

- **Core pipeline**: `PipelineIntegrationTests`, `VerifiedActionExecutorTests`, `PolicyEngineTests`
- **Planning**: `PlanGeneratorTests`, `PlanCandidateTests`, `TaskGraphTests`, `TaskGraphStoreTests`
- **Reasoning**: `ReasoningEngineExtensionTests`, `OperatorRegistryTests`, `ProposalEngineTests`
- **Strategy**: `StrategySelectorTests`, `StrategyEvaluatorTests`, `StrategyLibraryTests`
- **Memory**: `StateMemoryIndexTests`, `PatternMemoryStoreTests`, `TraceCompressorTests`
- **Workflows**: `WorkflowSynthesizerTests`, `WorkflowPromoterTests`, `WorkflowMatcherTests`
- **Recovery**: `RecoveryCoordinatorTests`, `RecoveryStrategySelectorTests`, `FailureClassifierTests`
- **World state**: `WorldStateModelTests`, `StateDiffEngineTests`, `StateAbstractionEngineTests`
- **Vision**: `VisionLayerTests`, `PerceptionEngineTests`, `ObservationTests`
- **Recipes**: `RecipeEngineTests`, `RecipeStoreTests`, `RecipeTypesTests`

---

## 🧬 Repository Lineage

Oracle-OS was born from distilling patterns across 13 diverse AI implementations into a single canonical system:

| Source Repo | Maps Into |
| :--- | :--- |
| `page-agent` / `browser-main` | `BrowserAutomation`, `Vision` — visual grounding and DOM parsing |
| `worktrunk` | `Experiments` — sandboxed Git / branch management pipelines |
| `OpenSandbox` | `sidecars/sandbox` — Dockerized Python code execution |
| `cocoindex` / `sourcegraph` | `sidecars/codeindex` — AST navigation microservice |
| `OpenViking` / `cody` | `PromptEngine`, `Memory`, `Reasoning` — LLM orchestration and graph persistence |
| `MineContext` / `raptor` | `Search` — semantic retrieval pipelines |

---

## 🤝 Contributing

Modifications to the main execution spine (Rule R1) or memory persistence (Rule R2) are heavily scrutinized. Follow these guidelines:

- **Sidecar tools** → add to `sidecars/`
- **macOS-specific utilities** → add to `oracle/Sources/OracleLib/Tools/`
- **New operators** → register in `OperatorRegistry` with preconditions and cost
- **New recovery strategies** → add entries to `RecoveryStrategyLibrary`

All changes must pass the full test suite before merge:

```bash
make test
```

---

## 📄 License

[MIT](LICENSE)


## 📄 License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
