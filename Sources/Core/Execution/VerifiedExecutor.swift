import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct VerifiedProcessResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var combinedOutput: String {
        [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: stdout.isEmpty || stderr.isEmpty ? "" : "\n")
    }

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public final class VerifiedExecutor: Sendable {
    private let policy: PolicyEngine

    public init(policy: PolicyEngine = PolicyEngine()) {
        self.policy = policy
    }

    public func execute(_ command: Command) throws -> [any DomainEvent] {
        try policy.validate(command)

        switch command.type {
        case "shell":
            return try runShell(command)
        case "file.write":
            return try writeFile(command)
        case "file.delete":
            return try deleteFile(command)
        case "http.request":
            return try httpRequest(command)
        default:
            throw RuntimeError.unknownCommand(command.type)
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

    private static func resolvedURL(for path: String) -> URL {
        let rawURL = URL(fileURLWithPath: path)
        if rawURL.path.hasPrefix("/") {
            return rawURL
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return cwd.appendingPathComponent(path, isDirectory: false)
    }

    private func runShell(_ command: Command) throws -> [any DomainEvent] {
        let task = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let shellCommand = command.payload["cmd"] ?? ""

        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", shellCommand]
        task.standardOutput = stdout
        task.standardError = stderr

        try task.run()
        task.waitUntilExit()

        let stdoutText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return [
            ShellExecutedEvent(
                commandID: command.id,
                command: shellCommand,
                output: VerifiedProcessResult(
                    exitCode: task.terminationStatus,
                    stdout: stdoutText,
                    stderr: stderrText
                ).combinedOutput,
                status: task.terminationStatus
            ),
        ]
    }

    private func writeFile(_ command: Command) throws -> [any DomainEvent] {
        let path = command.payload["path"] ?? ""
        let content = command.payload["content"] ?? ""
        let url = Self.resolvedURL(for: path)

        try Self.writeText(content, to: url)

        return [
            FileWriteRequestedEvent(
                commandID: command.id,
                path: path,
                content: content
            ),
        ]
    }

    private func deleteFile(_ command: Command) throws -> [any DomainEvent] {
        let path = command.payload["path"] ?? ""
        let url = Self.resolvedURL(for: path)

        try Self.deleteItem(at: url)

        return [
            FileDeleteRequestedEvent(
                commandID: command.id,
                path: path
            ),
        ]
    }

    private func httpRequest(_ command: Command) throws -> [any DomainEvent] {
        let urlString = command.payload["url"] ?? ""
        guard let url = URL(string: urlString) else {
            throw RuntimeError.invalidPayload
        }

        var request = URLRequest(url: url)
        request.httpMethod = command.payload["method"] ?? "GET"
        if let body = command.payload["body"] {
            request.httpBody = Data(body.utf8)
        }

        let box = ResponseBox()
        let semaphore = DispatchSemaphore(value: 0)
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { data, response, error in
            box.data = data
            box.response = response as? HTTPURLResponse
            box.error = error
            semaphore.signal()
        }

        task.resume()
        semaphore.wait()
        session.finishTasksAndInvalidate()

        if let error = box.error {
            throw error
        }

        let size = box.data?.count ?? 0
        let status = box.response?.statusCode ?? 0

        return [
            HTTPResponseEvent(
                commandID: command.id,
                url: urlString,
                size: size,
                status: status
            ),
        ]
    }
}

private final class ResponseBox: @unchecked Sendable {
    var data: Data?
    var response: HTTPURLResponse?
    var error: Error?
}
