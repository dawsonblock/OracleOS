import Foundation

// ─────────────────────────────────────────────────────────
// SystemDashboard — runtime health + telemetry (Phase 18)
//
// Exposes a text-based summary of system state for:
//   - the prompt engine (included in context)
//   - CLI diagnostics
//   - future web dashboard
//
// Reads from EventBus, TraceRecorder, ExecutionState.
// ─────────────────────────────────────────────────────────

public final class SystemDashboard {

    private let traceRecorder: TraceRecorder
    private let eventBus: EventBus

    public init(traceRecorder: TraceRecorder, eventBus: EventBus) {
        self.traceRecorder = traceRecorder
        self.eventBus = eventBus
    }

    // ── Summary snapshot ──────────────────────────────

    public struct DashboardSnapshot {
        public let totalActions: Int
        public let successRate: Double
        public let recentEvents: [String]
        public let uptime: TimeInterval
    }

    private let startTime = Date()

    public func snapshot() -> DashboardSnapshot {
        let events = traceRecorder.recentEvents(limit: 10000)
        let total = events.count
        let successes = events.filter { $0.outcome == .success }.count
        let rate = total > 0 ? Double(successes) / Double(total) : 1.0

        return DashboardSnapshot(
            totalActions: total,
            successRate: rate,
            recentEvents: [],
            uptime: Date().timeIntervalSince(startTime)
        )
    }

    public func printStatus() {
        printSummary()
    }

    public func printSummary() {
        let s = snapshot()
        print("""
        ┌──────── Oracle Dashboard ────────┐
        │ Actions:     \(s.totalActions)
        │ Success:     \(String(format: "%.1f%%", s.successRate * 100))
        │ Uptime:      \(String(format: "%.0fs", s.uptime))
        └──────────────────────────────────┘
        """)
    }
}
