import Foundation

public enum PostconditionClass: String, Codable, Sendable, CaseIterable {
    case stateAdvanced = "state_advanced"
    case stateUnchanged = "state_unchanged"
    case actionFailed = "action_failed"
    case unknown
}
