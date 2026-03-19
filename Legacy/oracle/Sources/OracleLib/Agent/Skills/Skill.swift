import Foundation

// ─────────────────────────────────────────────────────────
// Skill — resolution protocol for OS-level actions
//
// OS skills resolve abstract element queries into concrete
// ActionIntent values the executor can act on.
// Code skills resolve task-context-driven requests into
// code-oriented ActionIntents.
//
// Architecture rule: Skills resolve intent only.
// Execution is always through VerifiedActionExecutor (R4).
// ─────────────────────────────────────────────────────────

// MARK: - Errors

public enum SkillResolutionError: Error, Sendable, Equatable {
    case noCandidate(String)
    case ambiguousTarget(String, Double)
    case unsupportedOperation(String)

    public var description: String {
        switch self {
        case .noCandidate(let detail):
            return "no candidate found: \(detail)"
        case .ambiguousTarget(let detail, let score):
            return "ambiguous target (\(detail), score=\(score))"
        case .unsupportedOperation(let detail):
            return "unsupported: \(detail)"
        }
    }
}

public enum CodeSkillResolutionError: Error, Sendable, Equatable {
    case missingWorkspace
    case noRepositorySnapshot
    case noRelevantFiles(String)
    case ambiguousEditTarget(String)

    public var description: String {
        switch self {
        case .missingWorkspace:
            return "workspace root not provided"
        case .noRepositorySnapshot:
            return "repository snapshot not available"
        case .noRelevantFiles(let skill):
            return "no relevant files for skill: \(skill)"
        case .ambiguousEditTarget(let detail):
            return "ambiguous edit target: \(detail)"
        }
    }
}

// MARK: - Resolution result

/// The product of a skill resolution — an intent plus optional metadata.
public struct SkillResolution: Sendable {
    public let intent: ActionIntent
    public let resolvedTargetID: String?
    public let confidence: Double
    public let notes: [String]

    public init(
        intent: ActionIntent,
        resolvedTargetID: String? = nil,
        confidence: Double = 1.0,
        notes: [String] = []
    ) {
        self.intent = intent
        self.resolvedTargetID = resolvedTargetID
        self.confidence = confidence
        self.notes = notes
    }
}

// MARK: - Protocols

/// OS-level skill: resolves an element query against the current world snapshot.
public protocol Skill {
    var name: String { get }

    /// Resolve a query against world state into a concrete ActionIntent.
    func resolve(
        query: String,
        worldSnapshot: WorldModelSnapshot,
        parameters: [String: String]
    ) throws -> SkillResolution
}

/// Code-level skill: resolves a task context into a code-oriented ActionIntent.
public protocol CodeSkill {
    var name: String { get }

    /// Resolve a code task into a concrete ActionIntent.
    func resolve(
        goal: String,
        workspaceRoot: String?,
        parameters: [String: String]
    ) throws -> SkillResolution
}
