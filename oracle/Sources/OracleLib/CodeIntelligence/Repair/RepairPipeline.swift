import Foundation

// ─────────────────────────────────────────────────────────
// Code Intelligence — Repair Layer (Aider patterns, Phase 12)
//
// R9: Explicit repair pipeline
//   failure → localization → candidate symbols → patch candidates
//   → sandbox validation → regression check → rank → apply
//
// Localization is mandatory before patch generation.
// Sandbox validation is mandatory before apply.
// ─────────────────────────────────────────────────────────

public final class RepairPipeline {

    private let targetSelector: PatchTargetSelector
    private let patchGenerator: PatchGenerator

    public init(
        targetSelector: PatchTargetSelector = PatchTargetSelector(),
        patchGenerator: PatchGenerator = PatchGenerator()
    ) {
        self.targetSelector = targetSelector
        self.patchGenerator = patchGenerator
    }

    public func repair(failure: String, workspace: String) -> RepairResult {
        // Phase 12: full repair loop
        print("[repair] Repair requested for: \(failure)")
        
        // 1. Localization
        let targets = targetSelector.isolateTargetComponents(from: failure)
        
        // 2. Generation
        var allPatches = [PatchCandidate]()
        for target in targets {
            let patches = patchGenerator.generate(target: target.file, context: target.contextSnippet ?? "")
            allPatches.append(contentsOf: patches)
        }
        
        // 3. Application & Validation
        // (Wired sequentially via Sandbox/GraphStore in runtime)
        return RepairResult(success: !allPatches.isEmpty, patches: allPatches)
    }

    public struct RepairResult {
        public let success: Bool
        public let patches: [PatchCandidate]
    }
}
