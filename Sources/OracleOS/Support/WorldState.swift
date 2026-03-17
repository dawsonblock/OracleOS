import Foundation

/// A structured projection of the world state, derived from the event log.
public struct WorldStateProjection: Codable, Sendable {
    public let timestamp: Date
    public let ui: UIProjection
    public let workspace: WorkspaceProjection
    public let runtime: RuntimeProjection
    public let cluster: ClusterProjection
    public let metrics: MetricsProjection
    public let safety: SafetyProjection

    public init(
        timestamp: Date = Date(),
        ui: UIProjection = UIProjection(),
        workspace: WorkspaceProjection = WorkspaceProjection(),
        runtime: RuntimeProjection = RuntimeProjection(),
        cluster: ClusterProjection = ClusterProjection(),
        metrics: MetricsProjection = MetricsProjection(),
        safety: SafetyProjection = SafetyProjection()
    ) {
        self.timestamp = timestamp
        self.ui = ui
        self.workspace = workspace
        self.runtime = runtime
        self.cluster = cluster
        self.metrics = metrics
        self.safety = safety
    }
}

// Minimal placeholder projections for Phase 2 implementation.
public struct UIProjection: Codable, Sendable {
    public var focusedApp: String?
    public var windowTitle: String?
    public init() {}
}

public struct WorkspaceProjection: Codable, Sendable {
    public var currentDirectory: String?
    public var activeFiles: [String] = []
    public init() {}
}

public struct RuntimeProjection: Codable, Sendable {
    public var version: String = "2.0.6"
    public var uptime: TimeInterval = 0
    public init() {}
}

public struct ClusterProjection: Codable, Sendable {
    public var nodeId: String?
    public var isLeader: Bool = false
    public var term: Int = 0
    public init() {}
}

public struct MetricsProjection: Codable, Sendable {
    public var goalsProcessed: Int = 0
    public var commandsExecuted: Int = 0
    public init() {}
}

public struct SafetyProjection: Codable, Sendable {
    public var policyEnforced: Bool = true
    public var lastViolation: String?
    public init() {}
}
