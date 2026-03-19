import Foundation

public struct Command: Codable, Sendable, Equatable {
    public let type: String
    public let payload: [String: String]

    public init(type: String, payload: [String: String] = [:]) {
        self.type = type
        self.payload = payload
    }
}
