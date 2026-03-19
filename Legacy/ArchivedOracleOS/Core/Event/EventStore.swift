import Foundation

public protocol EventStore: Sendable {
    func append(_ events: [any DomainEvent]) throws
    func load() throws -> [EventEnvelope]
}
