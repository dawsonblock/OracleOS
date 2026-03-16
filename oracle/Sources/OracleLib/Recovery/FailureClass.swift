import Foundation

// ─────────────────────────────────────────────────────────
// FailureClass — discrete failure taxonomy for the oracle
//
// Every critic-detected failure is classified into one of
// these 20 failure domains before recovery selection.
// ─────────────────────────────────────────────────────────

/// Discrete classification of a recoverable failure.
///
/// Used by `FailureClassifier` to categorise error descriptions
/// and by `RecoveryStrategyLibrary` to look up applicable strategies.
public enum FailureClass: String, Codable, CaseIterable, Equatable, Sendable {

    // ── UI / element failures ────────────────────────────

    /// A targeted UI element could not be found in the current observation.
    case elementNotFound

    /// Multiple elements match the target description — selection is ambiguous.
    case elementAmbiguous

    /// The keyboard / pointer focus is on the wrong window or panel.
    case wrongFocus

    /// An action was dispatched but the execution layer reported failure.
    case actionFailed

    /// Navigation to a URL or screen failed.
    case navigationFailed

    /// A modal dialog or sheet is blocking the target element.
    case modalBlocking

    /// The critic evaluated the result as not matching the expected post-state.
    case verificationFailed

    /// The observation snapshot is too old to trust for element targeting.
    case staleObservation

    // ── Code / repo failures ─────────────────────────────

    /// The build command exited non-zero.
    case buildFailed

    /// One or more unit or integration tests failed.
    case testFailed

    /// A patch could not be applied cleanly to the source tree.
    case patchApplyFailed

    // ── Workspace policy failures ────────────────────────

    /// An action would cross workspace sandbox boundaries.
    case workspaceScopeViolation

    /// A git policy guard (branch protection, commit signing) blocked the action.
    case gitPolicyBlocked

    /// No relevant source files could be located for the current task.
    case noRelevantFiles

    /// The edit target file or symbol is ambiguous.
    case ambiguousEditTarget

    /// The expected target (file, element, branch) is missing.
    case targetMissing

    // ── System / environment failures ────────────────────

    /// An OS permission was denied (accessibility, file, network, etc.).
    case permissionBlocked

    /// An unexpected system dialog interrupted task execution.
    case unexpectedDialog

    /// The runtime environment does not match requirements (SDK, tool version).
    case environmentMismatch

    // ── Workflow / replay failures ────────────────────────

    /// A promoted workflow plan failed to replay successfully.
    case workflowReplayFailure
}
