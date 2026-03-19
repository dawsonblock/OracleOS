import Foundation

// MARK: - MemoryInfluence

/// Aggregated memory signals that influence planning and ranking decisions.
public struct MemoryInfluence: Sendable, Equatable {
    /// Bias towards a specific UI control based on execution history.
    public let executionRankingBias: Double
    /// Bias towards a specific command category based on pattern history.
    public let commandBias: Double
    /// The most successful fix path for the current error signature.
    public let preferredFixPath: String?
    /// The most successful recovery strategy for the current app.
    public let preferredRecoveryStrategy: String?
    /// Signals from structured project memory (decisions, risks, patterns).
    public let projectMemorySignals: ProjectMemoryPlanningSignals
    /// File paths favoured by known-good patterns.
    public let preferredPaths: [String]
    /// File paths disfavoured by rejected approaches.
    public let avoidedPaths: [String]
    /// When `true`, the planner should prefer experimental branches.
    public let shouldPreferExperiments: Bool
    /// Penalty applied when risks are present in project memory.
    public let riskPenalty: Double
    /// Human-readable notes summarising active signals.
    public let notes: [String]
    /// Raw evidence items backing this influence.
    public let evidence: [MemoryEvidence]

    public init(
        executionRankingBias: Double = 0,
        commandBias: Double = 0,
        preferredFixPath: String? = nil,
        preferredRecoveryStrategy: String? = nil,
        projectMemorySignals: ProjectMemoryPlanningSignals = ProjectMemoryPlanningSignals(),
        preferredPaths: [String] = [],
        avoidedPaths: [String] = [],
        shouldPreferExperiments: Bool = false,
        riskPenalty: Double = 0,
        notes: [String] = [],
        evidence: [MemoryEvidence] = []
    ) {
        self.executionRankingBias = executionRankingBias
        self.commandBias = commandBias
        self.preferredFixPath = preferredFixPath
        self.preferredRecoveryStrategy = preferredRecoveryStrategy
        self.projectMemorySignals = projectMemorySignals
        self.preferredPaths = preferredPaths
        self.avoidedPaths = avoidedPaths
        self.shouldPreferExperiments = shouldPreferExperiments
        self.riskPenalty = riskPenalty
        self.notes = notes
        self.evidence = evidence
    }

    public var projectMemoryRefs: [ProjectMemoryRef] { projectMemorySignals.refs }

    public static let empty = MemoryInfluence()
}
