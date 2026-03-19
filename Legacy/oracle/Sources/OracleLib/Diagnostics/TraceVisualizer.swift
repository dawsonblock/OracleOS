import Foundation

// ─────────────────────────────────────────────────────────
// TraceVisualizer — ASCII trace timeline (Phase 18)
//
// Renders execution traces into a human-readable timeline.
// ─────────────────────────────────────────────────────────

public final class TraceVisualizer {

    public init() {}

    public func render(traces: [ExecutionTrace]) -> String {
        guard !traces.isEmpty else { return "(no traces)" }

        var lines: [String] = ["─── Execution Timeline ───"]
        for (i, t) in traces.enumerated() {
            let mark = t.success ? "✓" : "✗"
            let ver  = t.verified ? "V" : " "
            lines.append(String(format: " %2d │ %@ [%@] %@ (%@)",
                                i + 1,
                                mark,
                                ver,
                                t.actionType,
                                String(t.id.prefix(8))))
        }
        lines.append("──────────────────────────")
        return lines.joined(separator: "\n")
    }
}
