import Foundation

extension TaskNode {
    public var planningStateID: PlanningStateID? { nil }
    public var memoryRefs: [String] { [] }
    public var workflowRefs: [String] { [] }
}

extension TaskEdge {
    public var actionContractID: String? { nil }

    public var operatorFamily: OperatorFamily {
        GraphNavigator.operatorFamilyForAction(action)
    }

    public var risk: Double {
        let lowered = action.lowercased()
        if lowered.contains("delete") || lowered.contains("remove") || lowered.contains("force") {
            return 1.0
        }
        switch domain {
        case .host:
            return 0.35
        case .browser:
            return 0.2
        case .code:
            return 0.15
        case .tool:
            return 0.1
        case .search, .system:
            return 0.05
        }
    }
}