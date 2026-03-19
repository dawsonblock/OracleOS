import Foundation

public struct WorldState: Codable, Sendable, Equatable {
    public var files: [String: String]
    public var lastOutput: String
    public var lastHTTPResponseSize: Int
    public var executedCommandIDs: [UUID]
    public var executionTrace: [String]

    public init(
        files: [String: String] = [:],
        lastOutput: String = "",
        lastHTTPResponseSize: Int = 0,
        executedCommandIDs: [UUID] = [],
        executionTrace: [String] = []
    ) {
        self.files = files
        self.lastOutput = lastOutput
        self.lastHTTPResponseSize = lastHTTPResponseSize
        self.executedCommandIDs = executedCommandIDs
        self.executionTrace = executionTrace
    }

    public static let empty = WorldState()
}
