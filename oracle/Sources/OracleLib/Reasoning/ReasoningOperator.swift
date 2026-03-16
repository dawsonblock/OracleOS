import Foundation

// MARK: - ReasoningOperatorKind

/// The set of primitive planning operators used by the reasoning layer.
public enum ReasoningOperatorKind: String, CaseIterable, Sendable {
    case runTests = "run_tests"
    case buildProject = "build_project"
    case applyPatch = "apply_patch"
    case revertPatch = "revert_patch"
    case dismissModal = "dismiss_modal"
    case clickTarget = "click_target"
    case openApplication = "open_application"
    case navigateBrowser = "navigate_browser"
    case rerunTests = "rerun_tests"
    case retryWithAlternateTarget = "retry_with_alternate_target"
    case focusWindow = "focus_window"
    case restartApplication = "restart_application"
    case rollbackPatch = "rollback_patch"

    /// The operator family this kind belongs to, used for strategy filtering.
    public var operatorFamily: OperatorFamily {
        switch self {
        case .runTests, .buildProject, .rerunTests:
            return .repoAnalysis
        case .applyPatch, .revertPatch, .rollbackPatch:
            return .patchGeneration
        case .dismissModal, .clickTarget, .openApplication,
             .retryWithAlternateTarget, .focusWindow, .restartApplication:
            return .hostTargeted
        case .navigateBrowser:
            return .browserTargeted
        }
    }
}

// MARK: - Operator

/// A concrete planning operator with cost, risk, and domain metadata.
public struct Operator: Sendable, Hashable {
    public let kind: ReasoningOperatorKind
    public let baseCost: Double
    public let risk: Double
    /// The kind of agent required to execute this operator (.ui for OS tasks, .code for engineering).
    public let agentKind: AgentKind
    public let stepPhase: TaskStepPhase

    public init(kind: ReasoningOperatorKind) {
        self.kind = kind
        switch kind {
        case .runTests:
            baseCost = 1.0; risk = 0.05; agentKind = .code; stepPhase = .engineering
        case .buildProject:
            baseCost = 1.1; risk = 0.05; agentKind = .code; stepPhase = .engineering
        case .applyPatch:
            baseCost = 2.0; risk = 0.2; agentKind = .code; stepPhase = .engineering
        case .revertPatch:
            baseCost = 1.4; risk = 0.1; agentKind = .code; stepPhase = .engineering
        case .dismissModal:
            baseCost = 0.4; risk = 0.02; agentKind = .ui; stepPhase = .operatingSystem
        case .clickTarget:
            baseCost = 0.6; risk = 0.08; agentKind = .ui; stepPhase = .operatingSystem
        case .openApplication:
            baseCost = 0.5; risk = 0.03; agentKind = .ui; stepPhase = .operatingSystem
        case .navigateBrowser:
            baseCost = 0.8; risk = 0.06; agentKind = .ui; stepPhase = .operatingSystem
        case .rerunTests:
            baseCost = 0.9; risk = 0.04; agentKind = .code; stepPhase = .engineering
        case .retryWithAlternateTarget:
            baseCost = 0.7; risk = 0.1; agentKind = .ui; stepPhase = .operatingSystem
        case .focusWindow:
            baseCost = 0.3; risk = 0.02; agentKind = .ui; stepPhase = .operatingSystem
        case .restartApplication:
            baseCost = 1.5; risk = 0.15; agentKind = .ui; stepPhase = .operatingSystem
        case .rollbackPatch:
            baseCost = 1.2; risk = 0.08; agentKind = .code; stepPhase = .engineering
        }
    }

    public var name: String { kind.rawValue }

