import Foundation

// ─────────────────────────────────────────────────────────
// TraceCompressor — collapses raw TraceEvent streams into
// reusable pattern summaries for memory and planning.
// ─────────────────────────────────────────────────────────

/// A compressed summary of repeated action/domain sequences.
public struct CompressedTracePattern: Sendable, Equatable {

    /// Fingerprint of the state/domain context (e.g. "browser|navigateTo").
    public let stateFingerprint: String

    /// Canonical action type string.
    public let actionName: String

    /// Whether the majority outcome for this pattern was success.
    public let resultSuccess: Bool

    /// How many times this pattern was observed.
    public let occurrences: Int

    /// Average elapsed milliseconds (0 when timing not available in source events).
    public let averageElapsedMs: Double

    public init(
        stateFingerprint: String,
        actionName: String,
        resultSuccess: Bool,
        occurrences: Int,
        averageElapsedMs: Double = 0.0
    ) {
        self.stateFingerprint = stateFingerprint
        self.actionName = actionName
        self.resultSuccess = resultSuccess
        self.occurrences = occurrences
        self.averageElapsedMs = averageElapsedMs
    }
}

/// Controls how much detail is retained when filtering observations.
public enum TraceVerbosity: Sendable {
    /// Keep only the focused element; strip all others.
    case minimal
    /// Pass the observation through unchanged.
    case full
}

/// Compresses `TraceEvent` arrays into pattern summaries.
public struct TraceCompressor: Sendable {

    public init() {}

    // MARK: – Compression

    /// Groups events by (domain, actionType) key, returning deduplicated pattern summaries
    /// sorted by descending occurrence count, then ascending action name.
    public func compress(events: [TraceEvent]) -> [CompressedTracePattern] {
        guard !events.isEmpty else { return [] }

        struct Accumulator {
            var successCount: Int = 0
            var totalCount: Int = 0
        }

        var accumulators: [String: Accumulator] = [:]

        for event in events {
            let key = patternKey(for: event)
            var acc = accumulators[key, default: Accumulator()]
            acc.totalCount += 1
            if event.outcome == .success {
                acc.successCount += 1
            }
            accumulators[key] = acc
        }

        var patterns: [CompressedTracePattern] = []
        for (key, acc) in accumulators {
            let parts = key.split(separator: "|", maxSplits: 1)
            let fingerprint = parts.count == 2 ? String(parts[0]) : key
            let actionName  = parts.count == 2 ? String(parts[1]) : key
            let resultSuccess = acc.successCount >= (acc.totalCount / 2 + 1)

            patterns.append(CompressedTracePattern(
                stateFingerprint: fingerprint,
                actionName: actionName,
                resultSuccess: resultSuccess,
                occurrences: acc.totalCount,
                averageElapsedMs: 0.0
            ))
        }

        return patterns.sorted {
            if $0.occurrences != $1.occurrences { return $0.occurrences > $1.occurrences }
            return $0.actionName < $1.actionName
        }
    }

    // MARK: – Success rate

    /// Returns the ratio of successful patterns to total patterns in the slice.
    public func successRate(for patterns: [CompressedTracePattern]) -> Double {
        guard !patterns.isEmpty else { return 0.0 }
        let successCount = patterns.filter { $0.resultSuccess }.count
        return Double(successCount) / Double(patterns.count)
    }

    // MARK: – Observation filtering

    /// Returns a filtered copy of the observation based on verbosity.
    /// `.minimal` keeps only the focused element; `.full` is a no-op.
    public func filter(observation: Observation, verbosity: TraceVerbosity) -> Observation {
        switch verbosity {
        case .full:
            return observation
        case .minimal:
            let retained: [UnifiedElement]
            if let focusedID = observation.focusedElementID {
                retained = observation.elements.filter { $0.id == focusedID }
            } else {
                retained = []
            }
            return Observation(
                app: observation.app,
                windowTitle: observation.windowTitle,
                url: observation.url,
                focusedElementID: observation.focusedElementID,
                elements: retained
            )
        }
    }

    // MARK: – Private helpers

    /// Stable grouping key: "<domain>|<actionType>"
    private func patternKey(for event: TraceEvent) -> String {
        "\(event.action.domain.rawValue)|\(event.action.type)"
    }
}
