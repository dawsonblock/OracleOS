import Foundation

// ─────────────────────────────────────────────────────────
// MetricsRecorder — runtime performance metrics
//
// Tracks core metrics required by R12 (Benchmark gating):
//   • Task success rate
//   • Average steps per goal
//   • Recovery count
//   • Action success rates by type
//   • Patch success rate (code intelligence)
//   • Search cycle statistics
//
// Merges that degrade core metrics are blocked until the
// regression is understood (enforced by CI).
// ─────────────────────────────────────────────────────────

/// Snapshot of all tracked metrics at a point in time.
public struct MetricsSnapshot {
    public let taskSuccessRate: Double
    public let averageStepsPerGoal: Double
    public let totalRecoveryAttempts: Int
    public let totalGoalsProcessed: Int
    public let totalActionsExecuted: Int
    public let actionSuccessRate: Double
    public let averageLatencyMs: Double
    public let timestamp: Date

    public init(
        taskSuccessRate: Double,
        averageStepsPerGoal: Double,
        totalRecoveryAttempts: Int,
        totalGoalsProcessed: Int,
        totalActionsExecuted: Int,
        actionSuccessRate: Double,
        averageLatencyMs: Double
    ) {
        self.taskSuccessRate = taskSuccessRate
        self.averageStepsPerGoal = averageStepsPerGoal
        self.totalRecoveryAttempts = totalRecoveryAttempts
        self.totalGoalsProcessed = totalGoalsProcessed
        self.totalActionsExecuted = totalActionsExecuted
        self.actionSuccessRate = actionSuccessRate
        self.averageLatencyMs = averageLatencyMs
        self.timestamp = Date()
    }
}

/// Records and aggregates runtime metrics.
public final class MetricsRecorder {

    // ── Goal tracking ───────────────────────────────────

    private var goalsProcessed: Int = 0
    private var goalsSucceeded: Int = 0

    // ── Action tracking ─────────────────────────────────

    private var actionsExecuted: Int = 0
    private var actionsSucceeded: Int = 0
    private var actionsByType: [String: (attempts: Int, successes: Int)] = [:]

    // ── Recovery tracking ───────────────────────────────

    private var recoveryAttempts: Int = 0

    // ── Latency tracking ────────────────────────────────

    private var latencies: [Double] = []  // in milliseconds
    private static let maxLatencySamples = 1000

    // ── Step tracking ───────────────────────────────────

    private var stepsPerGoal: [Int] = []

    public init() {}

    // ── Recording API ───────────────────────────────────

    /// Record a goal completion.
    public func recordGoal(success: Bool, stepCount: Int) {
        goalsProcessed += 1
        if success { goalsSucceeded += 1 }
        stepsPerGoal.append(stepCount)
    }

    /// Record an action execution.
    public func recordAction(type: String, success: Bool) {
        actionsExecuted += 1
        if success { actionsSucceeded += 1 }

        var stats = actionsByType[type, default: (attempts: 0, successes: 0)]
        stats.attempts += 1
        if success { stats.successes += 1 }
        actionsByType[type] = stats
    }

    /// Record a recovery attempt.
    public func recordRecovery() {
        recoveryAttempts += 1
    }

    /// Record an action latency in milliseconds.
    public func recordLatency(_ ms: Double) {
        latencies.append(ms)
        // Bounded buffer — drop oldest samples
        if latencies.count > MetricsRecorder.maxLatencySamples {
            latencies.removeFirst(latencies.count - MetricsRecorder.maxLatencySamples)
        }
    }

    // ── Snapshot ─────────────────────────────────────────

    /// Generate a point-in-time metrics snapshot.
    public func snapshot() -> MetricsSnapshot {
        let taskRate = goalsProcessed > 0
            ? Double(goalsSucceeded) / Double(goalsProcessed)
            : 0

        let avgSteps = stepsPerGoal.isEmpty
            ? 0
            : Double(stepsPerGoal.reduce(0, +)) / Double(stepsPerGoal.count)

        let actionRate = actionsExecuted > 0
            ? Double(actionsSucceeded) / Double(actionsExecuted)
            : 0

        let avgLatency = latencies.isEmpty
            ? 0
            : latencies.reduce(0, +) / Double(latencies.count)

        return MetricsSnapshot(
            taskSuccessRate: taskRate,
            averageStepsPerGoal: avgSteps,
            totalRecoveryAttempts: recoveryAttempts,
            totalGoalsProcessed: goalsProcessed,
            totalActionsExecuted: actionsExecuted,
            actionSuccessRate: actionRate,
            averageLatencyMs: avgLatency
        )
    }

    // ── Per-type queries ────────────────────────────────

    /// Success rate for a specific action type.
    public func successRate(forAction type: String) -> Double {
        guard let stats = actionsByType[type], stats.attempts > 0 else { return 0 }
        return Double(stats.successes) / Double(stats.attempts)
    }

    /// All tracked action types and their stats.
    public func allActionStats() -> [(type: String, attempts: Int, successes: Int, rate: Double)] {
        return actionsByType.map { (type, stats) in
            let rate = stats.attempts > 0 ? Double(stats.successes) / Double(stats.attempts) : 0
            return (type: type, attempts: stats.attempts, successes: stats.successes, rate: rate)
        }.sorted { $0.type < $1.type }
    }

    // ── Summary ─────────────────────────────────────────

    /// Human-readable metrics summary.
    public func summary() -> String {
        let s = snapshot()
        return """
        [metrics] Goals: \(s.totalGoalsProcessed) (success: \(String(format: "%.0f%%", s.taskSuccessRate * 100)))
        [metrics] Actions: \(s.totalActionsExecuted) (success: \(String(format: "%.0f%%", s.actionSuccessRate * 100)))
        [metrics] Avg steps/goal: \(String(format: "%.1f", s.averageStepsPerGoal))
        [metrics] Recovery attempts: \(s.totalRecoveryAttempts)
        [metrics] Avg latency: \(String(format: "%.1fms", s.averageLatencyMs))
        """
    }

    /// Reset all metrics.
    public func reset() {
        goalsProcessed = 0
        goalsSucceeded = 0
        actionsExecuted = 0
        actionsSucceeded = 0
        actionsByType.removeAll()
        recoveryAttempts = 0
        latencies.removeAll()
        stepsPerGoal.removeAll()
    }
}