    /// Whether this operator can fire in the given planning state.
    ///
    /// `.ui` maps to the OS agent (equivalent of reference's `.os`).
    public func precondition(_ state: ReasoningPlanningState) -> Bool {
        switch kind {
        case .runTests:
            return state.agentKind != .ui && state.repoOpen
        case .buildProject:
            return state.agentKind != .ui && state.repoOpen
        case .applyPatch:
            return state.agentKind != .ui && state.repoOpen && !state.candidateWorkspacePaths.isEmpty
        case .revertPatch:
            return state.agentKind != .ui && state.repoOpen && state.patchApplied
        case .dismissModal:
            return state.agentKind != .code && state.modalPresent
        case .clickTarget:
            return state.agentKind != .code && !state.visibleTargets.isEmpty
        case .openApplication:
            guard state.agentKind != .code else { return false }
            guard let targetApplication = state.targetApplication else { return false }
            return targetApplication != state.activeApplication
        case .navigateBrowser:
            guard state.agentKind != .code else { return false }
            guard let targetDomain = state.targetDomain else { return false }
            return targetDomain != state.currentDomain
        case .rerunTests:
            return state.agentKind != .ui && state.repoOpen && (state.testsObserved || state.patchApplied)
        case .retryWithAlternateTarget:
            return state.agentKind != .code && !state.visibleTargets.isEmpty
        case .focusWindow:
            return state.agentKind != .code && state.targetApplication != nil
        case .restartApplication:
            return state.agentKind != .code && state.targetApplication != nil
        case .rollbackPatch:
            return state.agentKind != .ui && state.repoOpen && state.patchApplied
        }
    }

    /// Projects the effect of this operator on a planning state.
    public func effect(_ state: ReasoningPlanningState) -> ReasoningPlanningState {
        var projected = state
        switch kind {
        case .runTests, .rerunTests:
            projected.testsObserved = true
            if projected.failingTests == nil { projected.failingTests = 1 }
            projected.buildSucceeded = nil
        case .buildProject:
            projected.buildSucceeded = true
        case .applyPatch:
            projected.patchApplied = true
            projected.repoDirty = true
        case .revertPatch:
            projected.patchApplied = false
        case .dismissModal:
            projected.modalPresent = false
        case .clickTarget:
            break
        case .openApplication:
            projected.activeApplication = projected.targetApplication
        case .navigateBrowser:
            projected.currentDomain = projected.targetDomain
        case .retryWithAlternateTarget:
            break
        case .focusWindow:
            projected.activeApplication = projected.targetApplication
        case .restartApplication:
            projected.activeApplication = projected.targetApplication
            projected.modalPresent = false
        case .rollbackPatch:
            projected.patchApplied = false
            projected.repoDirty = false
        }
        return projected
    }

