import Foundation

public struct VerifiedProcessResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let durationMs: Double

    public var combinedOutput: String {
        [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: stderr.isEmpty || stdout.isEmpty ? "" : "\n")
    }
}

public final class VerifiedExecutor: @unchecked Sendable {
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

    private func runShell(_ command: Command) throws -> [any DomainEvent] {
        guard let cmd = command.payload["cmd"], !cmd.isEmpty else {
            throw RuntimeError.invalidPayload
        }

        let result = try Self.runSubprocess(
            executable: "/bin/bash",
            arguments: ["-c", cmd],
            environment: Self.sanitizedEnvironment(removing: ["CLAUDE_CODE", "CLAUDECODE"])
        )

        return [
            ShellExecutedEvent(
                command: cmd,
                output: result.combinedOutput,
                status: result.exitCode
            )
        ]
    }

    private func writeFile(_ command: Command) throws -> [any DomainEvent] {
        guard let path = command.payload["path"],
              let content = command.payload["content"]
        else {
            throw RuntimeError.invalidPayload
        }

        return [FileWriteRequestedEvent(path: path, content: content)]
    }

    private func deleteFile(_ command: Command) throws -> [any DomainEvent] {
        guard let path = command.payload["path"], !path.isEmpty else {
            throw RuntimeError.invalidPayload
        }

        return [FileDeleteRequestedEvent(path: path)]
    }

    private func httpRequest(_ command: Command) throws -> [any DomainEvent] {
        guard let urlString = command.payload["url"],
              let url = URL(string: urlString)
        else {
            throw RuntimeError.invalidPayload
        }

        var request = URLRequest(url: url)
        request.httpMethod = command.payload["method"] ?? "GET"
        if let body = command.payload["body"] {
            request.httpBody = Data(body.utf8)
        }

        let data = try Self.performRequest(request)
        return [HTTPResponseEvent(url: urlString, size: data.count)]
    }

    public static func runSubprocess(
        executable: String,
        arguments: [String] = [],
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil,
        standardInput: Any? = nil,
        standardOutput: Any? = nil,
        standardError: Any? = nil
    ) throws -> VerifiedProcessResult {
        let start = Date()
        let stdoutPipe = standardOutput as? Pipe ?? Pipe()
        let stderrPipe = standardError as? Pipe ?? Pipe()

        let process = try spawnSubprocess(
            executable: executable,
            arguments: arguments,
            currentDirectoryURL: currentDirectoryURL,
            environment: environment,
            standardInput: standardInput,
            standardOutput: standardOutput ?? stdoutPipe,
            standardError: standardError ?? stderrPipe
        )

        process.waitUntilExit()

        let stdoutData = (standardOutput == nil) ? stdoutPipe.fileHandleForReading.readDataToEndOfFile() : Data()
        let stderrData = (standardError == nil) ? stderrPipe.fileHandleForReading.readDataToEndOfFile() : Data()

        return VerifiedProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            durationMs: Date().timeIntervalSince(start) * 1000.0
        )
    }

    @discardableResult
    public static func spawnSubprocess(
        executable: String,
        arguments: [String] = [],
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil,
        standardInput: Any? = nil,
        standardOutput: Any? = nil,
        standardError: Any? = nil
    ) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        if let environment {
            process.environment = environment
        }
        if let standardInput {
            process.standardInput = standardInput
        }
        if let standardOutput {
            process.standardOutput = standardOutput
        }
        if let standardError {
            process.standardError = standardError
        }
        try process.run()
        return process
    }

    public static func performRequest(_ request: URLRequest) throws -> Data {
        let box = ResponseBox<Data>()
        let semaphore = DispatchSemaphore(value: 0)
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { data, _, error in
            box.value = data
            box.error = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        session.finishTasksAndInvalidate()

        if let error = box.error {
            throw error
        }

        return box.value ?? Data()
    }

    public static func performJSONRequest(_ request: URLRequest) throws -> Any {
        let data = try performRequest(request)
        return try JSONSerialization.jsonObject(with: data)
    }

    public static func receiveWebSocketText(
        url: URL,
        sending message: String,
        timeout: TimeInterval
    ) throws -> String {
        let box = ResponseBox<String>()
        let semaphore = DispatchSemaphore(value: 0)
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        task.resume()

        task.send(.string(message)) { error in
            if let error {
                box.error = error
                semaphore.signal()
                return
            }

            task.receive { result in
                switch result {
                case .success(let payload):
                    switch payload {
                    case .string(let text):
                        box.value = text
                    case .data(let data):
                        box.value = String(data: data, encoding: .utf8)
                    @unknown default:
                        break
                    }
                case .failure(let error):
                    box.error = error
                }
                semaphore.signal()
            }
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)
        task.cancel(with: .goingAway, reason: nil)
        session.finishTasksAndInvalidate()

        if waitResult == .timedOut {
            throw OracleError.timeout(seconds: timeout)
        }
        if let error = box.error {
            throw error
        }
        return box.value ?? ""
    }

    public static func sanitizedEnvironment(removing keysToRemove: Set<String> = []) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        for key in keysToRemove {
            environment.removeValue(forKey: key)
        }
        return environment
    }
}

private final class ResponseBox<Value>: @unchecked Sendable {
    var value: Value?
    var error: (any Error)?
}
