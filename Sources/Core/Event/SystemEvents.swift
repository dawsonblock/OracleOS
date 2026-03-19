import Foundation

public struct ExecutionBackendSelectedEvent: DomainEvent, Equatable {
    public static let eventType = "execution.backend.selected"

    public let id: UUID
    public let commandID: UUID
    public let backend: String
    public let detail: String

    public var type: String { Self.eventType }

    public init(
        id: UUID = UUID(),
        commandID: UUID,
        backend: String,
        detail: String
    ) {
        self.id = id
        self.commandID = commandID
        self.backend = backend
        self.detail = detail
    }
}

public struct ShellExecutedEvent: DomainEvent, Equatable {
    public static let eventType = "shell.executed"

    public let id: UUID
    public let commandID: UUID
    public let command: String
    public let output: String
    public let status: Int32

    public var type: String { Self.eventType }

    public init(
        id: UUID = UUID(),
        commandID: UUID,
        command: String,
        output: String,
        status: Int32
    ) {
        self.id = id
        self.commandID = commandID
        self.command = command
        self.output = output
        self.status = status
    }
}

public struct FileWriteEvent: DomainEvent, Equatable {
    public static let eventType = "file.write"

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

public struct FileDeleteEvent: DomainEvent, Equatable {
    public static let eventType = "file.delete"

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
    public static let eventType = "http.response"

    public let id: UUID
    public let commandID: UUID
    public let url: String
    public let body: String

    public var type: String { Self.eventType }

    public init(
        id: UUID = UUID(),
        commandID: UUID,
        url: String,
        body: String
    ) {
        self.id = id
        self.commandID = commandID
        self.url = url
        self.body = body
    }
}
