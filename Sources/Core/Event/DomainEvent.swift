import Foundation

public protocol DomainEvent: Codable, Sendable {
    var id: UUID { get }
    var commandID: UUID { get }
    var type: String { get }
}

public struct ShellExecutedEvent: DomainEvent, Equatable {
    public static let eventType = "shell.executed"

    public let id: UUID
    public let commandID: UUID
    public let command: String
    public let output: String
    public let status: Int32
    public let durationMillis: Int

    public var type: String { Self.eventType }

    public init(
        id: UUID = UUID(),
        commandID: UUID,
        command: String,
        output: String,
        status: Int32,
        durationMillis: Int
    ) {
        self.id = id
        self.commandID = commandID
        self.command = command
        self.output = output
        self.status = status
        self.durationMillis = durationMillis
    }
}

public struct FileWriteRequestedEvent: DomainEvent, Equatable {
    public static let eventType = "file.write.requested"

    public let id: UUID
    public let commandID: UUID
    public let path: String
    public let content: String

    public var type: String { Self.eventType }

    public init(
        id: UUID = UUID(),
        commandID: UUID,
        path: String,
        content: String
    ) {
        self.id = id
        self.commandID = commandID
        self.path = path
        self.content = content
    }
}

public struct FileDeleteRequestedEvent: DomainEvent, Equatable {
    public static let eventType = "file.delete.requested"

    public let id: UUID
    public let commandID: UUID
    public let path: String

    public var type: String { Self.eventType }

    public init(
        id: UUID = UUID(),
        commandID: UUID,
        path: String
    ) {
        self.id = id
        self.commandID = commandID
        self.path = path
    }
}

public struct HTTPResponseEvent: DomainEvent, Equatable {
    public static let eventType = "http.response.received"

    public let id: UUID
    public let commandID: UUID
    public let url: String
    public let size: Int
    public let status: Int
    public let durationMillis: Int

    public var type: String { Self.eventType }

    public init(
        id: UUID = UUID(),
        commandID: UUID,
        url: String,
        size: Int,
        status: Int,
        durationMillis: Int
    ) {
        self.id = id
        self.commandID = commandID
        self.url = url
        self.size = size
        self.status = status
        self.durationMillis = durationMillis
    }
}
