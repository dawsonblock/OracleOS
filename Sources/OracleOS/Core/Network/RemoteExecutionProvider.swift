import Foundation

/// Abstract interface for executing commands over a network, 
/// supporting the Cluster runtime mode.
public protocol RemoteExecutionProvider: Sendable {
    func executeRemote(
        command: ActionCommand,
        nodeId: String
    ) async throws -> ExecutionResult
}

/// A node in the OracleOS cluster.
public struct ClusterNode: Codable, Sendable, Identifiable {
    public let id: String
}

public enum NodeStatus: String, Codable, Sendable {
    case online
    case offline
    case busy
}
