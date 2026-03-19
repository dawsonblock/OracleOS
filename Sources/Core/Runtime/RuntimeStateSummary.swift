import Foundation

public struct RuntimeStateSummary: Codable, Sendable, Equatable {
    public let fileCount: Int
    public let commandCount: Int
    public let traceCount: Int
    public let failureCount: Int
    public let lastFailure: String
    public let lastFailedCommandType: String
    public let lastFailureTimedOut: Bool
    public let lastHTTPResponseStatus: Int
    public let lastHTTPResponseURL: String
    public let lastHTTPResponseDurationMillis: Int
    public let lastHTTPResponseSize: Int
    public let lastOutputPreview: String
    public let lastTraceEntry: String

    public init(
        fileCount: Int,
        commandCount: Int,
        traceCount: Int,
        failureCount: Int,
        lastFailure: String,
        lastFailedCommandType: String,
        lastFailureTimedOut: Bool,
        lastHTTPResponseStatus: Int,
        lastHTTPResponseURL: String,
        lastHTTPResponseDurationMillis: Int,
        lastHTTPResponseSize: Int,
        lastOutputPreview: String,
        lastTraceEntry: String
    ) {
        self.fileCount = fileCount
        self.commandCount = commandCount
        self.traceCount = traceCount
        self.failureCount = failureCount
        self.lastFailure = lastFailure
        self.lastFailedCommandType = lastFailedCommandType
        self.lastFailureTimedOut = lastFailureTimedOut
        self.lastHTTPResponseStatus = lastHTTPResponseStatus
        self.lastHTTPResponseURL = lastHTTPResponseURL
        self.lastHTTPResponseDurationMillis = lastHTTPResponseDurationMillis
        self.lastHTTPResponseSize = lastHTTPResponseSize
        self.lastOutputPreview = lastOutputPreview
        self.lastTraceEntry = lastTraceEntry
    }
}
