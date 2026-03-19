import Foundation

public final class FileEventStore: EventStore, @unchecked Sendable {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(path: String) {
        self.url = URL(fileURLWithPath: path)
    }

    public func append(_ events: [any DomainEvent]) throws {
        guard !events.isEmpty else { return }

        let directory = url.deletingLastPathComponent()
        if !RuntimeFilesystem.fileExists(atPath: directory.path) {
            try RuntimeFilesystem.ensureDirectory(at: directory)
        }
        if !RuntimeFilesystem.fileExists(atPath: url.path) {
            try RuntimeFilesystem.saveData(Data(), to: url)
        }

        for event in events {
            let encodedEvent = try DomainEventCodec.encode(event)
            let envelope = EventEnvelope(event: encodedEvent, type: event.type)
            let data = try encoder.encode(envelope)
            var line = data
            line.append(0x0A)
            try RuntimeFilesystem.append(line, to: url)
        }
    }

    public func load() throws -> [EventEnvelope] {
        guard RuntimeFilesystem.fileExists(atPath: url.path) else {
            return []
        }

        let data = try RuntimeFilesystem.loadData(at: url)
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            return []
        }

        return try text
            .split(separator: "\n")
            .map { line in
                try decoder.decode(EventEnvelope.self, from: Data(line.utf8))
            }
    }
}
