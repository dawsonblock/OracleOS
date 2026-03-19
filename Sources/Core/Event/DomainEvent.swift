import Foundation

public protocol DomainEvent: Codable, Sendable {
    var id: UUID { get }
    var commandID: UUID { get }
    var type: String { get }
}
