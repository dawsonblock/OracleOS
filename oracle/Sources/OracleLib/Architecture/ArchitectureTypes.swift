import Foundation

// MARK: - RepositoryFile

public struct RepositoryFile: Codable, Sendable, Equatable {
    public let path: String
    public let isDirectory: Bool
    public let lastModifiedAt: Date?

    public init(path: String, isDirectory: Bool, lastModifiedAt: Date? = nil) {
        self.path = path
        self.isDirectory = isDirectory
        self.lastModifiedAt = lastModifiedAt
    }
}

// MARK: - ArchitectureDependencyEdge

public struct ArchitectureDependencyEdge: Codable, Sendable, Equatable {
    public let sourcePath: String
    public let dependency: String

    public init(sourcePath: String, dependency: String) {
        self.sourcePath = sourcePath
        self.dependency = dependency
    }
}

// MARK: - ArchitectureDependencyGraph

public struct ArchitectureDependencyGraph: Codable, Sendable, Equatable {
    public let edges: [ArchitectureDependencyEdge]

    public init(edges: [ArchitectureDependencyEdge] = []) {
        self.edges = edges
    }
}

// MARK: - RepositorySnapshot (lightweight — architecture layer only)

/// A lightweight snapshot of the repository used for architecture governance analysis.
/// This is distinct from full code-intelligence snapshots and carries only the fields
/// needed by the architecture engine.
public struct RepositorySnapshot: Codable, Sendable, Equatable {
    public let workspaceRoot: String
    public let files: [RepositoryFile]
    public let dependencyGraph: ArchitectureDependencyGraph
    public let activeBranch: String?
    public let isGitDirty: Bool

    public init(
        workspaceRoot: String = "",
        files: [RepositoryFile] = [],
        dependencyGraph: ArchitectureDependencyGraph = ArchitectureDependencyGraph(),
        activeBranch: String? = nil,
        isGitDirty: Bool = false
    ) {
        self.workspaceRoot = workspaceRoot
        self.files = files
        self.dependencyGraph = dependencyGraph
        self.activeBranch = activeBranch
        self.isGitDirty = isGitDirty
    }

    /// Convenience: create a snapshot from a list of source paths.
    public static func fromPaths(_ paths: [String], workspaceRoot: String = "") -> RepositorySnapshot {
        let files = paths.map { RepositoryFile(path: $0, isDirectory: false) }
        return RepositorySnapshot(workspaceRoot: workspaceRoot, files: files)
    }
}

// MARK: - CandidatePatch

/// Represents a single file candidate being evaluated for an architectural patch.
public struct CandidatePatch: Codable, Sendable, Equatable {
    public let workspaceRelativePath: String
    public let content: String

    public init(workspaceRelativePath: String, content: String) {
        self.workspaceRelativePath = workspaceRelativePath
        self.content = content
    }
}
