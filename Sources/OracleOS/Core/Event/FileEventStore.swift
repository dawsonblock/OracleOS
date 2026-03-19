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

        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: url.path) {
            try Data().write(to: url)
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()

        for event in events {
            let encodedEvent = try DomainEventCodec.encode(event)
            let envelope = EventEnvelope(event: encodedEvent, type: event.type)
            let data = try encoder.encode(envelope)
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data("\n".utf8))
        }
    }

    public func load() throws -> [EventEnvelope] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
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
