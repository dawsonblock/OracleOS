import Foundation

// ─────────────────────────────────────────────────────────
// PerformanceMonitor — track timing of pipeline stages (Phase 18)
// ─────────────────────────────────────────────────────────

public final class PerformanceMonitor {

    public struct Measurement {
        public let label: String
        public let durationMs: Double
        public let timestamp: Date
    }

    private var measurements: [Measurement] = []

    public init() {}

    public func measure<T>(label: String, block: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(start) * 1000
        measurements.append(Measurement(label: label, durationMs: duration, timestamp: start))
        return result
    }

    public func summary() -> String {
        let lines = measurements.suffix(20).map { m in
            "  \(m.label): \(String(format: "%.1fms", m.durationMs))"
        }
        return "Performance (\(measurements.count) total):\n" + lines.joined(separator: "\n")
    }

    public func reset() { measurements.removeAll() }
}
