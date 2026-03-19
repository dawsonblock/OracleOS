import Foundation

public struct WorldState: Codable, Sendable, Equatable {
    public var files: [String: String]
    public var lastOutput: String
    public var lastHTTPResponseSize: Int
    public var lastHTTPResponseStatus: Int
    public var lastHTTPResponseURL: String
    public var lastHTTPResponseDurationMillis: Int
    public var executedCommandIDs: [UUID]
    public var executionTrace: [String]
    public var failureCount: Int
    public var lastFailure: String
    public var lastFailedCommandType: String
    public var lastFailureTimedOut: Bool

    public init(
        files: [String: String] = [:],
        lastOutput: String = "",
        lastHTTPResponseSize: Int = 0,
        lastHTTPResponseStatus: Int = 0,
        lastHTTPResponseURL: String = "",
        lastHTTPResponseDurationMillis: Int = 0,
        executedCommandIDs: [UUID] = [],
        executionTrace: [String] = [],
        failureCount: Int = 0,
        lastFailure: String = "",
        lastFailedCommandType: String = "",
        lastFailureTimedOut: Bool = false
    ) {
        self.files = files
        self.lastOutput = lastOutput
        self.lastHTTPResponseSize = lastHTTPResponseSize
        self.lastHTTPResponseStatus = lastHTTPResponseStatus
        self.lastHTTPResponseURL = lastHTTPResponseURL
        self.lastHTTPResponseDurationMillis = lastHTTPResponseDurationMillis
        self.executedCommandIDs = executedCommandIDs
        self.executionTrace = executionTrace
        self.failureCount = failureCount
        self.lastFailure = lastFailure
        self.lastFailedCommandType = lastFailedCommandType
        self.lastFailureTimedOut = lastFailureTimedOut
    }

    public static let empty = WorldState()
}
