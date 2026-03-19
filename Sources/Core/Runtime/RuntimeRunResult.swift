import Foundation

public struct RuntimeRunResult: Codable, Sendable, Equatable {
    public let state: WorldState
    public let success: Bool
    public let issues: [String]
    public let emittedEventCount: Int

    public init(
        state: WorldState,
        success: Bool,
        issues: [String],
        emittedEventCount: Int
    ) {
        self.state = state
        self.success = success
        self.issues = issues
        self.emittedEventCount = emittedEventCount
    }
}
