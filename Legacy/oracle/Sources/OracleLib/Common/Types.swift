import Foundation

public enum OracleOS {
    public static let version = "2.0.6"
    public static let name = "oracle-os"
}

public struct ToolResult: @unchecked Sendable {
    public let success: Bool
    public let data: [String: Any]?
    public let error: String?
    public let suggestion: String?
    public let context: ContextInfo?

    public init(
        success: Bool,
        data: [String: Any]? = nil,
        error: String? = nil,
        suggestion: String? = nil,
        context: ContextInfo? = nil
    ) {
        self.success = success
        self.data = data
        self.error = error
        self.suggestion = suggestion
        self.context = context
    }

    public func toDict() -> [String: Any] {
        var result: [String: Any] = ["success": success]
        if let data { result["data"] = data }
        if let error { result["error"] = error }
        if let suggestion { result["suggestion"] = suggestion }
        if let context { result["context"] = context.toDict() }
        return result
    }
}

public struct ContextInfo: Sendable {
    public let app: String?
    public let window: String?
    public let focusedElement: String?
    public let url: String?

    public init(app: String? = nil, window: String? = nil, focusedElement: String? = nil, url: String? = nil) {
        self.app = app
        self.window = window
        self.focusedElement = focusedElement
        self.url = url
    }

    public func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let app { dict["app"] = app }
        if let window { dict["window"] = window }
        if let focusedElement { dict["focused_element"] = focusedElement }
        if let url { dict["url"] = url }
        return dict
    }
}

public struct ScreenshotResult: Sendable {
    public let base64PNG: String
    public let width: Int
    public let height: Int
    public let windowTitle: String?
    public let mimeType: String
    public let windowX: Double
    public let windowY: Double
    public let windowWidth: Double
    public let windowHeight: Double

    public init(
        base64PNG: String,
        width: Int,
        height: Int,
        windowTitle: String? = nil,
        mimeType: String = "image/png",
        windowX: Double = 0,
        windowY: Double = 0,
        windowWidth: Double = 0,
        windowHeight: Double = 0
    ) {
        self.base64PNG = base64PNG
        self.width = width
        self.height = height
        self.windowTitle = windowTitle
        self.mimeType = mimeType
        self.windowX = windowX
        self.windowY = windowY
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
    }
}

public enum OracleError: Error, Sendable {
    case timeout(seconds: TimeInterval)
    case elementNotFound(description: String)
    case actionFailed(description: String)
    case appNotFound(name: String)
    case permissionDenied(String)
    case invalidParameter(String)

    public var localizedDescription: String {
        switch self {
        case .timeout(let seconds):
            return "Operation timed out after \(Int(seconds)) seconds"
        case .elementNotFound(let description):
            return "Element not found: \(description)"
        case .actionFailed(let description):
            return "Action failed: \(description)"
        case .appNotFound(let name):
            return "Application not found: \(name)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        }
    }
}

public enum OracleConstants {
    public static let semanticDepthBudget = 25
    public static let defaultTimeoutSeconds: TimeInterval = 30
    public static let defaultPollInterval: TimeInterval = 0.5
    public static let maxSearchDepth = 100
    public static var recipesDirectory: String { OracleProductPaths.recipesDirectory.path }
    public static var logsDirectory: String { OracleProductPaths.logsDirectory.path }
    public static var approvalsDirectory: String { OracleProductPaths.approvalsDirectory.path }
    public static var graphDirectory: String { OracleProductPaths.graphDirectory.path }
}
