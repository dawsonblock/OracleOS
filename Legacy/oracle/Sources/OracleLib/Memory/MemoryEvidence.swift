import Foundation

// MARK: - MemoryTier

/// The tier of memory a piece of evidence came from.
public enum MemoryTier: String, Codable, Sendable, CaseIterable {
    case execution
    case pattern
    case workflow
    case project
    case residue
}

// MARK: - MemoryEvidence

/// A single piece of evidence contributing to a `MemoryInfluence`.
public struct MemoryEvidence: Sendable, Equatable {
    public let tier: MemoryTier
    public let summary: String
    public let sourceRefs: [String]
    public let confidence: Double

    public init(
        tier: MemoryTier,
        summary: String,
        sourceRefs: [String] = [],
        confidence: Double = 0
    ) {
        self.tier = tier
        self.summary = summary
        self.sourceRefs = sourceRefs
        self.confidence = confidence
    }
}
