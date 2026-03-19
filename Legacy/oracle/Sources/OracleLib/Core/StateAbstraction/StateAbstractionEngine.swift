import Foundation

// ─────────────────────────────────────────────────────────
// StateAbstractionEngine — compress observations into
//   semantic UI state for planning
//
// Protected backbone per ARCHITECTURE_RULES.md.
//
// Converts raw UnifiedElement arrays into a compact
// semantic representation that the planner can reason
// about efficiently. This is the bridge between perception
// (hundreds of raw elements) and planning (tens of
// meaningful semantic elements).
//
// Pipeline:
//   Observation → compress(observation:) → CompressedUIState
//
// The compressed state is suitable for inclusion in LLM
// prompts and for indexing in the state memory.
// ─────────────────────────────────────────────────────────

/// The semantic kind of a UI element after classification.
public enum SemanticElementKind: String, CaseIterable {
    case button
    case input
    case text
    case link
    case list
    case menu
    case dialog
    case tab
    case image
    case toggle
    case container
    case unknown
}

/// A compressed, semantically classified UI element.
public struct SemanticElement: Equatable, Identifiable {

    public let id: String
    public let kind: SemanticElementKind
    public let label: String?
    public let interactable: Bool

    public init(
        id: String,
        kind: SemanticElementKind,
        label: String?,
        interactable: Bool
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.interactable = interactable
    }
}

/// Compressed snapshot of the UI state suitable for planning.
public struct CompressedUIState {

    public let elements: [SemanticElement]
    public let interactableCount: Int
    public let totalCount: Int
    public let dominantKind: SemanticElementKind?
    public let timestamp: Date

    public init(
        elements: [SemanticElement],
        timestamp: Date = Date()
    ) {
        self.elements = elements
        self.interactableCount = elements.filter(\.interactable).count
        self.totalCount = elements.count
        self.dominantKind = CompressedUIState.computeDominant(elements)
        self.timestamp = timestamp
    }

    /// Compact summary for logging and prompts.
    public var summary: String {
        let dom = dominantKind?.rawValue ?? "mixed"
        return "UI[\(totalCount) elements, \(interactableCount) interactable, dominant=\(dom)]"
    }

    /// Fingerprint for deduplication.
    public func fingerprint() -> String {
        var hasher = Hasher()
        for e in elements {
            hasher.combine(e.kind.rawValue)
            hasher.combine(e.label)
            hasher.combine(e.interactable)
        }
        return String(abs(hasher.finalize()))
    }

    private static func computeDominant(_ elements: [SemanticElement]) -> SemanticElementKind? {
        guard !elements.isEmpty else { return nil }
        var counts: [SemanticElementKind: Int] = [:]
        for e in elements {
            counts[e.kind, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

/// Transforms raw observations into compressed semantic states.
public enum StateAbstractionEngine {

    // ── Role mapping ────────────────────────────────────

    /// Map an AX/DOM role string to a SemanticElementKind.
    public static func mapRole(_ role: String?) -> SemanticElementKind {
        guard let role = role?.lowercased() else { return .unknown }

        switch role {
        case "button", "AXButton", "axbutton":
            return .button
        case "textfield", "textarea", "searchfield", "securetextfield",
             "AXTextField", "axtextfield", "input", "combobox":
            return .input
        case "statictext", "AXStaticText", "axstatictext", "label", "heading":
            return .text
        case "link", "AXLink", "axlink":
            return .link
        case "list", "AXList", "axlist", "outline", "table":
            return .list
        case "menu", "menubar", "menuitem", "AXMenu", "axmenu",
             "AXMenuBar", "axmenubar", "AXMenuItem", "axmenuitem":
            return .menu
        case "dialog", "sheet", "alert", "AXDialog", "axdialog",
             "AXSheet", "axsheet":
            return .dialog
        case "tab", "tabgroup", "AXTab", "axtab", "AXTabGroup", "axtabgroup":
            return .tab
        case "image", "AXImage", "aximage":
            return .image
        case "checkbox", "radiobutton", "switch", "AXCheckBox", "axcheckbox",
             "AXRadioButton", "axradiobutton":
            return .toggle
        case "group", "scrollarea", "splitgroup", "toolbar", "AXGroup", "axgroup",
             "AXScrollArea", "axscrollarea", "AXToolbar", "axtoolbar":
            return .container
        default:
            return .unknown
        }
    }

    /// Classify whether a semantic element is interactable.
    public static func classify(_ kind: SemanticElementKind) -> Bool {
        switch kind {
        case .button, .input, .link, .toggle, .tab, .menu:
            return true
        case .text, .image, .list, .dialog, .container, .unknown:
            return false
        }
    }

    // ── Compression ─────────────────────────────────────

    /// Compress a full observation into a CompressedUIState.
    public static func compress(observation: Observation) -> CompressedUIState {
        let semanticElements = observation.elements.compactMap { elem -> SemanticElement? in
            // Skip invisible elements
            guard elem.visible else { return nil }

            let kind = mapRole(elem.role)
            let interactable = classify(kind) && elem.enabled

            return SemanticElement(
                id: elem.id,
                kind: kind,
                label: elem.label,
                interactable: interactable
            )
        }

        return CompressedUIState(elements: semanticElements)
    }

    /// Compress from raw UnifiedElement array.
    public static func compress(elements: [UnifiedElement]) -> CompressedUIState {
        let semanticElements = elements.compactMap { elem -> SemanticElement? in
            guard elem.visible else { return nil }

            let kind = mapRole(elem.role)
            let interactable = classify(kind) && elem.enabled

            return SemanticElement(
                id: elem.id,
                kind: kind,
                label: elem.label,
                interactable: interactable
            )
        }

        return CompressedUIState(elements: semanticElements)
    }

    /// Quick interactable element list for the planner prompt.
    public static func interactableElements(from observation: Observation) -> [SemanticElement] {
        compress(observation: observation).elements.filter(\.interactable)
    }
}
