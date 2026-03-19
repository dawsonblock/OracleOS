import Foundation

public struct ExecutionPolicy: Sendable {
    public let allowedShellCommands: Set<String>
    public let allowedWriteRoots: [String]
    public let networkWhitelist: Set<String>
    public let maxExecutionTime: TimeInterval
    public let maxOutputBytes: Int
    public let useContainers: Bool
    public let containerImage: String

    public init(
        allowedShellCommands: Set<String>,
        allowedWriteRoots: [String],
        networkWhitelist: Set<String>,
        maxExecutionTime: TimeInterval = 5.0,
        maxOutputBytes: Int = 50_000,
        useContainers: Bool = false,
        containerImage: String = "oracle-executor"
    ) {
        self.allowedShellCommands = allowedShellCommands
        self.allowedWriteRoots = allowedWriteRoots
        self.networkWhitelist = networkWhitelist
        self.maxExecutionTime = maxExecutionTime
        self.maxOutputBytes = maxOutputBytes
        self.useContainers = useContainers
        self.containerImage = containerImage
    }
}
