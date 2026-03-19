import Foundation

// MARK: - MemoryScorer

/// Computes bias and scoring signals from raw memory data.
public enum MemoryScorer {

    /// Bias for a known UI control — clamped to [0, 0.15].
    public static func rankingBias(
        control: KnownControl,
        failureCount: Int,
        now: Date = Date()
    ) -> Double {
        guard MemoryPromotionPolicy.allowsDurableBias(
            successes: control.successCount,
            failures: failureCount
        ) else { return 0 }
        let base = min(log(Double(control.successCount) + 1) * 0.05, 0.15)
        return base * MemoryDecayPolicy.freshnessMultiplier(since: control.lastUsed, now: now)
    }

    /// Bias for a repeated command pattern — clamped to [0, 0.15].
    public static func commandBias(successes: Int, failures: Int) -> Double {
        guard MemoryPromotionPolicy.allowsDurableBias(successes: successes, failures: failures) else {
            return 0
        }
        return min(log(Double(successes) + 1) * 0.05, 0.15)
    }

    /// Overall plan bias from a `MemoryInfluence` — clamped to [-0.3, 0.3].
    ///
    /// Weights:
    /// - execution history × 0.3 (primary positive signal)
    /// - command patterns × 0.2
    /// - preferred fix path +0.1
    /// - preferred paths +0.1
    /// - avoided paths −0.1
    /// - shouldPreferExperiments −0.05
    /// - riskPenalty × 0.5 (strongest negative factor)
    public static func planBias(influence: MemoryInfluence) -> Double {
        var bias = 0.0
        bias += influence.executionRankingBias * 0.3
        bias += influence.commandBias * 0.2
        if influence.preferredFixPath != nil { bias += 0.1 }
        if influence.shouldPreferExperiments { bias -= 0.05 }
        bias -= influence.riskPenalty * 0.5
        if !influence.avoidedPaths.isEmpty { bias -= 0.1 }
        if !influence.preferredPaths.isEmpty { bias += 0.1 }
        return max(-0.3, min(0.3, bias))
    }

    /// Score for a fix pattern — higher is better.
    public static func fixPatternScore(pattern: FixPattern, now: Date = Date()) -> Double {
        guard MemoryPromotionPolicy.allowsDurableBias(
            successes: pattern.successCount,
            failures: pattern.failureCount
        ) else { return 0 }
        let base = Double(pattern.successCount) - Double(pattern.failureCount) * 0.5
        return max(0, base) * MemoryDecayPolicy.freshnessMultiplier(since: pattern.lastAppliedAt, now: now)
    }
}
