import Foundation

public struct Goal: Codable, Sendable, Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}
