import Foundation

// ─────────────────────────────────────────────────────────
// OSTargetResolver — shared resolution helpers for OS skills
//
// Resolves abstract queries against the world model snapshot
// using element matching with confidence thresholds.
// ─────────────────────────────────────────────────────────

public enum OSTargetResolver {

    /// Minimum confidence score to accept a candidate.
    public static let minConfidence: Double = 0.6

    /// Maximum ambiguity gap before rejecting as ambiguous.
    public static let maxAmbiguityGap: Double = 0.2

    /// Attempt to find a matching element in the world snapshot.
    public static func resolve(
        query: String,
        role: String? = nil,
        snapshot: WorldModelSnapshot
    ) -> (elementID: String, confidence: Double)? {
        // Use the snapshot's element list if available
        let elements = snapshot.elementLabels

        guard !elements.isEmpty else { return nil }

        // Score each element by query similarity
        var bestID: String?
        var bestScore: Double = 0.0
        var secondBest: Double = 0.0

        for (index, label) in elements.enumerated() {
            let score = similarity(query: query, label: label)

            // Role filter: if a role is specified, check prefix convention
            if let role = role, !label.lowercased().hasPrefix(role.lowercased()) {
                // Role mismatch penalty
                let penalized = score * 0.5
                if penalized > bestScore {
                    secondBest = bestScore
                    bestScore = penalized
                    bestID = "element_\(index)"
                } else if penalized > secondBest {
                    secondBest = penalized
                }
                continue
            }

            if score > bestScore {
                secondBest = bestScore
                bestScore = score
                bestID = "element_\(index)"
            } else if score > secondBest {
                secondBest = score
            }
        }

        guard let id = bestID, bestScore >= minConfidence else {
            return nil
        }

        // Check ambiguity
        let gap = bestScore - secondBest
        guard gap >= maxAmbiguityGap || secondBest < minConfidence else {
            return nil // Too ambiguous
        }

        return (id, bestScore)
    }

    /// Simple string similarity (normalized overlap of lowercased tokens).
    internal static func similarity(query: String, label: String) -> Double {
        let qTokens = Set(query.lowercased().split(separator: " ").map(String.init))
        let lTokens = Set(label.lowercased().split(separator: " ").map(String.init))

        guard !qTokens.isEmpty else { return 0 }

        let overlap = qTokens.intersection(lTokens).count
        let union = qTokens.union(lTokens).count

        guard union > 0 else { return 0 }

        // Jaccard similarity
        return Double(overlap) / Double(union)
    }
}
