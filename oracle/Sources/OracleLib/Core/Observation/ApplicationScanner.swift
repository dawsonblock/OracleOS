import Foundation
import AppKit

public struct MonitoredApp: Equatable {
    public let pid: Int
    public let name: String
    public let bundleIdentifier: String?
    
    public init(pid: Int, name: String, bundleIdentifier: String?) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public final class ApplicationScanner {
    public init() {}
    
    /// Scans for currently running Mac applications using `NSWorkspace`.
    public func scanRunningApps() -> [MonitoredApp] {
        let apps = NSWorkspace.shared.runningApplications
        return apps.compactMap { app in
            // Only capture standard user-facing apps with a UI presence
            guard let name = app.localizedName, app.activationPolicy == .regular else {
                return nil
            }
            return MonitoredApp(
                pid: Int(app.processIdentifier), 
                name: name,
                bundleIdentifier: app.bundleIdentifier
            )
        }
    }
}
