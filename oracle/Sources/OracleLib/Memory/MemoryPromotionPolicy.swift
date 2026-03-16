import Foundation

// MARK: - MemoryPromotionPolicy

/// Governs when memory signals are strong enough to influence decisions.
public enum MemoryPromotionPolicy {
    public static let minimumSuccessfulUses = 3
    public static let maximumFailureRate = 0.25
    public static let strategyFreshnessWindow: TimeInterval = 60 * 60 * 24 * 30

    /// Returns `true` when the success/failure ratio meets the durable-bias threshold.
    public static func allowsDurableBias(successes: Int, failures: Int) -> Bool {
        let total = successes + failures
        guard successes >= minimumSuccessfulUses, total > 0 else { return false }
        let failureRate = Double(failures) / Double(total)
        return failureRate <= maximumFailureRate
    }

    /// Returns `true` when the strategy record is recent enough to reuse.
    public static func allowsStrategyReuse(record: StrategyRecord, now: Date = Date()) -> Bool {
        guard record.success else { return false }
        return now.timeIntervalSince(record.timestamp) <= strategyFreshnessWindow
    }
}
