import Foundation

/// A structured summary of the environment observed at a specific points in time.
public struct SupportObservation: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let provenance: ObservationProvenance

    /// UI Snapshot summary
    public let uiSummary: String?
    /// Currently focused application name
    public let focusedApp: String?
    /// Currently focused window title
    public let focusedWindow: String?

    /// Cryptographic hashes of relevant workspace files if applicable
    public let workspaceFileHashes: [String: String]
    /// Environment flags (e.g. "dark_mode": "true")
    public let flags: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        provenance: ObservationProvenance = .direct,
        uiSummary: String? = nil,
        focusedApp: String? = nil,
        focusedWindow: String? = nil,
        workspaceFileHashes: [String: String] = [:],
        flags: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.provenance = provenance
        self.uiSummary = uiSummary
        self.focusedApp = focusedApp
        self.focusedWindow = focusedWindow
        self.workspaceFileHashes = workspaceFileHashes
        self.flags = flags
    }
}

public enum ObservationProvenance: String, Codable, Sendable {
    /// Directly observed via system APIs
    case direct
    /// Inferred from previous actions
    case inferred
    /// Provided by an external source
    case external
}
