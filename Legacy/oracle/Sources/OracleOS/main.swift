import Foundation
import OracleLib

// ─────────────────────────────────────────────────────────
// Oracle System — Bootable Kernel
//
// Execution spine:
//   goal → context → plan → policy → execute → verify → trace → memory
//
// Every world-changing action routes through VerifiedActionExecutor.
// No sidecar, tool, or adapter may mutate state directly.
// ─────────────────────────────────────────────────────────

let cli = OracleCLI()
cli.run(args: CommandLine.arguments)
