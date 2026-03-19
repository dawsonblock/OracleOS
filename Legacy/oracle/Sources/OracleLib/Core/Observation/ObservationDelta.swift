import Foundation

// ─────────────────────────────────────────────────────────
// ObservationDelta — element-level change detection output
//
// Represents the fine-grained set of changes between two
// Observation snapshots. During long autonomous runs only a
// small fraction of UI elements change each loop iteration.
// By capturing exactly what changed, the system avoids
// re-processing thousands of unchanged elements.
//
// Pipeline:
//   previous observation
//     → ObservationChangeDetector.detect(previous:incoming:)
//     → ObservationDelta
//     → StateDiffEngine
//     → WorldStateModel.apply(diff:)
// ─────────────────────────────────────────────────────────

/// Fine-grained changes between two observations.
public struct ObservationDelta {

    // ── Metadata changes ────────────────────────────────

    public let applicationChanged: StringChange?
    public let windowTitleChanged: StringChange?
    public let urlChanged: StringChange?
    public let focusChanged: StringChange?

    // ── Element-level changes ───────────────────────────

    public let addedElements: [UnifiedElement]
    public let removedElementIDs: [String]
    public let changedElements: [ElementChange]

    public var isEmpty: Bool {
        applicationChanged == nil
            && windowTitleChanged == nil
            && urlChanged == nil
            && focusChanged == nil
            && addedElements.isEmpty
            && removedElementIDs.isEmpty
            && changedElements.isEmpty
    }

    public var changeCount: Int {
        var count = 0
        if applicationChanged != nil { count += 1 }
        if windowTitleChanged != nil { count += 1 }
        if urlChanged != nil { count += 1 }
        if focusChanged != nil { count += 1 }
        count += addedElements.count
        count += removedElementIDs.count
        count += changedElements.count
        return count
    }

    public init(
        applicationChanged: StringChange? = nil,
        windowTitleChanged: StringChange? = nil,
        urlChanged: StringChange? = nil,
        focusChanged: StringChange? = nil,
        addedElements: [UnifiedElement] = [],
        removedElementIDs: [String] = [],
        changedElements: [ElementChange] = []
    ) {
        self.applicationChanged = applicationChanged
        self.windowTitleChanged = windowTitleChanged
        self.urlChanged = urlChanged
        self.focusChanged = focusChanged
        self.addedElements = addedElements
        self.removedElementIDs = removedElementIDs
        self.changedElements = changedElements
    }

    // ── Nested types ────────────────────────────────────

    /// A change to an optional string field.
    public struct StringChange: Equatable {
        public let from: String?
        public let to: String?
        public init(from: String?, to: String?) {
            self.from = from
            self.to = to
        }
    }

    /// Describes how a persisting element's properties changed.
    public struct ElementChange {
        public let elementID: String
        public let updatedElement: UnifiedElement
        public let changedProperties: Set<ElementProperty>
        public init(
            elementID: String,
            updatedElement: UnifiedElement,
            changedProperties: Set<ElementProperty>
        ) {
            self.elementID = elementID
            self.updatedElement = updatedElement
            self.changedProperties = changedProperties
        }
    }

    /// Which property of a UnifiedElement changed.
    public enum ElementProperty: String, Hashable, CaseIterable {
        case label
        case value
        case enabled
        case visible
        case focused
        case role
        case confidence
    }
}
