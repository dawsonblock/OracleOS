import Foundation

public enum DomainEventCodec {
    public static func encode(_ event: any DomainEvent) throws -> Data {
        let encoder = JSONEncoder()

        switch event {
        case let event as ShellExecutedEvent:
            return try encoder.encode(event)
        case let event as FileWriteEvent:
            return try encoder.encode(event)
        case let event as FileDeleteEvent:
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
        case FileWriteEvent.eventType:
            return try decoder.decode(FileWriteEvent.self, from: data)
        case FileDeleteEvent.eventType:
            return try decoder.decode(FileDeleteEvent.self, from: data)
        case HTTPResponseEvent.eventType:
            return try decoder.decode(HTTPResponseEvent.self, from: data)
        default:
            throw RuntimeError.unknownEvent(type)
        }
    }
}
