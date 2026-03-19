import Foundation

public struct WorldState: Sendable {
    public var observationHash: String
    public var planningState: PlanningState
    public var beliefStateID: String?

    public var observation: Observation
    public var repositorySnapshot: RepositorySnapshot?

    public var lastAction: ActionIntent?
    public var files: [String: String]
    public var lastOutput: String?
    public var lastHTTPResponseSize: Int?

    public init(
        observation: Observation,
        lastAction: ActionIntent? = nil,
        beliefStateID: String? = nil,
        repositorySnapshot: RepositorySnapshot? = nil,
        stateAbstraction: StateAbstraction = StateAbstraction(),
        files: [String: String] = [:],
        lastOutput: String? = nil,
        lastHTTPResponseSize: Int? = nil
    ) {
        let observationHash = ObservationHash.hash(observation)
        self.observationHash = observationHash
        self.planningState = stateAbstraction.abstract(
            observation: observation,
            repositorySnapshot: repositorySnapshot,
            observationHash: observationHash
        )
        self.beliefStateID = beliefStateID
        self.observation = observation
        self.repositorySnapshot = repositorySnapshot
        self.lastAction = lastAction
        self.files = files
        self.lastOutput = lastOutput
        self.lastHTTPResponseSize = lastHTTPResponseSize
    }

    public init(
        observationHash: String,
        planningState: PlanningState,
        beliefStateID: String? = nil,
        observation: Observation,
        repositorySnapshot: RepositorySnapshot? = nil,
        lastAction: ActionIntent? = nil,
        files: [String: String] = [:],
        lastOutput: String? = nil,
        lastHTTPResponseSize: Int? = nil
    ) {
        self.observationHash = observationHash
        self.planningState = planningState
        self.beliefStateID = beliefStateID
        self.observation = observation
        self.repositorySnapshot = repositorySnapshot
        self.lastAction = lastAction
        self.files = files
        self.lastOutput = lastOutput
        self.lastHTTPResponseSize = lastHTTPResponseSize
    }
}

extension WorldState {
    public static var empty: WorldState {
        WorldState(observation: Observation(app: "system", elements: []))
    }
}
