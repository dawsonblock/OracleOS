import Foundation

public struct MonitoredApp {
    public let pid: Int
    public let name: String
    
    public init(pid: Int, name: String) {
        self.pid = pid
        self.name = name
    }
}

public final class ApplicationScanner {
    public init() {}
    
    public func scanRunningApps() -> [MonitoredApp] {
        return []
    }
}
