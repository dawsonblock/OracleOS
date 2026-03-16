import Foundation

// MARK: - Proposal

/// The result of a `ProposalEngine` cycle — a set of evaluated plans plus a selected winner.
public struct Proposal: Sendable {
    public let plans: [PlanCandidate]
    public let selectedPlan: PlanCandidate?
    public let diagnostics: ProposalDiagnostics

    public init(plans: [PlanCandidate], selectedPlan: PlanCandidate?, diagnostics: ProposalDiagnostics) {
        self.plans = plans
        self.selectedPlan = selectedPlan
        self.diagnostics = diagnostics
    }
}

// MARK: - ProposalDiagnostics

/// Diagnostic information about a `ProposalEngine` cycle.
public struct ProposalDiagnostics: Sendable {
    public let llmPlansGenerated: Int
    public let deterministicPlansGenerated: Int
    public let totalEvaluated: Int
    public let selectedSource: PlanSourceType?
    public let llmLatencyMs: Double
    public let notes: [String]

    public init(
        llmPlansGenerated: Int = 0,
        deterministicPlansGenerated: Int = 0,
        totalEvaluated: Int = 0,
        selectedSource: PlanSourceType? = nil,
        llmLatencyMs: Double = 0,
        notes: [String] = []
    ) {
        self.llmPlansGenerated = llmPlansGenerated
        self.deterministicPlansGenerated = deterministicPlansGenerated
        self.totalEvaluated = totalEvaluated
        self.selectedSource = selectedSource
        self.llmLatencyMs = llmLatencyMs
        self.notes = notes
    }
}

// MARK: - ProposalEngine

/// Combines deterministic operator reasoning with optional LLM-generated plans
/// to produce a ranked set of `PlanCandidate` values.
public final class ProposalEngine: @unchecked Sendable {
    private let llmClient: LLMClient
    private let reasoningEngine: ReasoningEngine
    private let minimumScore: Double

    public init(
        llmClient: LLMClient,
        reasoningEngine: ReasoningEngine = ReasoningEngine(),
        minimumScore: Double = 0.6
    ) {
        self.llmClient = llmClient
        self.reasoningEngine = reasoningEngine
        self.minimumScore = minimumScore
    }

    // MARK: - Propose

    /// Generate a `Proposal` asynchronously, combining deterministic and LLM-backed plans.
    public func propose(
        state: ReasoningPlanningState,
        goal: Goal,
        selectedStrategy: SelectedStrategy
    ) async -> Proposal {
        let deterministicPlans = reasoningEngine.generatePlans(from: state)

        let (llmPlans, llmLatencyMs) = await generateLLMPlans(
            state: state,
            goal: goal,
            operators: deterministicPlans.flatMap(\.operators).map(\.name),
            selectedStrategy: selectedStrategy
        )

        var allPlans = deterministicPlans + llmPlans
        allPlans = allPlans.filter { $0.isAllowed(by: selectedStrategy) }

        // Simple score: prefer longer plans with lower risk
        let scored = allPlans
            .map { plan -> PlanCandidate in
                let operatorScore = Double(plan.operators.count) * 0.1
                let riskAdjusted = operatorScore - plan.riskScore * 0.3
                return PlanCandidate(
                    operators: plan.operators,
                    projectedState: plan.projectedState,
                    score: plan.score + riskAdjusted,
                    reasons: plan.reasons,
                    simulatedOutcome: plan.simulatedOutcome,
                    sourceType: plan.sourceType
                )
            }
            .sorted { $0.score > $1.score }

        let best = scored.first.flatMap { $0.score >= minimumScore ? $0 : nil }

        let selectedSource: PlanSourceType?
        if let best {
            let isLLMPlan = llmPlans.contains { candidate in
                candidate.operators.map(\.kind) == best.operators.map(\.kind)
            }
            selectedSource = isLLMPlan ? .llm : .reasoning
        } else {
            selectedSource = nil
        }

        return Proposal(
            plans: scored,
            selectedPlan: best,
            diagnostics: ProposalDiagnostics(
                llmPlansGenerated: llmPlans.count,
                deterministicPlansGenerated: deterministicPlans.count,
                totalEvaluated: scored.count,
                selectedSource: selectedSource,
                llmLatencyMs: llmLatencyMs ?? 0,
                notes: best == nil ? ["no plan met minimum score threshold"] : []
            )
        )
    }

    // MARK: - LLM Plan Generation

    private func generateLLMPlans(
        state: ReasoningPlanningState,
        goal: Goal,
        operators: [String],
        selectedStrategy: SelectedStrategy
    ) async -> ([PlanCandidate], Double?) {
        let prompt = buildPlanningPrompt(
            state: state, goal: goal, operators: operators, selectedStrategy: selectedStrategy
        )
        let request = LLMRequest(prompt: prompt, modelTier: .planning, maxTokens: 1024, temperature: 0.3)

        do {
            let response = try await llmClient.complete(request)
            let parsed = ReasoningParser.parsePlans(from: response.text)
            let plans = ReasoningParser.toPlanCandidates(parsedPlans: parsed, state: state)
            return (plans, response.latencyMs)
        } catch {
            return ([], nil)
        }
    }

    private func buildPlanningPrompt(
        state: ReasoningPlanningState,
        goal: Goal,
        operators: [String],
        selectedStrategy: SelectedStrategy
    ) -> String {
        var lines: [String] = [
            "You are controlling a computer operator.",
            "",
            "Current strategy: \(selectedStrategy.kind.rawValue)",
            "Allowed operator families: \(selectedStrategy.allowedOperatorFamilies.map(\.rawValue).joined(separator: ", "))",
            "Strategy rationale: \(selectedStrategy.rationale)",
            "IMPORTANT: Only generate plans using operators from the allowed families.",
            "",
            "Current state:",
            "- agent kind: \(state.agentKind.rawValue)",
            "- active application: \(state.activeApplication ?? "none")",
            "- target application: \(state.targetApplication ?? "none")",
            "- repo open: \(state.repoOpen)",
            "- modal present: \(state.modalPresent)",
            "- patch applied: \(state.patchApplied)",
            "- tests observed: \(state.testsObserved)",
            "",
            "Goal:",
            "- \(goal.description)",
            "",
            "Available operators:",
        ]
        for op in Set(operators).sorted() { lines.append("- \(op)") }
        lines += [
            "",
            "Generate 3 candidate plans.",
            "Each plan must contain:",
            "- ordered steps",
            "- risk level (low, medium, high)",
            "- confidence (0.0 to 1.0)",
            "",
            "Format:",
            "PLAN 1",
            "steps:",
            "- step description",
            "risk: low",
            "confidence: 0.75",
        ]
        return lines.joined(separator: "\n")
    }
}
