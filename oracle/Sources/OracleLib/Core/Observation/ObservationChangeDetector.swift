import Foundation

// ─────────────────────────────────────────────────────────
// ObservationChangeDetector — element-level diff between
//   two Observation snapshots
//
// Protected backbone per ARCHITECTURE_RULES.md.
//
// Pipeline:
//   previous observation → detect(previous:incoming:) → ObservationDelta
//
// By producing a delta of only what changed, downstream
// consumers avoid re-processing the entire UI tree each
// loop iteration. During long sessions this can reduce
// observation processing cost by an order of magnitude.
// ─────────────────────────────────────────────────────────

public enum ObservationChangeDetector {

    /// Compare two observations and produce a delta.
    public static func detect(
        previous: Observation,
        incoming: Observation
    ) -> ObservationDelta {

        // ── Metadata changes ────────────────────────────
        let appChange: ObservationDelta.StringChange? =
            previous.app != incoming.app
                ? .init(from: previous.app, to: incoming.app)
                : nil

        let windowChange: ObservationDelta.StringChange? =
            previous.windowTitle != incoming.windowTitle
                ? .init(from: previous.windowTitle, to: incoming.windowTitle)
                : nil

        let urlChange: ObservationDelta.StringChange? =
            previous.url != incoming.url
                ? .init(from: previous.url, to: incoming.url)
                : nil

        let focusChange: ObservationDelta.StringChange? =
            previous.focusedElementID != incoming.focusedElementID
                ? .init(from: previous.focusedElementID, to: incoming.focusedElementID)
                : nil

        // ── Element-level diffing ───────────────────────
        let previousByID = Dictionary(
            previous.elements.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let incomingByID = Dictionary(
            incoming.elements.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let previousIDs = Set(previousByID.keys)
        let incomingIDs = Set(incomingByID.keys)

        // Added: present in incoming but not previous
        let addedIDs = incomingIDs.subtracting(previousIDs)
        let addedElements = addedIDs.compactMap { incomingByID[$0] }

        // Removed: present in previous but not incoming
        let removedIDs = Array(previousIDs.subtracting(incomingIDs))

        // Changed: present in both but with differing properties
        let persistingIDs = previousIDs.intersection(incomingIDs)
        var changedElements: [ObservationDelta.ElementChange] = []

        for id in persistingIDs {
            guard let old = previousByID[id], let new = incomingByID[id] else { continue }
            let changed = diffProperties(old: old, new: new)
            if !changed.isEmpty {
                changedElements.append(
                    ObservationDelta.ElementChange(
                        elementID: id,
                        updatedElement: new,
                        changedProperties: changed
                    )
                )
            }
        }

        return ObservationDelta(
            applicationChanged: appChange,
            windowTitleChanged: windowChange,
            urlChanged: urlChange,
            focusChanged: focusChange,
            addedElements: addedElements,
            removedElementIDs: removedIDs,
            changedElements: changedElements
        )
    }

    // ── Volatile property filtering ─────────────────────

    /// Properties that change frequently but do not affect planning.
    public static let volatileProperties: Set<ObservationDelta.ElementProperty> = [.confidence]

    /// Compare excluding volatile properties.
    public static func diffPlanningProperties(
        old: UnifiedElement,
        new: UnifiedElement
    ) -> Set<ObservationDelta.ElementProperty> {
        diffProperties(old: old, new: new).subtracting(volatileProperties)
    }

    // ── Internal helpers ────────────────────────────────

    static func diffProperties(
        old: UnifiedElement,
        new: UnifiedElement
    ) -> Set<ObservationDelta.ElementProperty> {
        var changed = Set<ObservationDelta.ElementProperty>()

        if old.label != new.label         { changed.insert(.label) }
        if old.value != new.value         { changed.insert(.value) }
        if old.enabled != new.enabled     { changed.insert(.enabled) }
        if old.visible != new.visible     { changed.insert(.visible) }
        if old.focused != new.focused     { changed.insert(.focused) }
        if old.role != new.role           { changed.insert(.role) }
        if old.confidence != new.confidence { changed.insert(.confidence) }

        return changed
    }
}
