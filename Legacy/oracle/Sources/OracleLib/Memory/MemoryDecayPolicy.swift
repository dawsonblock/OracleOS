import Foundation

// MARK: - MemoryDecayPolicy

/// Governs how memory signals decay over time.
public enum MemoryDecayPolicy {

    /// Returns a multiplier in [0, 1] based on how recently `date` occurred.
    ///
    /// - Returns 1.0 within the fresh window (default 30 days).
    /// - Returns 0.0 beyond the stale window (default 90 days).
    /// - Linearly interpolates between the two.
    public static func freshnessMultiplier(
        since date: Date,
        now: Date = Date(),
        freshWindow: TimeInterval = 60 * 60 * 24 * 30,
        staleWindow: TimeInterval = 60 * 60 * 24 * 90
    ) -> Double {
        let age = now.timeIntervalSince(date)
        if age <= freshWindow { return 1 }
        if age >= staleWindow { return 0 }
        let progress = (age - freshWindow) / max(staleWindow - freshWindow, 1)
        return max(0, 1 - progress)
    }
}
