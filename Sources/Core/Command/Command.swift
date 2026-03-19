import Foundation

public struct Command: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let type: String
    public let payload: [String: String]

    public init(
        id: UUID = UUID(),
        type: String,
        payload: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.payload = payload
    }
}
