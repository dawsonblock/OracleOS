# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **SelectedStrategy Dependency**: The `Planner.nextStep` and related logic now strictly require a `SelectedStrategy` instance to be injected, making execution strategies explicitly declared rather than inferred or defaulted contextually.
- **Strict Concurrency in VerifiedActionExecutor**: Imposed strict `@MainActor` rules to ensure that executor logic (like `VerifiedActionExecutor.run`) is called in an explicit `async` / `await` scope, resolving potential Swift 6 race conditions in task boundaries.

### Changed
- **Observation and PlanningState Mocks**: Test suites and world state mock instantiation now uniformly map against structured identifiers such as `StateClusterKey` and discrete IDs `focusedElementID`, moving past outdated primitive string parameterization.
- **Test Suite Resiliency**: Numerous structural overrides added to tests across `Core/WorldModelAgentLoopWiringTests`, `Planning/UpgradePhaseTests`, `Core/GraphAwareLoopTests`, `Core/DigitalEngineerLayerTests` and others to restore compilation against the new schema contracts.

### Removed
- Removed generic fallback initializers that obscured complex architectural changes from legacy modules.
