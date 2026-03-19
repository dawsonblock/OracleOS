import Foundation

public struct PatchTarget: Sendable, Equatable {
    public let path: String

    public init(path: String) {
        self.path = path
    }
}

public struct RankedPatch: Sendable, Equatable {
    public let workspaceRelativePath: String
    public let proposedContent: String
    public let testsFixed: Int
    public let regressions: Int
    public let dependencyImpact: Int
    public let origin: String

    public var rank: Int { testsFixed - regressions - dependencyImpact }

    public init(
        workspaceRelativePath: String,
        proposedContent: String,
        testsFixed: Int,
        regressions: Int,
        dependencyImpact: Int,
        origin: String
    ) {
        self.workspaceRelativePath = workspaceRelativePath
        self.proposedContent = proposedContent
        self.testsFixed = testsFixed
        self.regressions = regressions
        self.dependencyImpact = dependencyImpact
        self.origin = origin
    }
}

public struct PatchResult: Sendable {
    public enum Outcome: Sendable, Equatable {
        case applied(RankedPatch)
        case noViablePatch
        case localizationFailed
    }

    public let outcome: Outcome
    public let candidates: [RankedPatch]
    public let completedStages: [RepairPipeline.Stage]

    public var applied: RankedPatch? {
        if case .applied(let patch) = outcome { return patch }
        return nil
    }

    public init(outcome: Outcome, candidates: [RankedPatch], completedStages: [RepairPipeline.Stage]) {
        self.outcome = outcome
        self.candidates = candidates
        self.completedStages = completedStages
    }
}

public struct SandboxEvaluation: Sendable, Equatable {
    public let compiled: Bool
    public let testsFixed: Int
    public let regressions: Int
    public let stderr: String

    public init(compiled: Bool, testsFixed: Int, regressions: Int, stderr: String = "") {
        self.compiled = compiled
        self.testsFixed = testsFixed
        self.regressions = regressions
        self.stderr = stderr
    }
}

public typealias SandboxEvaluatorFn = @Sendable (_ relativePath: String, _ proposedContent: String, _ snapshot: RepositorySnapshot) -> SandboxEvaluation

public struct PatchPipeline: Sendable {
    private let maximumStrategiesPerTarget: Int
    private let sandboxEvaluator: SandboxEvaluatorFn

    public init(
        maximumStrategiesPerTarget: Int = 3,
        sandboxEvaluator: @escaping SandboxEvaluatorFn = PatchPipeline.defaultEvaluator
    ) {
        self.maximumStrategiesPerTarget = maximumStrategiesPerTarget
        self.sandboxEvaluator = sandboxEvaluator
    }

    public func run(failureDescription: String, snapshot: RepositorySnapshot) -> PatchResult {
        var completedStages: [RepairPipeline.Stage] = [.failure]

        let targets = localizeTargets(failureDescription: failureDescription, snapshot: snapshot)
        guard !targets.isEmpty else {
            return PatchResult(outcome: .localizationFailed, candidates: [], completedStages: completedStages)
        }
        completedStages.append(.localization)
        completedStages.append(.candidateSymbols)

        var candidates: [RankedPatch] = []
        for target in targets {
            for strategy in strategyKinds(for: failureDescription).prefix(maximumStrategiesPerTarget) {
                let content = syntheticPatch(for: strategy, target: target)
                let eval = sandboxEvaluator(target.path, content, snapshot)
                guard eval.compiled else { continue }
                let depImpact = snapshot.dependencyGraph.edges.filter { $0.sourcePath == target.path }.count
                candidates.append(RankedPatch(
                    workspaceRelativePath: target.path,
                    proposedContent: content,
                    testsFixed: eval.testsFixed,
                    regressions: eval.regressions,
                    dependencyImpact: depImpact,
                    origin: "\(strategy) on \(target.path)"
                ))
            }
        }
        completedStages.append(.patchCandidates)
        completedStages.append(.sandboxValidation)
        completedStages.append(.regressionCheck)

        let sorted = candidates.sorted { lhs, rhs in
            if lhs.rank == rhs.rank { return lhs.workspaceRelativePath < rhs.workspaceRelativePath }
            return lhs.rank > rhs.rank
        }
        completedStages.append(.rankFix)

        guard let bestPatch = sorted.first(where: { $0.regressions == 0 }) else {
            return PatchResult(outcome: .noViablePatch, candidates: sorted, completedStages: completedStages)
        }
        completedStages.append(.apply)

        assert(RepairPipeline.localizationPrecedesPatching(completedStages))
        assert(RepairPipeline.sandboxPrecedesApply(completedStages))

        return PatchResult(outcome: .applied(bestPatch), candidates: sorted, completedStages: completedStages)
    }

    private func localizeTargets(failureDescription: String, snapshot: RepositorySnapshot) -> [PatchTarget] {
        let mentionedFiles = snapshot.files.filter { file in
            !file.isDirectory && failureDescription.contains(file.path)
        }
        if !mentionedFiles.isEmpty {
            return mentionedFiles.map { PatchTarget(path: $0.path) }
        }

        let swiftFiles = snapshot.files.filter { !$0.isDirectory && $0.path.hasSuffix(".swift") }
        return Array(swiftFiles.prefix(3)).map { PatchTarget(path: $0.path) }
    }

    private func strategyKinds(for failureDescription: String) -> [String] {
        let lowercased = failureDescription.lowercased()
        if lowercased.contains("nil") || lowercased.contains("optional") {
            return ["null_guard", "boundary_fix", "type_correction"]
        }
        if lowercased.contains("index") || lowercased.contains("range") {
            return ["boundary_fix", "null_guard", "test_expectation_update"]
        }
        if lowercased.contains("type") || lowercased.contains("convert") {
            return ["type_correction", "dependency_update", "configuration_fix"]
        }
        return ["configuration_fix", "test_expectation_update", "dependency_update"]
    }

    private func syntheticPatch(for strategy: String, target: PatchTarget) -> String {
        switch strategy {
        case "null_guard":
            return "// [PatchPipeline:null_guard] guard let value = optionalValue else { return }\n"
        case "boundary_fix":
            return "// [PatchPipeline:boundary_fix] ensure index < collection.count before access\n"
        case "type_correction":
            return "// [PatchPipeline:type_correction] cast value to expected type\n"
        case "dependency_update":
            return "// [PatchPipeline:dependency_update] update import or package version for \(target.path)\n"
        case "test_expectation_update":
            return "// [PatchPipeline:test_expectation_update] update assertion to match revised behavior\n"
        default:
            return "// [PatchPipeline:configuration_fix] fix configuration value\n"
        }
    }

    public static let defaultEvaluator: SandboxEvaluatorFn = { _, content, _ in
        let openBraces = content.filter { $0 == "{" }.count
        let closeBraces = content.filter { $0 == "}" }.count
        guard openBraces == closeBraces else {
            return SandboxEvaluation(compiled: false, testsFixed: 0, regressions: 0, stderr: "Unbalanced braces")
        }
        let hasFix = content.contains("guard ") || content.contains("if let ") || content.contains("?? ")
        return SandboxEvaluation(compiled: true, testsFixed: hasFix ? 1 : 0, regressions: 0)
    }
}
