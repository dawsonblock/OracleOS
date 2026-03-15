import Foundation

// MARK: - ChangeImpactAnalyzer

public struct ChangeImpactAnalyzer: Sendable {
    public init() {}

    /// Derives affected logical modules from a list of workspace-relative paths.
    public func affectedModules(for paths: [String]) -> [String] {
        Array(Set(paths.map(ArchitectureModuleGraph.moduleName(for:)))).sorted()
    }

    /// Returns `true` when the described change warrants a full architecture review.
    ///
    /// Triggers:
    /// - Goal explicitly references "refactor", "architecture", or "boundary"
    /// - More than one logical module is affected
    public func shouldReview(goalDescription: String, candidatePaths: [String]) -> Bool {
        let lowered = goalDescription.lowercased()
        if lowered.contains("refactor") || lowered.contains("architecture") || lowered.contains("boundary") {
            return true
        }
        return affectedModules(for: candidatePaths).count > 1
    }
}
