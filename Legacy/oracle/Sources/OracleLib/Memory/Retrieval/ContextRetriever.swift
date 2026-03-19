import Foundation

// ─────────────────────────────────────────────────────────
// Context Retrieval — adapters for external context sources
//
// ContextRetriever connects to:
//   • GraphStore (local truth)
//   • contextdb sidecar (OpenViking — Phase 18)
//   • Code index (cocoindex — Phase 11)
//
// GraphStore remains the source of truth.
// External services are retrieval/index layers only.
// ─────────────────────────────────────────────────────────

public final class ContextRetriever {

    public func retrieveContext(goal: Goal) -> [String] {
        // Phase 18: query contextdb sidecar
        return []
    }

    public func retrieve(query: String, limit: Int = 5) -> [String] {
        // Phase 18: semantic search across contextdb
        return []
    }

    public func retrieveRelatedTasks(query: String) -> [String] {
        return []
    }

    public func retrieveArtifacts(taskID: String) -> [String] {
        return []
    }
}

public final class TaskHistorySearch {

    public func search(query: String, limit: Int = 10) -> [String] {
        return []
    }
}

public final class ExecutionTraceSearch {

    public func recentFailures(limit: Int = 10) -> [String] {
        return []
    }

    public func tracesForGoal(goalID: String) -> [String] {
        return []
    }
}
