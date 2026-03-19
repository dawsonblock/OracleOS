import Foundation

// ─────────────────────────────────────────────────────────
// ActionSchema — typed action schemas with pre/postconditions
//
// Protected backbone per ARCHITECTURE_RULES.md.
//
// An ActionSchema describes what an action requires and
// what effects it produces. The planner queries the
// ActionSchemaLibrary to find applicable actions given
// the current world state, and to predict what state
// will result after execution.
//
// This is the bridge between symbolic planning
// (precondition/postcondition reasoning) and the
// neural planner (LLM-driven action selection).
// ─────────────────────────────────────────────────────────

/// A condition that can be checked against a WorldModelSnapshot.
public enum SchemaCondition: Equatable {
    case elementExists(role: String)
    case appFrontmost(name: String)
    case windowTitleContains(substring: String)
    case urlContains(substring: String)
    case valueEquals(field: String, value: String)
    case buildSucceeded
    case gitClean
    case noFailingTests
    case custom(label: String)

    /// Evaluate this condition against a world snapshot.
    public func evaluate(against snapshot: WorldModelSnapshot) -> Bool {
        switch self {
        case .elementExists:
            // Cannot evaluate without element list — always true at schema level
            return true
        case .appFrontmost(let name):
            return snapshot.activeApplication?.lowercased() == name.lowercased()
        case .windowTitleContains(let sub):
            return snapshot.windowTitle?.contains(sub) ?? false
        case .urlContains(let sub):
            return snapshot.url?.contains(sub) ?? false
        case .valueEquals(let field, let value):
            // Map well-known fields
            switch field {
            case "app":
                return snapshot.activeApplication == value
            case "branch":
                return snapshot.activeBranch == value
            default:
                return false
            }
        case .buildSucceeded:
            return snapshot.buildSucceeded
        case .gitClean:
            return !snapshot.isGitDirty
        case .noFailingTests:
            return snapshot.failingTestCount == 0
        case .custom:
            // Custom conditions must be checked externally
            return true
        }
    }
}

/// The kind of an action schema.
public enum ActionSchemaKind: String, CaseIterable {
    case click
    case typeText
    case openApplication
    case openURL
    case runCommand
    case runTests
    case buildProject
    case applyPatch
    case gitCheckout
    case gitCommit
    case search
    case navigate
    case custom
}

/// A schema describing an action's requirements and effects.
public struct ActionSchema {

    public let kind: ActionSchemaKind
    public let domain: ActionDomain
    public let name: String
    public let description: String
    public let preconditions: [SchemaCondition]
    public let postconditions: [SchemaCondition]
    public let parameterNames: [String]

    public init(
        kind: ActionSchemaKind,
        domain: ActionDomain,
        name: String,
        description: String = "",
        preconditions: [SchemaCondition] = [],
        postconditions: [SchemaCondition] = [],
        parameterNames: [String] = []
    ) {
        self.kind = kind
        self.domain = domain
        self.name = name
        self.description = description
        self.preconditions = preconditions
        self.postconditions = postconditions
        self.parameterNames = parameterNames
    }

    /// Check whether all preconditions hold against the world state.
    public func preconditionsMet(snapshot: WorldModelSnapshot) -> Bool {
        preconditions.allSatisfy { $0.evaluate(against: snapshot) }
    }

    /// Compact summary for logging.
    public var summary: String {
        "\(kind.rawValue) (\(domain.rawValue)) pre=\(preconditions.count) post=\(postconditions.count)"
    }
}

/// Library of well-known action schemas.
public final class ActionSchemaLibrary {

    private var schemas: [ActionSchemaKind: ActionSchema] = [:]
    private var customSchemas: [String: ActionSchema] = [:]

    public init() {
        registerDefaults()
    }

    // ── Registration ────────────────────────────────────

    public func register(_ schema: ActionSchema) {
        if schema.kind == .custom {
            customSchemas[schema.name] = schema
        } else {
            schemas[schema.kind] = schema
        }
    }

