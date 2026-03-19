import Foundation

// MARK: - PlanningState

/// A compressed, semantically meaningful representation of the agent's current
/// planning context. Used by memory subsystems to look up prior strategies.
public struct PlanningState: Hashable, Codable, Sendable {
    public let id: PlanningStateID
    public let clusterKey: StateClusterKey
    public let appID: String
    public let domain: String?
    public let windowClass: String?
    public let taskPhase: String?
    public let focusedRole: String?
    public let modalClass: String?
    public let navigationClass: String?
    public let controlContext: String?

    public init(
        id: PlanningStateID,
        clusterKey: StateClusterKey,
        appID: String,
        domain: String? = nil,
        windowClass: String? = nil,
        taskPhase: String? = nil,
        focusedRole: String? = nil,
        modalClass: String? = nil,
        navigationClass: String? = nil,
        controlContext: String? = nil
    ) {
        self.id = id
        self.clusterKey = clusterKey
        self.appID = appID
        self.domain = domain
        self.windowClass = windowClass
        self.taskPhase = taskPhase
        self.focusedRole = focusedRole
        self.modalClass = modalClass
        self.navigationClass = navigationClass
        self.controlContext = controlContext
    }
}
