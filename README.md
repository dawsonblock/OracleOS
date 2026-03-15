# 🔮 Oracle-OS

> **The Autonomous Agent Kernel for macOS**
> 
> *One planner. One executor. One memory graph. Zero hallucination-loops.*

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14+-black.svg?logo=apple)](https://apple.com)
[![Architecture: Kernel/Sidecar](https://img.shields.io/badge/Arch-Kernel%2FSidecar-blue.svg)](#architecture)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](#license)

**Oracle-OS** is a canonical Swift implementation of an autonomous execution runtime. Engineered as a high-speed "brain" (kernel) governing Python and Docker "hands and eyes" (sidecars), it consolidates the capabilities of an entire suite of disparate AI tools into a single, unified, strictly typed, and policy-governed execution spine.

---

## ✨ Features

*   **🧠 Strict Execution Spine**: Actions no longer randomly loop. Every goal strictly flows: `Goal → Context Assembly → Plan → Gate → Execute → Trace → Memory`.
*   **🛡️ Type-Safe Execution (R4)**: End-to-end verification. No mutation fires without passing through the Swift `VerifiedActionExecutor` and `PolicyEngine` (with `.safe`, `.low`, and `.critical` runtime gates).
*   **🔗 Hybrid Microservices**: Lightning-fast 10ms Swift core handling context and planning, commanding Python sidecars (AST indexing, LLM interactions, headless browsers) via HTTP REST.
*   **💾 Unified Memory Truth-Store (R2)**: A native `sqlite3` `GraphStore` merges episodic traces, semantic workflow maps, and knowledge graphs into a single database.
*   **🔌 Native MCP Ready**: Embedded Context Protocol HTTP Listener out of the box, ready to expose generic functions to remote agents dynamically. 

---

## 🏗️ Architecture

Instead of falling into the standard "spaghetti code" trap of endless Python LLM loops, Oracle-OS operates fundamentally like a Unix Kernel. 

*   **Swift "Kernel" (`oracle-system`):** Handles planning, context token budgeting schemas, policy routing, memory persistence, and system-level operations.
*   **Python "Sidecars":** Lightweight HTTP microservices that execute tasks that Swift natively struggles with (running untrusted code in Docker, indexing abstract syntax trees via Tree-sitter, running Playwright).

### The Invariants (Core Rules)
Oracle-OS strictly adheres to its founding integration commandments:
1.  **R1 (One Planner):** One central entry point (`PlanGenerator`).
2.  **R2 (Unified Memory):** All state changes persist natively inside `GraphStore`.
3.  **R3 (Action Abstraction):** Tools must conform to the `ActionIntent` schema and be routed by `ActionRegistry`.
4.  **R4 (Verified Execution):** All external alterations must carry the `executedThroughExecutor` stamp.

---

## 🚀 Quick Start

### 1. Prerequisites
- **macOS 14+** (Sonoma or later)
- **Swift 5.9+** (`swift --version` to verify)
- **Python 3.12+**
- **Docker** (Required for the `OpenSandbox` code-execution sidecar)

### 2. Build & Setup
```bash
git clone https://github.com/dawsonblock/OracleOS.git
cd OracleOS

# Build the Swift package (Release mode for optimizations)
make build    # Runs standard: swift build
```

### 3. Running the Sidecars
Sidecars are necessary for advanced telemetry (parsing syntax, running code, searching the web).
```bash
make sidecars
```
*(Boots the microservices on ports `8080` through `8084`)*

### 4. Running Oracle
Start the interactive Oracle CLI shell REPL:
```bash
.build/release/oracle run
```
Or check the health of your overall configuration:
```bash
.build/release/oracle health
```

---

## 💻 CLI Command Reference

The `OracleCLI` orchestrates directly with the system.

| Command | Description |
| :--- | :--- |
| `oracle run` | Drops you into the autonomous `/repl` environment |
| `oracle goal "..."` | Feed a single direct goal for one-shot execution |
| `oracle health` | Pings system databases, sidecars, and internal pipelines |
| `oracle logs` | Analyzes local telemetry and traces |
| `oracle actions` | Lists all `ActionIntents` registered in the kernel |
| `oracle mcp` | Starts the headless HTTP MCP server on port `9100` |

### Interactive REPL Subcommands
Once dropped inside `oracle run`, you can use immediate chat-ops:
*   `/status` — Overview of memory and traces
*   `/history` — Local history log of action inputs and context frames
*   `/health` — Rapid sidecar and database connectivity checks
*   `/quit` — Gracefully exits the kernel

---

## 🗂️ System Module Map

```text
OracleOS/
├── Makefile
├── Package.swift
├── oracle/
│   ├── Sources/
│   │   ├── OracleOS/                # REPL and CLI Entry Point
│   │   └── OracleLib/               # The "Kernel" 
│   │       ├── Core/                # PolicyGate, ActionExecutor
│   │       ├── Agent/               # Master Planner
│   │       ├── Memory/              # SQLite GraphStore
│   │       ├── PromptEngine/        # Context Assembly
│   │       ├── Diagnostics/         # Analytics
│   │       ├── Search/              # Metasearch Engine
│   │       ├── BrowserAutomation/   # Headless Bridging
│   │       └── MCP/                 # Embedded Context Protocol
│   └── Tests/                       # Integration Validation
├── sidecars/                        # Python Sub-routines
│   ├── sandbox/                     # (8080) Untrusted code isolation
│   ├── codeindex/                   # (8081) AST code navigation 
│   ├── contextdb/                   # (8082) Long-horizon embeddings
│   ├── crawler/                     # (8083) Web parsing
│   └── metasearch/                  # (8084) SearXNG Web Retrieval
└── configs/                         # Model parameters
```

---

## 🧬 Repository Lineage

Oracle-OS was born from distilling patterns across 13 diverse AI implementations into an absolute canonical system:

*   `page-agent` / `browser-main` &rarr; Visual grounding and DOM parsing mapping into `BrowserAutomation`
*   `worktrunk` &rarr; Sandboxed Git / branch management pipelines mapping into `Experiments` 
*   `OpenSandbox` &rarr; Dockerized `sandbox` python sidecar executing code remotely
*   `cocoindex` / `sourcegraph` &rarr; Extracted into the AST `codeindex` microservice
*   `OpenViking` / `cody` &rarr; Abstracted into `PromptEngine` and `Memory` Graph
*   `MineContext` / `raptor` &rarr; Routed to semantic `Search` pipelines

---

## 🤝 Contributing
Modifications to the main execution spine (Rule R1) or memory persistence (Rule R2) are heavily scrutinized. Code tools should generally be merged into `sidecars/`, whereas macOS-specific utilities can live directly inside `oracle/Sources/OracleLib/Tools/`. Ensure you run tests before any merge:

```bash
make test
# executes swift test --enable-xctest
```

## 📄 License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
