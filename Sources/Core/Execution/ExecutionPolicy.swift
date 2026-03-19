import Foundation

public struct ExecutionPolicy: Sendable {
    public let allowedShellCommands: Set<String>
    public let allowedWriteRoots: [String]
    public let networkWhitelist: Set<String>
    public let maxExecutionTime: TimeInterval
    public let maxOutputBytes: Int
    public let useContainers: Bool
    public let containerImage: String
    public let seccompProfilePath: String?
    public let useMicroVM: Bool
    public let firecrackerBinaryPath: String
    public let microVMKernelPath: String
    public let microVMRootfsPath: String
    public let microVMWorkspaceImagePath: String?
    public let microVMCPUCount: Int
    public let microVMMemoryMiB: Int

    public init(
        allowedShellCommands: Set<String>,
        allowedWriteRoots: [String],
        networkWhitelist: Set<String>,
        maxExecutionTime: TimeInterval = 5.0,
        maxOutputBytes: Int = 50_000,
        useContainers: Bool = false,
        containerImage: String = "oracle-executor",
        seccompProfilePath: String? = nil,
        useMicroVM: Bool = false,
        firecrackerBinaryPath: String = "/usr/local/bin/firecracker",
        microVMKernelPath: String = "Infra/microvm/vmlinux",
        microVMRootfsPath: String = "Infra/microvm/rootfs.ext4",
        microVMWorkspaceImagePath: String? = nil,
        microVMCPUCount: Int = 1,
        microVMMemoryMiB: Int = 128
    ) {
        self.allowedShellCommands = allowedShellCommands
        self.allowedWriteRoots = allowedWriteRoots
        self.networkWhitelist = networkWhitelist
        self.maxExecutionTime = maxExecutionTime
        self.maxOutputBytes = maxOutputBytes
        self.useContainers = useContainers
        self.containerImage = containerImage
        self.seccompProfilePath = seccompProfilePath
        self.useMicroVM = useMicroVM
        self.firecrackerBinaryPath = firecrackerBinaryPath
        self.microVMKernelPath = microVMKernelPath
        self.microVMRootfsPath = microVMRootfsPath
        self.microVMWorkspaceImagePath = microVMWorkspaceImagePath
        self.microVMCPUCount = microVMCPUCount
        self.microVMMemoryMiB = microVMMemoryMiB
    }
}
