import Foundation

// ─────────────────────────────────────────────────────────
// OracleCLI — command-line interface for Oracle runtime
//
// Subcommands:
//   oracle run              — start interactive agent loop (REPL)
//   oracle goal "text"      — process a single goal then exit
//   oracle status           — show dashboard snapshot
//   oracle actions          — list registered actions
//   oracle health           — check sidecar connectivity
//   oracle mcp              — start MCP server mode
//   oracle version          — print version info
//   oracle help             — print usage
//
// All goal processing flows through OracleRuntime.process(goal:)
// which enforces the single execution spine.
// ─────────────────────────────────────────────────────────

public final class OracleCLI {

    private let runtime = OracleRuntime()
    private let version = "0.1.0"

    public init() {}

    public func run(args: [String]) {
        let subcommand = args.dropFirst().first ?? "run"

        // Always initialize runtime
        runtime.initialize()

        // Register extended tools
        registerExtendedTools()

        switch subcommand {
        case "run":
            startREPL()

        case "goal":
            let goalText = args.dropFirst(2).joined(separator: " ")
            guard !goalText.isEmpty else {
                printError("Usage: oracle goal \"<goal description>\"")
                return
            }
            processSingleGoal(goalText)

        case "status":
            showStatus()

        case "actions":
            listActions()

        case "health":
            checkHealth()

        case "mcp":
            startMCPServer()

        case "version", "--version", "-v":
            print("Oracle-OS v\(version)")

        case "help", "--help", "-h":
            printUsage()

        default:
            // Treat unknown args as a goal
            let goalText = args.dropFirst().joined(separator: " ")
            processSingleGoal(goalText)
        }
    }

    // ── REPL ────────────────────────────────────────────

    private func startREPL() {
        print("""
        ┌─────────────────────────────────────────┐
        │  Oracle-OS v\(version)                        │
        │  Interactive Agent Runtime               │
        │                                          │
        │  Type a goal, or:                        │
        │    /status   — dashboard snapshot         │
        │    /actions  — list registered actions     │
        │    /health   — check sidecar connectivity  │
        │    /history  — recent execution traces     │
        │    /quit     — exit                        │
        └─────────────────────────────────────────┘
        """)

        while true {
            print("\n\u{1B}[36moracle>\u{1B}[0m ", terminator: "")
            fflush(stdout)

            guard let line = readLine(strippingNewline: true) else {
                break  // EOF
            }

            let input = line.trimmingCharacters(in: .whitespaces)
            guard !input.isEmpty else { continue }

            switch input {
            case "/quit", "/exit", "/q":
                print("[oracle] Goodbye.")
                return

            case "/status":
                showStatus()

            case "/actions":
                listActions()

            case "/health":
                checkHealth()

            case "/history":
                showHistory()

            case let cmd where cmd.hasPrefix("/"):
                print("Unknown command: \(cmd). Type /quit to exit.")

            default:
                processSingleGoal(input)
            }
        }
    }

    // ── Goal processing ─────────────────────────────────

    private func processSingleGoal(_ text: String) {
        let goal = Goal(description: text)
        print("[oracle] Processing goal: \(text)")
        print("─────────────────────────────────────────────")
        runtime.process(goal: goal)
        print("─────────────────────────────────────────────")
        print("[oracle] Goal completed: \(goal.id.prefix(8))")
    }

    // ── Status ──────────────────────────────────────────

    private func showStatus() {
        runtime.diagnostics.printSummary()
        print("  Registered actions: \(ActionRegistry.shared.registeredActions().count)")
        print("  Trace events:      \(runtime.traceRecorder.eventCount())")
    }

    // ── Actions ─────────────────────────────────────────

    private func listActions() {
        let actions = ActionRegistry.shared.registeredActions()
        print("Registered actions (\(actions.count)):")
        for a in actions {
            print("  • \(a)")
        }
    }

    // ── Health ──────────────────────────────────────────

    private func checkHealth() {
        let http = HTTPClient(timeout: 3)

        let services: [(String, String)] = [
            ("Sandbox",    "http://127.0.0.1:8080"),
            ("Code Index", "http://127.0.0.1:8081"),
            ("Context DB", "http://127.0.0.1:8082"),
            ("Crawler",    "http://127.0.0.1:8083"),
            ("Metasearch", "http://127.0.0.1:8084"),
            ("Browser",    "http://127.0.0.1:9222"),
        ]

        print("Sidecar Health:")
        for (name, url) in services {
            let ok = http.isReachable(baseURL: url)
            let icon = ok ? "✓" : "✗"
            let color = ok ? "\u{1B}[32m" : "\u{1B}[31m"
            print("  \(color)\(icon)\u{1B}[0m \(name.padding(toLength: 12, withPad: " ", startingAt: 0)) \(url)")
        }
    }

    // ── History ─────────────────────────────────────────

    private func showHistory() {
        let events = runtime.traceRecorder.recentEvents(limit: 20)
        if events.isEmpty {
            print("(no execution traces yet)")
            return
        }
        print("Recent traces (\(events.count)):")
        for (i, e) in events.enumerated() {
            let mark = e.outcome == .success ? "✓" : (e.outcome == .blocked ? "⊘" : "✗")
            print("  \(String(format: "%2d", i + 1)). \(mark) \(e.action.type) — \(e.detail.prefix(60))")
        }
    }

    // ── MCP Server ──────────────────────────────────────

    private func startMCPServer() {
        let mcp = MCPServer()
        mcp.start(port: 9100)
        print("[mcp] Press Ctrl+C to stop.")

        // Start the MCP HTTP listener
        let listener = MCPHTTPListener(mcpServer: mcp, runtime: runtime)
        listener.start(port: 9100)
    }

    // ── Extended Tool Registration ──────────────────────

    private func registerExtendedTools() {
        ShellTool.register(in: ActionRegistry.shared)
        GitTool.register(in: ActionRegistry.shared)
        BrowserController.register(in: ActionRegistry.shared)
        ApplicationController.register(in: ActionRegistry.shared)
    }

    // ── Helpers ─────────────────────────────────────────

    private func printError(_ msg: String) {
        FileHandle.standardError.write(Data("error: \(msg)\n".utf8))
    }

    private func printUsage() {
        print("""
        Oracle-OS v\(version) — Autonomous Runtime System

        USAGE:
            oracle [subcommand] [options]

        SUBCOMMANDS:
            run              Start interactive REPL (default)
            goal "text"      Process a single goal then exit
            status           Show dashboard snapshot
            actions          List registered actions
            health           Check sidecar connectivity
            mcp              Start MCP server on port 9100
            version          Print version
            help             Show this help

        EXAMPLES:
            oracle run
            oracle goal "read the contents of README.md"
            oracle goal "list all Swift files in the current directory"
            oracle health
            oracle mcp
        """)
    }
}
