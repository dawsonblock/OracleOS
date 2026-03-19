import Foundation

// ─────────────────────────────────────────────────────────
// RecipeEngine — recipe execution engine
//
// Validates inputs, checks preconditions, and executes each
// step by dispatching to ActionRegistry.shared.
//
// Design:
//   • Pure enum namespace — no stored state
//   • Synchronous — callers handle async wrapping if needed
//   • param substitution: {{name}} tokens in step params
//   • Failure policy: per-step onFailure ?? recipe.onFailure ?? "stop"
// ─────────────────────────────────────────────────────────

/// Executes recipe scripts against the action registry.
///
/// **Usage:**
/// ```swift
/// let result = RecipeEngine.run(recipe: myRecipe, params: ["query": "Swift closures"])
/// ```
public enum RecipeEngine {

    // ── Primary API ──────────────────────────────────────

    /// Execute a recipe with the supplied parameter values.
    ///
    /// - Parameters:
    ///   - recipe: The recipe to execute.
    ///   - params: Runtime values for declared parameters.
    ///   - registry: Action registry to dispatch step actions through.
    ///     Defaults to the shared registry.
    /// - Returns: A `RecipeRunResult` describing each step's outcome.
    public static func run(
        recipe: Recipe,
        params: [String: String] = [:],
        registry: ActionRegistry = .shared
    ) -> RecipeRunResult {
        let start = Date()

        // ── 1. Validate required parameters ─────────────
        if let paramDecls = recipe.params {
            for (name, decl) in paramDecls where decl.required == true {
                if params[name] == nil || params[name]?.isEmpty == true {
                    return RecipeRunResult(
                        recipeName: recipe.name,
                        success: false,
                        stepsCompleted: 0,
                        totalSteps: recipe.steps.count,
                        stepResults: [],
                        error: "Missing required parameter: '\(name)'"
                    )
                }
            }
        }

        // ── 2. Check preconditions ────────────────────────
        if let pre = recipe.preconditions, let check = checkPreconditions(pre) {
            return RecipeRunResult(
                recipeName: recipe.name,
                success: false,
                stepsCompleted: 0,
                totalSteps: recipe.steps.count,
                stepResults: [],
                error: "Precondition not met: \(check)"
            )
        }

        // ── 3. Execute steps ─────────────────────────────
        var stepResults: [RecipeStepResult] = []
        var stepsCompleted = 0

        for step in recipe.steps {
            let stepStart = Date()
            let substitutedParams = substituteParams(step.params, with: params)
            let intent = buildIntent(for: step, substitutedParams: substitutedParams)

            let handler = registry.handler(for: step.action)
            let executionResult = handler(intent)
            let durationMs = Int(Date().timeIntervalSince(stepStart) * 1000)

            if executionResult.success {
                stepsCompleted += 1
                stepResults.append(RecipeStepResult(
                    stepId: step.id,
                    action: step.action,
                    success: true,
                    durationMs: durationMs,
                    note: step.note
                ))
            } else {
                // ── Apply failure policy ─────────────────
                let policy = step.onFailure ?? recipe.onFailure ?? "stop"
                let errorMsg = executionResult.detail.isEmpty ? "step \(step.id) failed" : executionResult.detail

                stepResults.append(RecipeStepResult(
                    stepId: step.id,
                    action: step.action,
                    success: false,
                    durationMs: durationMs,
                    error: errorMsg,
                    note: step.note
                ))

                if policy == "skip" {
                    // Continue to next step
                    continue
                } else {
                    // "stop" (default) — abort execution
                    return RecipeRunResult(
                        recipeName: recipe.name,
                        success: false,
                        stepsCompleted: stepsCompleted,
                        totalSteps: recipe.steps.count,
                        stepResults: stepResults,
                        error: "Stopped at step \(step.id) (\(step.action)): \(errorMsg)"
                    )
                }
            }
        }

        let _ = start  // timing available if needed
        return RecipeRunResult(
            recipeName: recipe.name,
            success: true,
            stepsCompleted: stepsCompleted,
            totalSteps: recipe.steps.count,
            stepResults: stepResults
        )
    }

    // ── Private helpers ──────────────────────────────────

    /// Check preconditions — returns a failure reason string or nil.
    private static func checkPreconditions(_ pre: RecipePreconditions) -> String? {
        if let urlContains = pre.urlContains, urlContains.isEmpty {
            return "urlContains precondition is empty"
        }
        return nil
    }

    /// Substitute {{name}} tokens in step params with runtime values.
    private static func substituteParams(
        _ stepParams: [String: String]?,
        with runtimeParams: [String: String]
    ) -> [String: String] {
        guard let stepParams = stepParams else { return [:] }
        return stepParams.mapValues { value in
            var result = value
            for (name, runtimeValue) in runtimeParams {
                result = result.replacingOccurrences(of: "{{\(name)}}", with: runtimeValue)
            }
            return result
        }
    }

    /// Build an `ActionIntent` from a step's params and target name.
    private static func buildIntent(
        for step: RecipeStep,
        substitutedParams: [String: String]
    ) -> ActionIntent {
        var parameters = substitutedParams
        if let target = step.targetName {
            parameters["target"] = target
        }
        return ActionIntent(type: step.action, parameters: parameters)
    }}