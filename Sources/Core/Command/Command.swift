import Foundation

public struct Command: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let type: String
    public let payload: [String: Any]

    public init(
        id: UUID = UUID(),
        type: String,
        payload: [String: Any] = [:]
    ) {
        self.id = id
        self.type = type
        self.payload = payload
    }

    public func stringValue(for key: String) -> String? {
        payload[key] as? String
    }

    public func intValue(for key: String) -> Int? {
        if let value = payload[key] as? Int {
            return value
        }

        if let value = payload[key] as? String {
            return Int(value)
        }

        return nil
    }
}
