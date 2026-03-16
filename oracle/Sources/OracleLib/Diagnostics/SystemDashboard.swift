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
    private var metricsRecorder: MetricsRecorder?
    private var criticLoop: CriticLoop?

    public init(traceRecorder: TraceRecorder, eventBus: EventBus) {
        self.traceRecorder = traceRecorder
        self.eventBus = eventBus
    }

    /// Attach metrics recorder for enriched dashboards.
    public func attachMetrics(_ metrics: MetricsRecorder) {
        self.metricsRecorder = metrics
    }

    /// Attach critic loop for verdict statistics.
    public func attachCritic(_ critic: CriticLoop) {
        self.criticLoop = critic
    }

    // ── Summary snapshot ──────────────────────────────

    public struct DashboardSnapshot {
        public let totalActions: Int
        public let successRate: Double
        public let recentEvents: [String]
        public let uptime: TimeInterval
        public let criticSuccessRate: Double
        public let totalRecoveries: Int
        public let averageLatencyMs: Double
    }

    private let startTime = Date()

    public func snapshot() -> DashboardSnapshot {
        let events = traceRecorder.recentEvents(limit: 10000)
        let total = events.count
        let successes = events.filter { $0.outcome == .success }.count
        let rate = total > 0 ? Double(successes) / Double(total) : 1.0

        let criticRate = criticLoop?.overallSuccessRate() ?? rate
        let metricsSnap = metricsRecorder?.snapshot()

        return DashboardSnapshot(
            totalActions: total,
            successRate: rate,
            recentEvents: [],
            uptime: Date().timeIntervalSince(startTime),
            criticSuccessRate: criticRate,
            totalRecoveries: metricsSnap?.totalRecoveryAttempts ?? 0,
            averageLatencyMs: metricsSnap?.averageLatencyMs ?? 0
        )
    }

    public func printStatus() {
        printSummary()
    }

    public func printSummary() {
        let s = snapshot()
        print("""
        \u{250c}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500} Oracle Dashboard \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2510}
        \u{2502} Actions:     \(s.totalActions)
        \u{2502} Success:     \(String(format: "%.1f%%", s.successRate * 100))
        \u{2502} Critic:      \(String(format: "%.1f%%", s.criticSuccessRate * 100))
        \u{2502} Recoveries:  \(s.totalRecoveries)
        \u{2502} Avg Latency: \(String(format: "%.1fms", s.averageLatencyMs))
        \u{2502} Uptime:      \(String(format: "%.0fs", s.uptime))
        \u{2514}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2518}
        """)
    }
}
