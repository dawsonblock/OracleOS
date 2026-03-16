import Foundation

// ─────────────────────────────────────────────────────────
// PatchExperimentRunner — bounded parallel code experiments
//
// Pipeline:
//   generate patch → spawn worktree → apply → run tests → score
//
// All patches go through worktree or sandbox — never main branch.
// Results feed back through VerifiedActionExecutor and trace.
// ─────────────────────────────────────────────────────────

public final class PatchExperimentRunner {

    public let sandbox: WorktreeSandbox
    public let ranker: ResultRanker

    public init(
        sandbox: WorktreeSandbox = WorktreeSandbox(),
        ranker: ResultRanker = ResultRanker()
    ) {
        self.sandbox = sandbox
        self.ranker = ranker
    }

    public struct ExperimentResult {
        public let patchID: String
        public let worktree: String
        public let testsPassed: Bool
        public let score: Double
        public let detail: String
    }

    public func runExperiment(
        repoPath: String,
        patchContent: String,
        testCommand: String = "swift test"
    ) -> ExperimentResult {

        let patchID = UUID().uuidString

        // 1. Create isolated worktree
        let worktree = sandbox.create(basePath: repoPath, branchPrefix: "experiment")

        // 2. Apply patch in worktree
        let applied = sandbox.applyPatch(worktree: worktree, patch: patchContent)
        guard applied else {
            return ExperimentResult(
                patchID: patchID, worktree: worktree,
                testsPassed: false, score: 0, detail: "patch application failed"
            )
        }

        // 3. Run tests (Phase 9: route through sandbox sidecar for untrusted)
        let testResult = sandbox.runTests(worktree: worktree, command: testCommand)

        // 4. Score result
        let score = ranker.score(testsPassed: testResult, patchSize: patchContent.count)

        return ExperimentResult(
            patchID: patchID, worktree: worktree,
            testsPassed: testResult, score: score,
            detail: testResult ? "tests passed" : "tests failed"
        )
    }

    public func runParallel(
        repoPath: String,
        patches: [String],
        testCommand: String = "swift test",
        maxCandidates: Int = 3
    ) -> [ExperimentResult] {

        let candidates = Array(patches.prefix(maxCandidates))

        // Phase 13: actual parallel execution via DispatchGroup
        return candidates.map { patch in
            runExperiment(repoPath: repoPath, patchContent: patch, testCommand: testCommand)
        }
    }

    public func bestCandidate(results: [ExperimentResult]) -> ExperimentResult? {
        return results.filter { $0.testsPassed }.max(by: { $0.score < $1.score })
    }
}

// ─────────────────────────────────────────────────────────
// WorktreeSandbox — git worktree lifecycle
// ─────────────────────────────────────────────────────────

public final class WorktreeSandbox {

    public init() {}

    public func create(basePath: String, branchPrefix: String) -> String {
        // Phase 13: actual git worktree add
        let id = UUID().uuidString.prefix(8)
        return "\(basePath)/.worktrees/\(branchPrefix)-\(id)"
    }

    public func applyPatch(worktree: String, patch: String) -> Bool {
        // Phase 13: write patch file and git apply
        print("[worktree] Would apply patch to \(worktree)")
        return true
    }

    public func runTests(worktree: String, command: String) -> Bool {
        // Phase 13: run test command in worktree
        print("[worktree] Would run '\(command)' in \(worktree)")
        return false
    }

    public func cleanup(worktree: String) {
        // Phase 13: git worktree remove
        print("[worktree] Would remove \(worktree)")
    }
}

// ─────────────────────────────────────────────────────────
// ResultRanker — score experiment outcomes
//
// Ranking: passing tests > fewer touched files > smaller diff
// ─────────────────────────────────────────────────────────

public final class ResultRanker {

    public init() {}

    public func score(testsPassed: Bool, patchSize: Int) -> Double {
        var score = 0.0
        if testsPassed { score += 1.0 }
        // Prefer smaller patches (less invasive)
        let sizePenalty = min(Double(patchSize) / 10000.0, 0.5)
        score -= sizePenalty
        return max(score, 0)
    }

    public func rank(results: [PatchExperimentRunner.ExperimentResult]) -> [PatchExperimentRunner.ExperimentResult] {
        return results.sorted { $0.score > $1.score }
    }
}

// ─────────────────────────────────────────────────────────
// ExperimentManager — coordinate experiment lifecycle
// ─────────────────────────────────────────────────────────

public final class ExperimentManager {

    private var history: [PatchExperimentRunner.ExperimentResult] = []

    public init() {}

    public func record(result: PatchExperimentRunner.ExperimentResult) {
        history.append(result)
    }

    public func recentExperiments(limit: Int = 20) -> [PatchExperimentRunner.ExperimentResult] {
        return Array(history.suffix(limit))
    }

    public func successRate() -> Double {
        guard !history.isEmpty else { return 0 }
        let passed = history.filter { $0.testsPassed }.count
        return Double(passed) / Double(history.count)
    }
}