    /// Produces an `ActionContract` for this operator given current state + goal.
    public func actionContract(for state: ReasoningPlanningState, goal: Goal) -> ActionContract? {
        switch kind {
        case .runTests:
            guard let workspaceRoot = state.workspaceRoot else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(workspaceRoot)",
                agentKind: .code,
                skillName: "run_tests",
                targetRole: nil, targetLabel: nil,
                locatorStrategy: "reasoning",
                workspaceRelativePath: state.preferredWorkspacePath,
                commandCategory: CodeCommandCategory.test.rawValue,
                plannerFamily: PlannerFamily.code.rawValue
            )
        case .buildProject:
            guard let workspaceRoot = state.workspaceRoot else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(workspaceRoot)",
                agentKind: .code,
                skillName: "run_build",
                targetRole: nil, targetLabel: nil,
                locatorStrategy: "reasoning",
                workspaceRelativePath: state.preferredWorkspacePath,
                commandCategory: CodeCommandCategory.build.rawValue,
                plannerFamily: PlannerFamily.code.rawValue
            )
        case .applyPatch:
            let path = state.preferredWorkspacePath ?? state.candidateWorkspacePaths.first
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(path ?? "generate")",
                agentKind: .code,
                skillName: path == nil ? "generate_patch" : "edit_file",
                targetRole: nil,
                targetLabel: path.map { URL(fileURLWithPath: $0).lastPathComponent },
                locatorStrategy: "reasoning",
                workspaceRelativePath: path,
                commandCategory: (path == nil ? CodeCommandCategory.generatePatch : .editFile).rawValue,
                plannerFamily: PlannerFamily.code.rawValue
            )
        case .revertPatch:
            guard let workspaceRoot = state.workspaceRoot else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(workspaceRoot)",
                agentKind: .code,
                skillName: "git_status",
                targetRole: nil, targetLabel: nil,
                locatorStrategy: "reasoning",
                workspaceRelativePath: state.preferredWorkspacePath,
                commandCategory: CodeCommandCategory.gitStatus.rawValue,
                plannerFamily: PlannerFamily.code.rawValue
            )
        case .dismissModal:
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|escape",
                agentKind: .ui,
                skillName: "press",
                targetRole: nil, targetLabel: "escape",
                locatorStrategy: "reasoning-dismiss-modal",
                plannerFamily: PlannerFamily.os.rawValue
            )
        case .clickTarget:
            guard let label = bestVisibleTarget(for: state, goal: goal) else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(state.activeApplication ?? "unknown")|\(label)",
                agentKind: .ui,
                skillName: "click",
                targetRole: nil, targetLabel: label,
                locatorStrategy: "reasoning-click",
                plannerFamily: PlannerFamily.os.rawValue
            )
        case .openApplication:
            guard let targetApplication = state.targetApplication else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(targetApplication)",
                agentKind: .ui,
                skillName: "focus",
                targetRole: nil, targetLabel: targetApplication,
                locatorStrategy: "reasoning-focus",
                plannerFamily: PlannerFamily.os.rawValue
            )
        case .navigateBrowser:
            guard let targetDomain = state.targetDomain else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(targetDomain)",
                agentKind: .ui,
                skillName: "navigate_url",
                targetRole: nil,
                targetLabel: targetDomain.hasPrefix("http") ? targetDomain : "https://\(targetDomain)",
                locatorStrategy: "reasoning-browser-nav",
                plannerFamily: PlannerFamily.os.rawValue
            )
        case .rerunTests:
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(state.workspaceRoot ?? "workspace")",
                agentKind: .code,
                skillName: "run_tests",
                targetRole: nil, targetLabel: nil,
                locatorStrategy: "reasoning-rerun",
                workspaceRelativePath: state.preferredWorkspacePath,
                commandCategory: CodeCommandCategory.test.rawValue,
                plannerFamily: PlannerFamily.code.rawValue
            )
        case .retryWithAlternateTarget:
            guard let label = bestVisibleTarget(for: state, goal: goal) else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(state.activeApplication ?? "unknown")|\(label)",
                agentKind: .ui,
                skillName: "click",
                targetRole: nil, targetLabel: label,
                locatorStrategy: "reasoning-retry-alternate",
                plannerFamily: PlannerFamily.os.rawValue
            )
        case .focusWindow:
            guard let targetApplication = state.targetApplication else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(targetApplication)",
                agentKind: .ui,
                skillName: "focus",
                targetRole: nil, targetLabel: targetApplication,
                locatorStrategy: "reasoning-focus-window",
                plannerFamily: PlannerFamily.os.rawValue
            )
        case .restartApplication:
            guard let targetApplication = state.targetApplication else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(targetApplication)",
                agentKind: .ui,
                skillName: "focus",
                targetRole: nil, targetLabel: targetApplication,
                locatorStrategy: "reasoning-restart-app",
                plannerFamily: PlannerFamily.os.rawValue
            )
        case .rollbackPatch:
            guard let workspaceRoot = state.workspaceRoot else { return nil }
            return ActionContract(
                id: "reasoning|\(kind.rawValue)|\(workspaceRoot)",
                agentKind: .code,
                skillName: "git_status",
                targetRole: nil, targetLabel: nil,
                locatorStrategy: "reasoning-rollback",
                workspaceRelativePath: state.preferredWorkspacePath,
                commandCategory: CodeCommandCategory.gitStatus.rawValue,
                plannerFamily: PlannerFamily.code.rawValue
            )
        }
    }

    /// Returns an `ElementQuery` for click-based operators when applicable.
    public func semanticQuery(for state: ReasoningPlanningState, goal: Goal) -> ElementQuery? {
        guard kind == .clickTarget,
              let label = bestVisibleTarget(for: state, goal: goal)
        else { return nil }
        return ElementQuery(
            text: label,
            clickable: true,
            visibleOnly: true,
            app: state.activeApplication ?? state.targetApplication
        )
    }

    private func bestVisibleTarget(for state: ReasoningPlanningState, goal: Goal) -> String? {
        let goalTokens = Set(
            goal.description.lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
        )
        let scored = state.visibleTargets.compactMap { label -> (String, Int)? in
            let lowered = label.lowercased()
            let overlap = goalTokens.filter { lowered.contains($0) }.count
            guard overlap > 0 else { return nil }
            return (label, overlap)
        }.sorted { lhs, rhs in
            if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
            return lhs.1 > rhs.1
        }
        return scored.first?.0
    }
}
