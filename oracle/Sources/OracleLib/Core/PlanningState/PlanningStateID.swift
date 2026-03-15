import Foundation

// MARK: - PlanningStateID

/// A typed wrapper around a raw string planning-state identifier.
public struct PlanningStateID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(raw: String) { self.rawValue = raw }

    public var description: String { rawValue }
}
