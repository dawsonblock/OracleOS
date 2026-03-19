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
        if policy.policy.useMicroVM {
            return try runShellMicroVM(commandID: command.id, shellCommand: shellCommand)
        }
        if policy.policy.useContainers {
            return try runShellContainer(commandID: command.id, shellCommand: shellCommand)
        }

        return try runShellHost(commandID: command.id, shellCommand: shellCommand)
    }

    private func runShellHost(commandID: UUID, shellCommand: String) throws -> [any DomainEvent] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", shellCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        try waitForShellExit(process, cleanupOnTimeout: nil)

        let output = trimmedOutput(from: pipe)

        return [
            ShellExecutedEvent(
                commandID: commandID,
                command: shellCommand,
                output: output,
                status: process.terminationStatus
            ),
        ]
    }

    private func runShellContainer(commandID: UUID, shellCommand: String) throws -> [any DomainEvent] {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/docker") else {
            throw RuntimeError.serverFailure("Container runtime unavailable: /usr/bin/docker")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/docker")

        let cidFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("oracle-executor-\(UUID().uuidString).cid")
        let workspaceRoot = workspaceRootPath()
        process.arguments = [
            "run",
            "--rm",
            "--cidfile", cidFileURL.path,
            "--network", "none",
            "--memory", "128m",
            "--cpus", "0.5",
            "--pids-limit", "64",
            "-v", "\(workspaceRoot):/workspace",
            "--workdir", "/workspace",
            "--read-only",
            "--tmpfs", "/tmp:rw,noexec,nosuid,size=16m",
            "--cap-drop=ALL",
        ]

        if let seccompProfilePath = policy.policy.seccompProfilePath {
            let normalizedPath = URL(fileURLWithPath: seccompProfilePath).standardizedFileURL.path
            guard FileManager.default.fileExists(atPath: normalizedPath) else {
                throw RuntimeError.serverFailure("Seccomp profile missing: \(normalizedPath)")
            }
            process.arguments?.append(contentsOf: [
                "--security-opt", "seccomp=\(normalizedPath)",
            ])
        }

        process.arguments?.append(contentsOf: [
            policy.policy.containerImage,
            shellCommand,
        ])

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        defer {
            try? FileManager.default.removeItem(at: cidFileURL)
        }

        try waitForShellExit(
            process,
            cleanupOnTimeout: { [cidFileURL] in
                cleanupContainerIfNeeded(cidFileURL: cidFileURL)
            }
        )

        let output = trimmedOutput(from: pipe)

        return [
            ShellExecutedEvent(
                commandID: commandID,
                command: shellCommand,
                output: output,
                status: process.terminationStatus
            ),
        ]
    }

    private func runShellMicroVM(commandID: UUID, shellCommand: String) throws -> [any DomainEvent] {
        let firecrackerBinaryPath = URL(fileURLWithPath: policy.policy.firecrackerBinaryPath).standardizedFileURL.path
        guard FileManager.default.isExecutableFile(atPath: firecrackerBinaryPath) else {
            throw RuntimeError.serverFailure("MicroVM runtime unavailable: \(firecrackerBinaryPath)")
        }

        let kernelPath = URL(fileURLWithPath: policy.policy.microVMKernelPath).standardizedFileURL.path
        let rootfsPath = URL(fileURLWithPath: policy.policy.microVMRootfsPath).standardizedFileURL.path

        guard FileManager.default.fileExists(atPath: kernelPath) else {
            throw RuntimeError.serverFailure("MicroVM kernel missing: \(kernelPath)")
        }
        guard FileManager.default.fileExists(atPath: rootfsPath) else {
            throw RuntimeError.serverFailure("MicroVM rootfs missing: \(rootfsPath)")
        }

        let workspaceImagePath = policy.policy.microVMWorkspaceImagePath.map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        }
        if let workspaceImagePath,
           !FileManager.default.fileExists(atPath: workspaceImagePath) {
            throw RuntimeError.serverFailure("MicroVM workspace image missing: \(workspaceImagePath)")
        }

        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("oracle-microvm-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        defer {
            try? FileManager.default.removeItem(at: workingDirectory)
        }

        let socketPath = workingDirectory.appendingPathComponent("firecracker.sock").path
        let configURL = workingDirectory.appendingPathComponent("firecracker-config.json")
        let runner = MicroVMRunner(
            configuration: MicroVMConfiguration(
                firecrackerBinaryPath: firecrackerBinaryPath,
                kernelImagePath: kernelPath,
                rootfsPath: rootfsPath,
                workspaceImagePath: workspaceImagePath,
                vcpuCount: policy.policy.microVMCPUCount,
                memoryMiB: policy.policy.microVMMemoryMiB
            )
        )
        let plan = try runner.invocationPlan(
            command: shellCommand,
            apiSocketPath: socketPath,
            configFilePath: configURL.path
        )
        try Self.writeText(plan.configJSON, to: configURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: plan.executablePath)
        process.arguments = plan.arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        try waitForShellExit(process, cleanupOnTimeout: nil)

        let output = trimmedOutput(from: pipe)

        return [
            ShellExecutedEvent(
                commandID: commandID,
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

    private func waitForShellExit(
        _ process: Process,
        cleanupOnTimeout: (() -> Void)?
    ) throws {
        let deadline = Date().addingTimeInterval(policy.policy.maxExecutionTime)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            cleanupOnTimeout?()
            throw RuntimeError.timeout
        }

        process.waitUntilExit()
    }

    private func trimmedOutput(from pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let trimmed = data.prefix(policy.policy.maxOutputBytes)
        return String(data: trimmed, encoding: .utf8) ?? ""
    }

    private func workspaceRootPath() -> String {
        if let root = policy.policy.allowedWriteRoots.first {
            return URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL.path
        }

        return URL(fileURLWithPath: "workspace", relativeTo: URL(fileURLWithPath: ".", isDirectory: true))
            .standardizedFileURL
            .path
    }

    private func cleanupContainerIfNeeded(cidFileURL: URL) {
        let containerID = (try? String(contentsOf: cidFileURL, encoding: .utf8))
            ?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let containerID, !containerID.isEmpty else {
            return
        }

        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/docker")
        killProcess.arguments = ["kill", containerID]
        killProcess.standardOutput = Pipe()
        killProcess.standardError = Pipe()
        try? killProcess.run()
        killProcess.waitUntilExit()
    }
}

private final class ResponseBox: @unchecked Sendable {
    var data: Data?
    var error: Error?
}
