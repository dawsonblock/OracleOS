import Foundation

/// Policy engine for enforcing deterministic execution and security 
/// across node boundaries (Phase 18).
public final class GovernanceEngine: Sendable {
    private let validator: CommandValidator
    private let lockManager: DistributedLockManager
    
    public init(
        validator: CommandValidator = CommandValidator(),
        lockManager: DistributedLockManager = DistributedLockManager()
    ) {
        self.validator = validator
        self.lockManager = lockManager
    }

    /// Evaluates whether a proposed command can be safely executed on the cluster.
    public func enforce(command: ActionCommand) async throws -> GovernanceResult {
        // 1. Structural Validation
        let validation = validator.validate(command)
        if case .invalid(let reason, _) = validation {
            return .violated(reason: "Structural validation failed: \(reason)")
        }

        // 2. Resource Exclusivity (Phase 13 logic)
        // Ensure no other node is operating on the target app
        let maybeLockId = try await lockManager.acquire(resource: command.intent.app)
        guard let lockId = maybeLockId else {
            return .denied(reason: "Failed to acquire execution lock for app \(command.intent.app)")
        }
        defer {
            Task {
                try? await lockManager.release(lockId: lockId)
            }
        }
        
        // 3. (Phase 21-25 logic) Check safety policies
        return .approved
    }
}

public enum GovernanceResult: Sendable {
    case approved
    case violated(reason: String)
    case denied(reason: String)
}