    // ── Query ───────────────────────────────────────────

    /// Get schema by kind.
    public func schema(for kind: ActionSchemaKind) -> ActionSchema? {
        schemas[kind]
    }

    /// Get custom schema by name.
    public func customSchema(named name: String) -> ActionSchema? {
        customSchemas[name]
    }

    /// All schemas whose preconditions are satisfied.
    public func applicableSchemas(given snapshot: WorldModelSnapshot) -> [ActionSchema] {
        let builtIn = schemas.values.filter { $0.preconditionsMet(snapshot: snapshot) }
        let custom = customSchemas.values.filter { $0.preconditionsMet(snapshot: snapshot) }
        return builtIn + custom
    }

    /// All registered schemas.
    public var allSchemas: [ActionSchema] {
        Array(schemas.values) + Array(customSchemas.values)
    }

    /// Number of registered schemas.
    public var count: Int { schemas.count + customSchemas.count }

    // ── Default schemas ─────────────────────────────────

    private func registerDefaults() {
        register(ActionSchema(
            kind: .click,
            domain: .host,
            name: "click",
            description: "Click a UI element by role and label",
            preconditions: [.elementExists(role: "button")],
            postconditions: [],
            parameterNames: ["elementID"]
        ))

        register(ActionSchema(
            kind: .typeText,
            domain: .host,
            name: "typeText",
            description: "Type text into the focused field",
            preconditions: [.elementExists(role: "textfield")],
            postconditions: [],
            parameterNames: ["text"]
        ))

        register(ActionSchema(
            kind: .openApplication,
            domain: .host,
            name: "openApplication",
            description: "Launch or bring an application to front",
            preconditions: [],
            postconditions: [],
            parameterNames: ["appName"]
        ))

        register(ActionSchema(
            kind: .openURL,
            domain: .browser,
            name: "openURL",
            description: "Navigate browser to a URL",
            preconditions: [],
            postconditions: [],
            parameterNames: ["url"]
        ))

        register(ActionSchema(
            kind: .runCommand,
            domain: .tool,
            name: "runCommand",
            description: "Run a shell command",
            preconditions: [],
            postconditions: [],
            parameterNames: ["command"]
        ))

        register(ActionSchema(
            kind: .runTests,
            domain: .code,
            name: "runTests",
            description: "Run the test suite",
            preconditions: [.buildSucceeded],
            postconditions: [],
            parameterNames: []
        ))

        register(ActionSchema(
            kind: .buildProject,
            domain: .code,
            name: "buildProject",
            description: "Build the project",
            preconditions: [],
            postconditions: [.buildSucceeded],
            parameterNames: []
        ))

        register(ActionSchema(
            kind: .applyPatch,
            domain: .code,
            name: "applyPatch",
            description: "Apply a code patch to a file",
            preconditions: [],
            postconditions: [],
            parameterNames: ["filePath", "patch"]
        ))

        register(ActionSchema(
            kind: .gitCheckout,
            domain: .tool,
            name: "gitCheckout",
            description: "Checkout a git branch",
            preconditions: [.gitClean],
            postconditions: [],
            parameterNames: ["branch"]
        ))

        register(ActionSchema(
            kind: .gitCommit,
            domain: .tool,
            name: "gitCommit",
            description: "Commit staged changes",
            preconditions: [],
            postconditions: [.gitClean],
            parameterNames: ["message"]
        ))

        register(ActionSchema(
            kind: .search,
            domain: .search,
            name: "search",
            description: "Search the web or codebase",
            preconditions: [],
            postconditions: [],
            parameterNames: ["query"]
        ))

        register(ActionSchema(
            kind: .navigate,
            domain: .browser,
            name: "navigate",
            description: "Navigate within the current page",
            preconditions: [],
            postconditions: [],
            parameterNames: ["target"]
        ))
    }
}
