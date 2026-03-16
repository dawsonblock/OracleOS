import Foundation

// ─────────────────────────────────────────────────────────
// PromptBuilder — construct prompts from assembled context (Phase 6)
//
// Takes an AssembledContext + a template, produces a final
// prompt string ready for the LLM.
// ─────────────────────────────────────────────────────────

public final class PromptBuilder {

    public enum Template: String {
        case plan   = "plan"
        case reason = "reason"
        case repair = "repair"
        case search = "search"
    }

    public func build(template: Template, context: ContextAssembler.AssembledContext) -> String {
        let header: String
        switch template {
        case .plan:
            header = "You are Oracle, an autonomous agent. Generate a plan for the goal below."
        case .reason:
            header = "You are Oracle. Reason about the current situation and decide the next action."
        case .repair:
            header = "You are Oracle. Diagnose the failure and suggest a repair patch."
        case .search:
            header = "You are Oracle. Synthesize an answer from the search results."
        }

        return """
        \(header)

        \(context.text)
        """
    }
}
