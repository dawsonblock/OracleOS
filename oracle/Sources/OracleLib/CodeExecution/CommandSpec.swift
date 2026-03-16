import Foundation

public struct CommandSpec: Codable, Sendable, Equatable {
    public let category: CodeCommandCategory
    public let executable: String
    public let arguments: [String]
    public let workspaceRoot: String
    public let workspaceRelativePath: String?
    public let summary: String
    public let mutatesWorkspace: Bool
    public let touchesNetwork: Bool

    public init(
        category: CodeCommandCategory,
        executable: String,
        arguments: [String],
        workspaceRoot: String,
        workspaceRelativePath: String? = nil,
        summary: String,
        mutatesWorkspace: Bool? = nil,
        touchesNetwork: Bool = false
    ) {
        self.category = category
        self.executable = executable
        self.arguments = arguments
        self.workspaceRoot = workspaceRoot
        self.workspaceRelativePath = workspaceRelativePath
        self.summary = summary
        self.mutatesWorkspace = mutatesWorkspace ?? category.isWrite
        self.touchesNetwork = touchesNetwork
    }
}
