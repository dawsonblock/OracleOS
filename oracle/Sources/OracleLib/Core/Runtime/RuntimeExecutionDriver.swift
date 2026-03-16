import Foundation

@MainActor
public final class RuntimeExecutionDriver: AgentExecutionDriver {
    private let runtime: OracleRuntime
    private let surface: RuntimeSurface
    private let rawActionExecutor: (@MainActor (ActionIntent) -> ToolResult)?

    public init(
        runtime: OracleRuntime,
        surface: RuntimeSurface = .recipe,
        rawActionExecutor: (@MainActor (ActionIntent) -> ToolResult)? = nil
    ) {
        self.runtime = runtime
        self.surface = surface
        self.rawActionExecutor = rawActionExecutor
    }

    public func execute(
        intent: ActionIntent,
        plannerDecision: PlannerDecision,
        selectedCandidate: ElementCandidate?
    ) -> ToolResult {
        if plannerDecision.agentKind == .ui, let rawActionExecutor {
            return rawActionExecutor(intent)
        }

        let result = runtime.executor.execute(action: intent)
        return ToolResult(
            success: result.success,
            data: [
                "detail": result.detail,
                "action_id": result.actionID,
                "planner_source": plannerDecision.source.rawValue,
                "planner_family": plannerDecision.plannerFamily.rawValue,
                "surface": surface.rawValue,
                "selected_element_id": selectedCandidate?.element.id as Any,
                "candidate_score": selectedCandidate?.score as Any,
            ],
            error: result.success ? nil : result.detail
        )
    }
}