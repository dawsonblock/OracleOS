import Foundation

// MARK: - ProjectMemoryPlanningSignals

/// Aggregated project memory signals relevant to a single planning decision.
public struct ProjectMemoryPlanningSignals: Sendable, Equatable {
    public let architectureDecisions: [ProjectMemoryRecord]
    public let openProblems: [ProjectMemoryRecord]
    public let rejectedApproaches: [ProjectMemoryRecord]
    public let knownGoodPatterns: [ProjectMemoryRecord]
    public let risks: [ProjectMemoryRecord]

    public init(
        architectureDecisions: [ProjectMemoryRecord] = [],
        openProblems: [ProjectMemoryRecord] = [],
        rejectedApproaches: [ProjectMemoryRecord] = [],
        knownGoodPatterns: [ProjectMemoryRecord] = [],
        risks: [ProjectMemoryRecord] = []
    ) {
        self.architectureDecisions = architectureDecisions
        self.openProblems = openProblems
        self.rejectedApproaches = rejectedApproaches
        self.knownGoodPatterns = knownGoodPatterns
        self.risks = risks
    }

    public var refs: [ProjectMemoryRef] { records.map(\.ref) }

    public var records: [ProjectMemoryRecord] {
        architectureDecisions + openProblems + rejectedApproaches + knownGoodPatterns + risks
    }

    public var hasArchitectureDecisions: Bool { !architectureDecisions.isEmpty }
    public var hasOpenProblems: Bool { !openProblems.isEmpty }
    public var hasRejectedApproaches: Bool { !rejectedApproaches.isEmpty }
    public var hasKnownGoodPatterns: Bool { !knownGoodPatterns.isEmpty }
    public var hasRisks: Bool { !risks.isEmpty }

    /// Paths from known-good patterns that match files in the snapshot.
    public func preferredPaths(in snapshot: RepositorySnapshot) -> [String] {
        let knownPaths = knownGoodPatterns.compactMap { $0.path.isEmpty ? nil : $0.path }
        let filePaths = Set(snapshot.files.map(\.path))
        return knownPaths.filter { filePaths.contains($0) }
    }

    /// Paths from rejected approaches that match files in the snapshot.
    public func avoidedPaths(in snapshot: RepositorySnapshot) -> [String] {
        let rejectedPaths = rejectedApproaches.compactMap { $0.path.isEmpty ? nil : $0.path }
        let filePaths = Set(snapshot.files.map(\.path))
        return rejectedPaths.filter { filePaths.contains($0) }
    }
}
