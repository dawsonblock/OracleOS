import Foundation

// ─────────────────────────────────────────────────────────
// RecipeTypes — core data model for the recipe system
//
// Recipes are human-authored, JSON-serialisable task scripts.
// They consist of:
//   • A metadata header (name, description, schema version)
//   • Optional typed parameter declarations
//   • An ordered list of steps, each mapping to an action type
//   • Optional preconditions and per-step failure policies
//
// Runtime execution is handled by RecipeEngine; storage by
// RecipeStore.
// ─────────────────────────────────────────────────────────

// MARK: – Recipe

/// A named, serialisable task script.
public struct Recipe: Codable, Equatable {

    /// Semver integer for schema evolution.
    public let schemaVersion: Int

    /// Unique human-readable identifier (used as the store key).
    public let name: String

    /// One-sentence description for display and selection.
    public let description: String

    /// Target application name (hint for precondition checks and focus).
    public let app: String?

    /// Declared input parameters.
    public let params: [String: RecipeParam]?

    /// Optional preconditions that must hold before execution begins.
    public let preconditions: RecipePreconditions?

    /// Ordered steps to execute.
    public let steps: [RecipeStep]

    /// Default failure policy: `"stop"` (default) or `"skip"`.
    public let onFailure: String?

    public init(
        schemaVersion: Int = 2,
        name: String,
        description: String,
        app: String? = nil,
        params: [String: RecipeParam]? = nil,
        preconditions: RecipePreconditions? = nil,
        steps: [RecipeStep],
        onFailure: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.description = description
        self.app = app
        self.params = params
        self.preconditions = preconditions
        self.steps = steps
        self.onFailure = onFailure
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case name, description, app, params, preconditions, steps
        case onFailure = "on_failure"
    }
}

// MARK: – RecipeParam

/// A declared recipe parameter.
public struct RecipeParam: Codable, Equatable {

    /// Data type hint (`"string"`, `"integer"`, `"boolean"`).
    public let type: String

    /// Human-readable description of this parameter.
    public let description: String

    /// Whether this parameter must be supplied at run time.
    public let required: Bool?

    public init(type: String, description: String, required: Bool? = nil) {
        self.type = type
        self.description = description
        self.required = required
    }
}

// MARK: – RecipePreconditions

/// Conditions that must hold before a recipe starts.
public struct RecipePreconditions: Codable, Equatable {

    /// The named application must be running.
    public let appRunning: String?

    /// The active URL must contain this substring.
    public let urlContains: String?

    public init(appRunning: String? = nil, urlContains: String? = nil) {
        self.appRunning = appRunning
        self.urlContains = urlContains
    }

    enum CodingKeys: String, CodingKey {
        case appRunning = "app_running"
        case urlContains = "url_contains"
    }
}

// MARK: – RecipeStep

/// A single step in a recipe.
public struct RecipeStep: Codable, Equatable {

    /// 1-based step index (for result correlation and error messages).
    public let id: Int

    /// Action type string dispatched to the action registry.
    public let action: String

    /// Optional target element name hint.
    public let targetName: String?

    /// Named string parameters passed to the action.
    public let params: [String: String]?

    /// Optional condition to wait for after the step succeeds.
    public let waitAfter: RecipeWaitCondition?

    /// Free-text annotation shown in run logs.
    public let note: String?

    /// Per-step failure policy override (`"stop"` or `"skip"`).
    public let onFailure: String?

    public init(
        id: Int,
        action: String,
        targetName: String? = nil,
        params: [String: String]? = nil,
        waitAfter: RecipeWaitCondition? = nil,
        note: String? = nil,
        onFailure: String? = nil
    ) {
        self.id = id
        self.action = action
        self.targetName = targetName
        self.params = params
        self.waitAfter = waitAfter
        self.note = note
        self.onFailure = onFailure
    }

    enum CodingKeys: String, CodingKey {
        case id, action
        case targetName = "target_name"
        case params
        case waitAfter = "wait_after"
        case note
        case onFailure = "on_failure"
    }
}

// MARK: – RecipeWaitCondition

/// A post-step wait condition.
public struct RecipeWaitCondition: Codable, Equatable {

    /// Condition type: `"delay"`, `"elementExists"`, `"urlContains"`, etc.
    public let condition: String

    /// Optional value to match against.
    public let value: String?

    /// Maximum wait duration in seconds (default: 10).
    public let timeout: Double?

    public init(condition: String, value: String? = nil, timeout: Double? = nil) {
        self.condition = condition
        self.value = value
        self.timeout = timeout
    }
}

// MARK: – RecipeRunResult

/// The result of executing an entire recipe.
public struct RecipeRunResult: Equatable {

    public let recipeName: String
    public let success: Bool
    public let stepsCompleted: Int
    public let totalSteps: Int
    public let stepResults: [RecipeStepResult]

    /// Non-nil when execution stopped due to a fatal error.
    public let error: String?

    public init(
        recipeName: String,
        success: Bool,
        stepsCompleted: Int,
        totalSteps: Int,
        stepResults: [RecipeStepResult],
        error: String? = nil
    ) {
        self.recipeName = recipeName
        self.success = success
        self.stepsCompleted = stepsCompleted
        self.totalSteps = totalSteps
        self.stepResults = stepResults
        self.error = error
    }
}

// MARK: – RecipeStepResult

/// The result of executing a single recipe step.
public struct RecipeStepResult: Equatable {

    public let stepId: Int
    public let action: String
    public let success: Bool
    public let durationMs: Int
    public let error: String?
    public let note: String?

    public init(
        stepId: Int,
        action: String,
        success: Bool,
        durationMs: Int = 0,
        error: String? = nil,
        note: String? = nil
    ) {
        self.stepId = stepId
        self.action = action
        self.success = success
        self.durationMs = durationMs
        self.error = error
        self.note = note
    }
}
