import Foundation

public enum DomainEventCodec {
    public static func encode(_ event: any DomainEvent) throws -> Data {
        let encoder = JSONEncoder()

        switch event {
        case let event as ShellExecutedEvent:
            return try encoder.encode(event)
        case let event as FileWriteRequestedEvent:
            return try encoder.encode(event)
        case let event as FileDeleteRequestedEvent:
            return try encoder.encode(event)
        case let event as HTTPResponseEvent:
            return try encoder.encode(event)
        default:
            throw RuntimeError.unknownEvent(String(describing: type(of: event)))
        }
    }

    public static func decode(type: String, data: Data) throws -> any DomainEvent {
        let decoder = JSONDecoder()

        switch type {
        case ShellExecutedEvent.eventType:
            return try decoder.decode(ShellExecutedEvent.self, from: data)
        case FileWriteRequestedEvent.eventType:
            return try decoder.decode(FileWriteRequestedEvent.self, from: data)
        case FileDeleteRequestedEvent.eventType:
            return try decoder.decode(FileDeleteRequestedEvent.self, from: data)
        case HTTPResponseEvent.eventType:
            return try decoder.decode(HTTPResponseEvent.self, from: data)
        default:
            throw RuntimeError.unknownEvent(type)
        }
    }
}
