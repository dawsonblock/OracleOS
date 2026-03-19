import Foundation
import AppKit

// ─────────────────────────────────────────────────────────
// ApplicationController — manage macOS apps via NSWorkspace + AX
//
// Read path:  NSWorkspace queries → data returned to planner
// Write path: actions flow through VerifiedActionExecutor
// ─────────────────────────────────────────────────────────

public final class ApplicationController {

    private let observation: AccessibilitySnapshotService

    public init(observation: AccessibilitySnapshotService = AccessibilitySnapshotService()) {
        self.observation = observation
    }

    public func launch(bundleID: String) -> ExecutionResult {
        print("[app-ctrl] Launching: \(bundleID)")
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return ExecutionResult(success: false, detail: "app not found: \(bundleID)", actionID: UUID().uuidString)
        }
        let config = NSWorkspace.OpenConfiguration()
        let semaphore = DispatchSemaphore(value: 0)
        var launchSuccess = false
        var launchError: String = ""

        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
            if let error = error {
                launchError = error.localizedDescription
            } else {
                launchSuccess = true
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 10)

        return ExecutionResult(
            success: launchSuccess,
            detail: launchSuccess ? "launched \(bundleID)" : "launch failed: \(launchError)",
            actionID: UUID().uuidString
        )
    }

    public func activate(bundleID: String) -> ExecutionResult {
        print("[app-ctrl] Activating: \(bundleID)")
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return ExecutionResult(success: false, detail: "app not running: \(bundleID)", actionID: UUID().uuidString)
        }
        let ok = app.activate()
        return ExecutionResult(
            success: ok,
            detail: ok ? "activated \(bundleID)" : "activate failed",
            actionID: UUID().uuidString
        )
    }

    public func quit(bundleID: String) -> ExecutionResult {
        print("[app-ctrl] Quitting: \(bundleID)")
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return ExecutionResult(success: false, detail: "app not running: \(bundleID)", actionID: UUID().uuidString)
        }
        let ok = app.terminate()
        return ExecutionResult(
            success: ok,
            detail: ok ? "quit \(bundleID)" : "quit failed",
            actionID: UUID().uuidString
        )
    }

    public func runningApps() -> [String] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
    }

    public func frontmostApp() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }

    public static func register(in registry: ActionRegistry) {
        let ctrl = ApplicationController()

        registry.register("app_launch") { action in
            return ctrl.launch(bundleID: action.parameters["bundle_id"] ?? "")
        }
        registry.register("app_activate") { action in
            return ctrl.activate(bundleID: action.parameters["bundle_id"] ?? "")
        }
        registry.register("app_quit") { action in
            return ctrl.quit(bundleID: action.parameters["bundle_id"] ?? "")
        }
    }
}
