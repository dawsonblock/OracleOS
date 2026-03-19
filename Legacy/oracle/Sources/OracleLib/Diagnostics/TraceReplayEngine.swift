import Foundation

// ─────────────────────────────────────────────────────────
// TraceReplayEngine — deterministic execution replay
//
// Records execution steps as ReplayStep values from critic
// verdicts. Collects steps into ReplayTrace for an entire
// session. Compares expected traces against replayed traces
// and surfaces divergences for debugging and regression
// analysis.
//
// Deterministic replay makes debugging autonomous behaviour
// tractable. Every step records the pre/post state hash,
// action name, critic outcome, and latency.
// ─────────────────────────────────────────────────────────

/// One atomic step in a replay trace.
public struct ReplayStep: Equatable {

    public let stepIndex: Int
    public let actionType: String
    public let actionID: String
    public let preStateHash: String
    public let postStateHash: String
    public let verdict: CriticVerdict
    public let latencyMs: Double
    public let timestamp: Date

    public init(
        stepIndex: Int,
        actionType: String,
        actionID: String,
        preStateHash: String,
        postStateHash: String,
        verdict: CriticVerdict,
        latencyMs: Double
    ) {
        self.stepIndex = stepIndex
        self.actionType = actionType
        self.actionID = actionID
        self.preStateHash = preStateHash
        self.postStateHash = postStateHash
        self.verdict = verdict
        self.latencyMs = latencyMs
        self.timestamp = Date()
    }

    public static func == (lhs: ReplayStep, rhs: ReplayStep) -> Bool {
        return lhs.actionType == rhs.actionType
            && lhs.preStateHash == rhs.preStateHash
            && lhs.postStateHash == rhs.postStateHash
            && lhs.verdict == rhs.verdict
    }
}

/// A complete session trace containing all replay steps.
public struct ReplayTrace {

    public let id: String
    public let goalID: String
    public let goalDescription: String
    public private(set) var steps: [ReplayStep]
    public let startedAt: Date
    public var completedAt: Date?

    public init(goalID: String, goalDescription: String) {
        self.id = UUID().uuidString
        self.goalID = goalID
        self.goalDescription = goalDescription
        self.steps = []
        self.startedAt = Date()
    }

    mutating public func addStep(_ step: ReplayStep) {
        steps.append(step)
    }

    mutating public func complete() {
        completedAt = Date()
    }

    public var totalLatencyMs: Double {
        return steps.reduce(0) { $0 + $1.latencyMs }
    }

    public var successCount: Int {
        return steps.filter { $0.verdict == .success }.count
    }

    public var failureCount: Int {
        return steps.filter { $0.verdict == .failure }.count
    }
}

/// A divergence detected between an expected trace and a replayed trace.
public struct TraceDivergence {
    public let stepIndex: Int
    public let expected: ReplayStep?
    public let actual: ReplayStep?
    public let reason: String

    public init(stepIndex: Int, expected: ReplayStep?, actual: ReplayStep?, reason: String) {
        self.stepIndex = stepIndex
        self.expected = expected
        self.actual = actual
        self.reason = reason
    }
}

/// TraceReplayEngine records and compares execution traces.
public final class TraceReplayEngine {

    /// All recorded traces, keyed by trace ID
    private var traces: [String: ReplayTrace] = [:]

    /// Currently active trace (one at a time)
    private var activeTraceID: String?

    public init() {}

    // ── Recording ───────────────────────────────────────

    /// Begin recording a new trace for a goal.
    /// Returns the trace ID.
    @discardableResult
    public func beginTrace(goalID: String, goalDescription: String) -> String {
        var trace = ReplayTrace(goalID: goalID, goalDescription: goalDescription)
        let id = trace.id
        traces[id] = trace
        activeTraceID = id
        print("[replay] Trace started: \(id.prefix(8)) for goal: \(goalDescription.prefix(40))")
        return id
    }

    /// Record a step into the currently active trace.
    public func recordStep(
        actionType: String,
        actionID: String,
        preStateHash: String,
        postStateHash: String,
        verdict: CriticVerdict,
        latencyMs: Double
    ) {
        guard let id = activeTraceID, var trace = traces[id] else {
            print("[replay] WARNING: no active trace for step recording")
            return
        }

        let step = ReplayStep(
            stepIndex: trace.steps.count,
            actionType: actionType,
            actionID: actionID,
            preStateHash: preStateHash,
            postStateHash: postStateHash,
            verdict: verdict,
            latencyMs: latencyMs
        )

        trace.addStep(step)
        traces[id] = trace
    }

