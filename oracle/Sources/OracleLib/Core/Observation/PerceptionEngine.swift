import Foundation

// ─────────────────────────────────────────────────────────
// PerceptionEngine — canonical perception pipeline
//
// Protected backbone per ARCHITECTURE_RULES.md.
//
// Fuses environment signals (AX tree, DOM, vision sidecar)
// into a unified Observation and compresses it for the
// planner. This is the read-only entry point for all
// environment perception — it never mutates state.
//
// Pipeline:
//   environment → PerceptionEngine.observe()
//     → Observation → CompressedUIState → planner
//
// The planner must only receive compressed semantic state
// objects (Button("Send"), Input("Search")), never raw AX
// structures. This engine enforces that boundary.
//
// Current implementation:
//   In the library-only build (no AppKit/AXorcist), the
//   engine accepts pre-built Observations from external
//   adapters. In the full runtime with host access, the
//   observe() call would drive AX queries, CDP calls, and
//   vision sidecar fusion internally.
// ─────────────────────────────────────────────────────────

/// Read-only perception pipeline. No side effects.
public enum PerceptionEngine {

    // ── Full pipeline: observe + compress ────────────────

    /// Produce a compressed UI state from a raw observation.
    /// This is the canonical entry for the planner.
    public static func perceive(observation: Observation) -> PerceptionResult {
        let compressed = StateAbstractionEngine.compress(observation: observation)
        let interactable = compressed.elements.filter(\.interactable)

        return PerceptionResult(
            observation: observation,
            compressed: compressed,
            interactableElements: interactable,
            observationHash: observation.stableHash()
        )
    }

    /// Lightweight perception from just elements (no metadata).
    public static func perceive(elements: [UnifiedElement]) -> CompressedUIState {
        return StateAbstractionEngine.compress(elements: elements)
    }

    // ── Context extraction (maps to oracle_context) ─────

    /// Extract orientation context from an observation.
    /// Returns a summary dict suitable for prompt injection.
    public static func getContext(from observation: Observation) -> [String: String] {
        var ctx: [String: String] = [:]
        ctx["app"] = observation.app ?? "unknown"
        ctx["windowTitle"] = observation.windowTitle ?? "none"
        ctx["url"] = observation.url ?? "none"
        ctx["focusedElement"] = observation.focusedElement?.label ?? "none"
        ctx["elementCount"] = "\(observation.elements.count)"

        let visible = observation.elements.filter(\.visible)
        ctx["visibleCount"] = "\(visible.count)"

        let interactable = StateAbstractionEngine.interactableElements(from: observation)
        ctx["interactableCount"] = "\(interactable.count)"

        // Top interactable elements for quick orientation
        let topLabels = interactable.prefix(8).compactMap(\.label)
        ctx["topInteractables"] = topLabels.joined(separator: ", ")

        return ctx
    }

    // ── Element queries (maps to oracle_find) ───────────

    /// Find elements matching a query within an observation.
    public static func findElements(
        in observation: Observation,
        query: String? = nil,
        role: String? = nil
    ) -> [UnifiedElement] {
        var results = observation.elements

        if let role = role?.lowercased() {
            results = results.filter {
                $0.role?.lowercased() == role
            }
        }

        if let query = query?.lowercased() {
            results = results.filter { elem in
                let label = elem.label?.lowercased() ?? ""
                let value = elem.value?.lowercased() ?? ""
                let id = elem.id.lowercased()
                return label.contains(query) || value.contains(query) || id.contains(query)
            }
        }

        return results
    }

    // ── State fingerprinting ────────────────────────────

    /// Build a StateSignature from a perception result.
    /// Links perception output to the state memory index.
    public static func stateSignature(from result: PerceptionResult) -> StateSignature {
        let actionTypes = result.interactableElements.map { elem in
            elem.kind.rawValue
        }
        return StateSignature.from(
            context: result.compressed.summary,
            actionTypes: actionTypes
        )
    }
}

// ── PerceptionResult ────────────────────────────────────

/// Complete output from a perception cycle.
public struct PerceptionResult {

    /// The raw observation.
    public let observation: Observation
    /// Compressed semantic UI state for the planner.
    public let compressed: CompressedUIState
    /// Just the interactable elements for quick access.
    public let interactableElements: [SemanticElement]
    /// Observation fingerprint for deduplication.
    public let observationHash: String

    public init(
        observation: Observation,
        compressed: CompressedUIState,
        interactableElements: [SemanticElement],
        observationHash: String
    ) {
        self.observation = observation
        self.compressed = compressed
        self.interactableElements = interactableElements
        self.observationHash = observationHash
    }

    /// Compact summary for logging.
    public var summary: String {
        let app = observation.app ?? "unknown"
        return "[\(app)] \(compressed.summary) hash=\(observationHash.prefix(8))"
    }
}
