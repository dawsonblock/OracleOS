import Foundation

// ─────────────────────────────────────────────────────────
// MacServicesTool — access protected Apple APIs (Phase 19)
//
// Capabilities: calendar, reminders, messages, notes, files
//
// All service calls are explicit actions with policy checks
// and traces. No direct API access outside this tool.
// ─────────────────────────────────────────────────────────

public final class MacServicesTool {

    public static func register(in registry: ActionRegistry) {

        registry.register("mac_calendar_read") { action in
            // Phase 19: EventKit calendar read
            return ExecutionResult(
                success: false,
                detail: "mac services not yet connected",
                actionID: action.id
            )
        }

        registry.register("mac_reminders_read") { action in
            return ExecutionResult(
                success: false,
                detail: "mac services not yet connected",
                actionID: action.id
            )
        }

        registry.register("mac_notes_read") { action in
            return ExecutionResult(
                success: false,
                detail: "mac services not yet connected",
                actionID: action.id
            )
        }
    }
}
