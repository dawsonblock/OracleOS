import Foundation

public struct VerifiedTransition: Sendable {
    public let fromPlanningStateID: PlanningStateID
    public let toPlanningStateID: PlanningStateID
    public let actionContractID: String
    public let agentKind: AgentKind
    public let domain: String
    public let workspaceRelativePath: String?
    public let commandCategory: String?
    public let plannerFamily: String?
    public let postconditionClass: PostconditionClass
    public let verified: Bool
    public let failureClass: String?
    public let latencyMs: Int
    public let targetAmbiguityScore: Double?
    public let recoveryTagged: Bool
    public let approvalRequired: Bool
    public let approvalOutcome: String?
    public let knowledgeTier: KnowledgeTier
    public let timestamp: TimeInterval

    public init(
        fromPlanningStateID: PlanningStateID,
        toPlanningStateID: PlanningStateID,
        actionContractID: String,
        agentKind: AgentKind = .mixed,
        domain: String? = nil,
        workspaceRelativePath: String? = nil,
        commandCategory: String? = nil,
        plannerFamily: String? = nil,
        postconditionClass: PostconditionClass,
        verified: Bool,
        failureClass: String? = nil,
        latencyMs: Int = 0,
        targetAmbiguityScore: Double? = nil,
        recoveryTagged: Bool = false,
        approvalRequired: Bool = false,
        approvalOutcome: String? = nil,
        knowledgeTier: KnowledgeTier = .candidate,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.fromPlanningStateID = fromPlanningStateID
        self.toPlanningStateID = toPlanningStateID
        self.actionContractID = actionContractID
        self.agentKind = agentKind
        self.domain = domain ?? (agentKind == .code ? "code" : "os")
        self.workspaceRelativePath = workspaceRelativePath
        self.commandCategory = commandCategory
        self.plannerFamily = plannerFamily
        self.postconditionClass = postconditionClass
        self.verified = verified
        self.failureClass = failureClass
        self.latencyMs = latencyMs
        self.targetAmbiguityScore = targetAmbiguityScore
        self.recoveryTagged = recoveryTagged
        self.approvalRequired = approvalRequired
        self.approvalOutcome = approvalOutcome
        self.knowledgeTier = knowledgeTier
        self.timestamp = timestamp
    }
}
