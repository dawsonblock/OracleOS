import Foundation

public struct WorkflowPattern: Sendable, Equatable {
    public let fingerprint: String
    public let actionTypes: [String]
    public let planningStateConsistency: Double
    public let parameterConsistency: Double
    public let reusable: Bool
    public let notes: [String]

    public init(fingerprint: String, actionTypes: [String], planningStateConsistency: Double, parameterConsistency: Double, reusable: Bool, notes: [String] = []) {
        self.fingerprint = fingerprint
        self.actionTypes = actionTypes
        self.planningStateConsistency = planningStateConsistency
        self.parameterConsistency = parameterConsistency
        self.reusable = reusable
        self.notes = notes
    }
}

public struct WorkflowPatternMiner: Sendable {
    public let minimumPlanningStateConsistency: Double
    public let minimumParameterConsistency: Double

    public init(minimumPlanningStateConsistency: Double = 0.6, minimumParameterConsistency: Double = 0.5) {
        self.minimumPlanningStateConsistency = minimumPlanningStateConsistency
        self.minimumParameterConsistency = minimumParameterConsistency
    }

    public func mine(events: [TraceEvent]) -> [WorkflowPattern] {
        let successfulEvents = events.filter {
            if case .success = $0.outcome { return true }
            return false
        }
        guard !successfulEvents.isEmpty else { return [] }

        let grouped = Dictionary(grouping: successfulEvents) { event in
            [event.action.type, event.action.domain.rawValue].joined(separator: "|")
        }

        return grouped.map { fingerprint, groupedEvents in
            let actionDomains = groupedEvents.map { $0.action.domain.rawValue }
            let planningStateConsistency = consistencyScore(values: actionDomains)
            let parameterConsistency = parameterConsistencyScore(events: groupedEvents)
            let reusable = planningStateConsistency >= minimumPlanningStateConsistency && parameterConsistency >= minimumParameterConsistency
            return WorkflowPattern(
                fingerprint: fingerprint,
                actionTypes: groupedEvents.map { $0.action.type },
                planningStateConsistency: planningStateConsistency,
                parameterConsistency: parameterConsistency,
                reusable: reusable,
                notes: [
                    "planning state consistency \(String(format: "%.2f", planningStateConsistency))",
                    "parameter consistency \(String(format: "%.2f", parameterConsistency))",
                ]
            )
        }
        .sorted { lhs, rhs in
            if lhs.planningStateConsistency == rhs.planningStateConsistency {
                return lhs.parameterConsistency > rhs.parameterConsistency
            }
            return lhs.planningStateConsistency > rhs.planningStateConsistency
        }
    }

    private func consistencyScore(values: [String]) -> Double {
        guard !values.isEmpty else { return 0 }
        let groups = Dictionary(grouping: values, by: { $0 })
        let dominant = groups.values.map(\.count).max() ?? 0
        return Double(dominant) / Double(values.count)
    }

    private func parameterConsistencyScore(events: [TraceEvent]) -> Double {
        guard !events.isEmpty else { return 0 }
        let nonEmptyValues = events.flatMap { $0.action.parameters.values }.filter { !$0.isEmpty }
        guard !nonEmptyValues.isEmpty else { return 1 }
        let residueCount = nonEmptyValues.filter {
            $0.contains("/tmp/") || $0.contains("sandbox-") || $0.contains("/.oracle/")
        }.count
        return max(0, 1.0 - (Double(residueCount) / Double(nonEmptyValues.count)))
    }
}
