import Foundation

// ─────────────────────────────────────────────────────────
// TokenBudgetManager — estimate and cap token usage (Phase 6)
//
// Uses rough 4-chars-per-token heuristic.
// Phase 6: integrate real tokenizer (tiktoken or similar).
// ─────────────────────────────────────────────────────────

public final class TokenBudgetManager {

    public let maxTokens: Int

    public init(maxTokens: Int = 8192) {
        self.maxTokens = maxTokens
    }

    /// Rough token count estimate (4 chars ≈ 1 token).
    public func estimate(text: String) -> Int {
        return text.count / 4
    }

    /// Truncate text to fit within budget.
    public func truncate(text: String) -> String {
        let limit = maxTokens * 4
        if text.count <= limit { return text }
        let idx = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<idx]) + "\n…[truncated]"
    }

    /// Check if text fits within the budget.
    public func fits(text: String) -> Bool {
        return estimate(text: text) <= maxTokens
    }
}