    /// Complete the currently active trace.
    public func endTrace() -> ReplayTrace? {
        guard let id = activeTraceID, var trace = traces[id] else { return nil }
        trace.complete()
        traces[id] = trace
        activeTraceID = nil
        print("[replay] Trace ended: \(id.prefix(8)) (\(trace.steps.count) steps, \(String(format: "%.1fms", trace.totalLatencyMs)))")
        return trace
    }

    // ── Queries ─────────────────────────────────────────

    /// Get a trace by ID.
    public func trace(id: String) -> ReplayTrace? {
        return traces[id]
    }

    /// Get all completed traces.
    public func completedTraces() -> [ReplayTrace] {
        return traces.values.filter { $0.completedAt != nil }
    }

    /// Recent traces by completion time.
    public func recentTraces(limit: Int = 10) -> [ReplayTrace] {
        return completedTraces()
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    /// Get trace for a specific goal ID (most recent).
    public func trace(forGoal goalID: String) -> ReplayTrace? {
        return traces.values
            .filter { $0.goalID == goalID }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    // ── Comparison / Replay ─────────────────────────────

    /// Compare two traces and return divergences.
    ///
    /// A divergence occurs when:
    /// - Step count differs
    /// - Action types differ at the same index
    /// - Pre/post state hashes differ at the same index
    /// - Verdicts differ at the same index
    public static func compare(expected: ReplayTrace, actual: ReplayTrace) -> [TraceDivergence] {
        var divergences: [TraceDivergence] = []

        let maxSteps = max(expected.steps.count, actual.steps.count)

        for i in 0..<maxSteps {
            let exp = i < expected.steps.count ? expected.steps[i] : nil
            let act = i < actual.steps.count ? actual.steps[i] : nil

            if exp == nil {
                divergences.append(TraceDivergence(
                    stepIndex: i, expected: nil, actual: act,
                    reason: "extra step in actual trace: \(act?.actionType ?? "?")"
                ))
            } else if act == nil {
                divergences.append(TraceDivergence(
                    stepIndex: i, expected: exp, actual: nil,
                    reason: "missing step in actual trace: \(exp?.actionType ?? "?")"
                ))
            } else if exp != act {
                var reasons: [String] = []
                if exp!.actionType != act!.actionType {
                    reasons.append("action: \(exp!.actionType) vs \(act!.actionType)")
                }
                if exp!.preStateHash != act!.preStateHash {
                    reasons.append("preState diverged")
                }
                if exp!.postStateHash != act!.postStateHash {
                    reasons.append("postState diverged")
                }
                if exp!.verdict != act!.verdict {
                    reasons.append("verdict: \(exp!.verdict.rawValue) vs \(act!.verdict.rawValue)")
                }
                divergences.append(TraceDivergence(
                    stepIndex: i, expected: exp, actual: act,
                    reason: reasons.joined(separator: "; ")
                ))
            }
        }

        return divergences
    }

    /// Render a trace as an ASCII timeline for diagnostics.
    public func renderTrace(_ trace: ReplayTrace) -> String {
        guard !trace.steps.isEmpty else { return "(empty trace)" }

        var lines: [String] = [
            "=== Replay Trace \(trace.id.prefix(8)) ===",
            "Goal: \(trace.goalDescription.prefix(60))",
            "Steps: \(trace.steps.count) | Latency: \(String(format: "%.1fms", trace.totalLatencyMs))",
            "Success: \(trace.successCount)/\(trace.steps.count)",
            "---"
        ]

        for step in trace.steps {
            let mark: String
            switch step.verdict {
            case .success: mark = "+"
            case .partialSuccess: mark = "~"
            case .failure: mark = "x"
            case .unknown: mark = "?"
            }
            lines.append(String(format: " %2d [%@] %-20s %6.1fms  %@ -> %@",
                                step.stepIndex,
                                mark,
                                (step.actionType as NSString).utf8String!,
                                step.latencyMs,
                                String(step.preStateHash.prefix(8)),
                                String(step.postStateHash.prefix(8))))
        }

        lines.append("===")
        return lines.joined(separator: "\n")
    }
}
