import Foundation

// MARK: - FailurePattern

/// Records a failure event (app + failure class + action) for replay analysis.
public struct FailurePattern: Codable {
    public let app: String
    public let failure: FailureClass
    public let action: String
    public let timestamp: Date

    public init(app: String, failure: FailureClass, action: String) {
        self.app = app
        self.failure = failure
        self.action = action
        self.timestamp = Date()
    }
}
