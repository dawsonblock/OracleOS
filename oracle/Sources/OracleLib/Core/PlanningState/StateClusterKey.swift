import Foundation

// MARK: - StateClusterKey

/// A typed wrapper that groups semantically equivalent planning states into a cluster.
public struct StateClusterKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public var description: String { rawValue }
}
