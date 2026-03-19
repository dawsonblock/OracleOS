import Foundation

public final class FileEventStore: EventStore, @unchecked Sendable {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(path: String) {
        self.url = URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: ".")).standardizedFileURL
    }

    public func append(_ events: [any DomainEvent]) throws {
        guard !events.isEmpty else {
            return
        }

        for event in events {
            let payload = try DomainEventCodec.encode(event)
            let envelope = EventEnvelope(
                id: event.id,
                commandID: event.commandID,
                type: event.type,
                event: payload
            )
            var line = try encoder.encode(envelope)
            line.append(0x0A)
            try VerifiedExecutor.appendData(line, to: url)
        }
    }

    public func load() throws -> [EventEnvelope] {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty
        else {
            return []
        }

        return try text
            .split(separator: "\n")
            .map { line in
                try decoder.decode(EventEnvelope.self, from: Data(line.utf8))
            }
    }
}
