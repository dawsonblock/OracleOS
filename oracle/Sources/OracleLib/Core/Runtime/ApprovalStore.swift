import Foundation

@MainActor
public final class ApprovalStore {
    public let rootDirectory: URL
    private var lastHeartbeatBySession: [String: Date] = [:]

    public init(rootDirectory: URL = OracleProductPaths.approvalsDirectory) {
        self.rootDirectory = rootDirectory
    }

    public func writeControllerHeartbeat(sessionID: String) {
        lastHeartbeatBySession[sessionID] = Date()
    }

    public func controllerConnected(maxAgeSeconds: TimeInterval = 6) -> Bool {
        let now = Date()
        return lastHeartbeatBySession.values.contains { now.timeIntervalSince($0) <= maxAgeSeconds }
    }
}