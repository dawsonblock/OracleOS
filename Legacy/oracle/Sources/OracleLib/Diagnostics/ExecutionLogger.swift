import Foundation

// ─────────────────────────────────────────────────────────
// ExecutionLogger — structured log output (Phase 18)
//
// Writes to logs/oracle.log with timestamp, level, message.
// ─────────────────────────────────────────────────────────

public final class ExecutionLogger {

    public enum Level: String {
        case debug   = "DEBUG"
        case info    = "INFO"
        case warn    = "WARN"
        case error   = "ERROR"
    }

    private let logDir: String
    private let fileManager = FileManager.default

    public init(logDir: String = "logs") {
        self.logDir = logDir
        try? fileManager.createDirectory(atPath: logDir, withIntermediateDirectories: true)
    }

    public func log(_ message: String, level: Level = .info) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] [\(level.rawValue)] \(message)\n"

        print(line, terminator: "")

        let path = "\(logDir)/oracle.log"
        if let data = line.data(using: .utf8) {
            if fileManager.fileExists(atPath: path) {
                if let handle = FileHandle(forWritingAtPath: path) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                fileManager.createFile(atPath: path, contents: data)
            }
        }
    }
}
