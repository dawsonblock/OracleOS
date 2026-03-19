import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class VerifiedExecutor: Sendable {
    private let policy: PolicyEngine

    public init(policy: PolicyEngine) {
        self.policy = policy
    }

    public func execute(_ command: Command) throws -> [any DomainEvent] {
        try policy.validate(command)

        switch command.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "shell":
            return try runShell(command)
        case "file.write":
            return try writeFile(command)
        case "file.delete":
            return try deleteFile(command)
        case "http.request":
            return try performRequest(command)
        default:
            throw RuntimeError.unknownCommand
        }
    }

    public static func appendData(_ data: Data, to url: URL) throws {
        try ensureParentDirectory(for: url)

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    public static func writeText(_ text: String, to url: URL) throws {
        try ensureParentDirectory(for: url)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public static func deleteItem(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try FileManager.default.removeItem(at: url)
    }

    private static func ensureParentDirectory(for url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func runShell(_ command: Command) throws -> [any DomainEvent] {
        let shellCommand = command.stringValue(for: "cmd") ?? ""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", shellCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        let deadline = Date().addingTimeInterval(policy.policy.maxExecutionTime)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw RuntimeError.timeout
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let trimmed = data.prefix(policy.policy.maxOutputBytes)
        let output = String(data: trimmed, encoding: .utf8) ?? ""

        return [
            ShellExecutedEvent(
                commandID: command.id,
                command: shellCommand,
                output: output,
                status: process.terminationStatus
            ),
        ]
    }

    private func writeFile(_ command: Command) throws -> [any DomainEvent] {
        let path = command.stringValue(for: "path") ?? ""
        let content = command.stringValue(for: "content") ?? ""
        let url = resolveURL(for: path)

        try Self.writeText(content, to: url)

        return [
            FileWriteEvent(
                commandID: command.id,
                path: path,
                content: content
            ),
        ]
    }

    private func deleteFile(_ command: Command) throws -> [any DomainEvent] {
        let path = command.stringValue(for: "path") ?? ""
        let url = resolveURL(for: path)

        try Self.deleteItem(at: url)

        return [
            FileDeleteEvent(
                commandID: command.id,
                path: path
            ),
        ]
    }

    private func performRequest(_ command: Command) throws -> [any DomainEvent] {
        let urlString = command.stringValue(for: "url") ?? ""
        guard let url = URL(string: urlString) else {
            throw RuntimeError.invalidURL
        }

        let box = ResponseBox()
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            box.data = data
            box.error = error
            semaphore.signal()
        }

        task.resume()
        let timeout = DispatchTime.now() + .milliseconds(Int(policy.policy.maxExecutionTime * 1000))
        if semaphore.wait(timeout: timeout) == .timedOut {
            task.cancel()
            throw RuntimeError.timeout
        }

        if let error = box.error {
            throw error
        }

        let trimmed = box.data?.prefix(policy.policy.maxOutputBytes) ?? Data()
        let output = String(data: trimmed, encoding: .utf8) ?? ""

        return [
            HTTPResponseEvent(
                commandID: command.id,
                url: urlString,
                body: output
            ),
        ]
    }

    private func resolveURL(for path: String) -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed, isDirectory: false).standardizedFileURL
        }

        return URL(fileURLWithPath: trimmed, relativeTo: URL(fileURLWithPath: ".", isDirectory: true))
            .standardizedFileURL
    }
}

private final class ResponseBox: @unchecked Sendable {
    var data: Data?
    var error: Error?
}
