import Foundation

public protocol DomainEvent: Codable, Sendable {
    var type: String { get }
}

public struct ShellExecutedEvent: DomainEvent, Equatable {
    public static let eventType = "shell.executed"

    public let command: String
    public let output: String
    public let status: Int32

    public var type: String { Self.eventType }

    public init(command: String, output: String, status: Int32) {
        self.command = command
        self.output = output
        self.status = status
    }
}

public struct FileWriteRequestedEvent: DomainEvent, Equatable {
    public static let eventType = "file.write.requested"

    public let path: String
    public let content: String

    public var type: String { Self.eventType }

    public init(path: String, content: String) {
        self.path = path
        self.content = content
    }
}

public struct FileDeleteRequestedEvent: DomainEvent, Equatable {
    public static let eventType = "file.delete.requested"

    public let path: String

    public var type: String { Self.eventType }

    public init(path: String) {
        self.path = path
    }
}

public struct HTTPResponseEvent: DomainEvent, Equatable {
    public static let eventType = "http.response.received"

    public let url: String
    public let size: Int

    public var type: String { Self.eventType }

    public init(url: String, size: Int) {
        self.url = url
        self.size = size
    }
}
