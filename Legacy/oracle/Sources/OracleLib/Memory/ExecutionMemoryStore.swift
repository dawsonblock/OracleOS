import Foundation

// MARK: - ExecutionMemoryStore

/// Wraps `AppMemoryStore` to provide execution-history ranking bias queries.
public struct ExecutionMemoryStore {
    private let store: AppMemoryStore

    public init(store: AppMemoryStore) {
        self.store = store
    }

    /// Bias for a labelled UI control in a given app.
    public func rankingBias(label: String?, app: String?, now: Date = Date()) -> Double {
        guard let label, let app else { return 0 }
        guard let control = store.preferredKnownControl(label: label, app: app) else { return 0 }
        let lowered = label.lowercased()
        let failureCount = store.failuresForApp(app).filter {
            $0.action.lowercased().contains(lowered)
        }.count
        return MemoryScorer.rankingBias(control: control, failureCount: failureCount, now: now)
    }

    /// The most recent successful recovery strategy for an app (if fresh enough).
    public func preferredRecoveryStrategy(app: String, now: Date = Date()) -> String? {
        guard let record = store.latestSuccessfulStrategy(app: app),
              MemoryPromotionPolicy.allowsStrategyReuse(record: record, now: now)
        else { return nil }
        return record.strategy
    }
}
