import Foundation

// MARK: - ProjectMemoryKind

public enum ProjectMemoryKind: String, Codable, Sendable, CaseIterable {
    case architectureDecision = "architecture-decision"
    case openProblem = "open-problem"
    case rejectedApproach = "rejected-approach"
    case knownGoodPattern = "known-good-pattern"
    case risk

    public var directoryName: String {
        switch self {
        case .architectureDecision: "architecture-decisions"
        case .openProblem:          "open-problems"
        case .rejectedApproach:     "rejected-approaches"
        case .knownGoodPattern:     "known-good-patterns"
        case .risk:                 "."
        }
    }

    public var titlePrefix: String {
        switch self {
        case .architectureDecision: "Architecture Decision"
        case .openProblem:          "Open Problem"
        case .rejectedApproach:     "Rejected Approach"
        case .knownGoodPattern:     "Known Good Pattern"
        case .risk:                 "Risk"
        }
    }
}

// MARK: - ProjectMemoryStatus

public enum ProjectMemoryStatus: String, Codable, Sendable, CaseIterable {
    case draft
    case accepted
}

// MARK: - ProjectMemoryRef

/// A lightweight reference to a project memory record, suitable for use in
/// `MemoryInfluence` and planning signals without carrying the full record body.
public struct ProjectMemoryRef: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let kind: ProjectMemoryKind
    public let knowledgeClass: KnowledgeClass
    public let status: ProjectMemoryStatus
    public let title: String
    public let summary: String
    public let path: String
    public let affectedModules: [String]
    public let evidenceRefs: [String]
    public let sourceTraceIDs: [String]

    public init(
        id: String,
        kind: ProjectMemoryKind,
        knowledgeClass: KnowledgeClass,
        status: ProjectMemoryStatus,
        title: String,
        summary: String,
        path: String,
        affectedModules: [String] = [],
        evidenceRefs: [String] = [],
        sourceTraceIDs: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.knowledgeClass = knowledgeClass
        self.status = status
        self.title = title
        self.summary = summary
        self.path = path
        self.affectedModules = affectedModules
        self.evidenceRefs = evidenceRefs
        self.sourceTraceIDs = sourceTraceIDs
    }
}

// MARK: - ProjectMemoryRecord

/// A full project memory record — a structured decision or observation persisted
/// across sessions, keyed by `path` within the workspace's `ProjectMemory/` folder.
public struct ProjectMemoryRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: ProjectMemoryKind
    public let knowledgeClass: KnowledgeClass
    public let status: ProjectMemoryStatus
    public let title: String
    public let summary: String
    public let path: String
    public let affectedModules: [String]
    public let evidenceRefs: [String]
    public let sourceTraceIDs: [String]
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        kind: ProjectMemoryKind,
        knowledgeClass: KnowledgeClass,
        status: ProjectMemoryStatus = .draft,
        title: String,
        summary: String,
        path: String,
        affectedModules: [String] = [],
        evidenceRefs: [String] = [],
        sourceTraceIDs: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.knowledgeClass = knowledgeClass
        self.status = status
        self.title = title
        self.summary = summary
        self.path = path
        self.affectedModules = affectedModules
        self.evidenceRefs = evidenceRefs
        self.sourceTraceIDs = sourceTraceIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Lightweight reference to this record.
    public var ref: ProjectMemoryRef {
        ProjectMemoryRef(
            id: id,
            kind: kind,
            knowledgeClass: knowledgeClass,
            status: status,
            title: title,
            summary: summary,
            path: path,
            affectedModules: affectedModules,
            evidenceRefs: evidenceRefs,
            sourceTraceIDs: sourceTraceIDs
        )
    }
}
