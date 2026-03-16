import Foundation

// ─────────────────────────────────────────────────────────
// Observation — canonical snapshot of the environment
//
// Every perception cycle produces an Observation containing
// metadata (app, window, URL) and a flat array of unified
// elements. This is the input to the entire state pipeline:
//
//   observation → change detection → diff → world model → abstraction → planner
// ─────────────────────────────────────────────────────────

/// Source of a unified element.
public enum ElementSource: String, Codable, Sendable {
    case accessibility  // AX tree
    case dom            // browser DOM
    case vision         // OCR / vision sidecar
    case synthetic      // test / generated
}

/// A single UI element fused from AX, DOM, or vision signals.
public struct UnifiedElement: Equatable, Identifiable, Sendable {

    public let id: String
    public let source: ElementSource
    public let role: String?
    public let label: String?
    public let value: String?
    public let enabled: Bool
    public let visible: Bool
    public let focused: Bool
    public let confidence: Double

    public init(
        id: String,
        source: ElementSource = .synthetic,
        role: String? = nil,
        label: String? = nil,
        value: String? = nil,
        enabled: Bool = true,
        visible: Bool = true,
        focused: Bool = false,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.source = source
        self.role = role
        self.label = label
        self.value = value
        self.enabled = enabled
        self.visible = visible
        self.focused = focused
        self.confidence = confidence
    }
}

/// A complete snapshot of the environment at a point in time.
public struct Observation: Sendable {

    public let timestamp: Date
    public let app: String?
    public let windowTitle: String?
    public let url: String?
    public let focusedElementID: String?
    public let elements: [UnifiedElement]

    public init(
        app: String? = nil,
        windowTitle: String? = nil,
        url: String? = nil,
        focusedElementID: String? = nil,
        elements: [UnifiedElement] = []
    ) {
        self.timestamp = Date()
        self.app = app
        self.windowTitle = windowTitle
        self.url = url
        self.focusedElementID = focusedElementID
        self.elements = elements
    }

    /// The focused element, if any.
    public var focusedElement: UnifiedElement? {
        guard let focusedElementID else { return nil }
        return elements.first { $0.id == focusedElementID }
    }

    /// Stable hash for deduplication and diff detection.
    public func stableHash() -> String {
        var hasher = Hasher()
        hasher.combine(app)
        hasher.combine(windowTitle)
        hasher.combine(url)
        hasher.combine(elements.count)
        for e in elements {
            hasher.combine(e.id)
            hasher.combine(e.role)
            hasher.combine(e.label)
        }
        return String(abs(hasher.finalize()))
    }
}
