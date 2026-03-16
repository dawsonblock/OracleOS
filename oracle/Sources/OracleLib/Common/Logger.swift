import Foundation

public enum LogLevel: Int, Sendable, Comparable {
    case debug = 0
    case info = 1
    case warn = 2
    case error = 3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warn: return "WARN"
        case .error: return "ERROR"
        }
    }
}

public enum Log {
    private static let levelLock = NSLock()
    nonisolated(unsafe) private static var storedMinimumLevel: LogLevel = .info

    public static var minimumLevel: LogLevel {
        get {
            levelLock.lock()
            defer { levelLock.unlock() }
            return storedMinimumLevel
        }
        set {
            levelLock.lock()
            defer { levelLock.unlock() }
            storedMinimumLevel = newValue
        }
    }

    public static func debug(_ message: @autoclosure () -> String) { log(.debug, message()) }
    public static func info(_ message: @autoclosure () -> String) { log(.info, message()) }
    public static func warn(_ message: @autoclosure () -> String) { log(.warn, message()) }
    public static func error(_ message: @autoclosure () -> String) { log(.error, message()) }

    private static func log(_ level: LogLevel, _ message: String) {
        guard level >= minimumLevel else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [\(level.label)] \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
