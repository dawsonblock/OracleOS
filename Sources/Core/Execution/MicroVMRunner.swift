import Foundation

public struct MicroVMConfiguration: Sendable {
    public let firecrackerBinaryPath: String
    public let kernelImagePath: String
    public let rootfsPath: String
    public let workspaceImagePath: String?
    public let vcpuCount: Int
    public let memoryMiB: Int

    public init(
        firecrackerBinaryPath: String,
        kernelImagePath: String,
        rootfsPath: String,
        workspaceImagePath: String?,
        vcpuCount: Int,
        memoryMiB: Int
    ) {
        self.firecrackerBinaryPath = firecrackerBinaryPath
        self.kernelImagePath = kernelImagePath
        self.rootfsPath = rootfsPath
        self.workspaceImagePath = workspaceImagePath
        self.vcpuCount = vcpuCount
        self.memoryMiB = memoryMiB
    }
}

public struct MicroVMInvocationPlan: Sendable {
    public let executablePath: String
    public let arguments: [String]
    public let configJSON: String

    public init(executablePath: String, arguments: [String], configJSON: String) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.configJSON = configJSON
    }
}

public final class MicroVMRunner: Sendable {
    private let configuration: MicroVMConfiguration

    public init(configuration: MicroVMConfiguration) {
        self.configuration = configuration
    }

    public func invocationPlan(
        command: String,
        apiSocketPath: String,
        configFilePath: String
    ) throws -> MicroVMInvocationPlan {
        let config = FirecrackerConfig(
            bootSource: BootSource(
                kernelImagePath: configuration.kernelImagePath,
                bootArgs: bootArguments(for: command)
            ),
            drives: drives(),
            machineConfig: MachineConfig(
                vcpuCount: max(1, configuration.vcpuCount),
                memSizeMiB: max(128, configuration.memoryMiB)
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return MicroVMInvocationPlan(
            executablePath: configuration.firecrackerBinaryPath,
            arguments: ["--api-sock", apiSocketPath, "--config-file", configFilePath],
            configJSON: json
        )
    }

    private func bootArguments(for command: String) -> String {
        let encodedCommand = Data(command.utf8).base64EncodedString()
        return "console=ttyS0 reboot=k panic=1 pci=off init=/sbin/init oracle_cmd_b64=\(encodedCommand)"
    }

    private func drives() -> [Drive] {
        var result = [
            Drive(
                driveID: "rootfs",
                pathOnHost: configuration.rootfsPath,
                isRootDevice: true,
                isReadOnly: false
            ),
        ]

        if let workspaceImagePath = configuration.workspaceImagePath {
            result.append(
                Drive(
                    driveID: "workspace",
                    pathOnHost: workspaceImagePath,
                    isRootDevice: false,
                    isReadOnly: false
                )
            )
        }

        return result
    }
}

private struct FirecrackerConfig: Encodable {
    let bootSource: BootSource
    let drives: [Drive]
    let machineConfig: MachineConfig

    enum CodingKeys: String, CodingKey {
        case bootSource = "boot-source"
        case drives
        case machineConfig = "machine-config"
    }
}

private struct BootSource: Encodable {
    let kernelImagePath: String
    let bootArgs: String

    enum CodingKeys: String, CodingKey {
        case kernelImagePath = "kernel_image_path"
        case bootArgs = "boot_args"
    }
}

private struct Drive: Encodable {
    let driveID: String
    let pathOnHost: String
    let isRootDevice: Bool
    let isReadOnly: Bool

    enum CodingKeys: String, CodingKey {
        case driveID = "drive_id"
        case pathOnHost = "path_on_host"
        case isRootDevice = "is_root_device"
        case isReadOnly = "is_read_only"
    }
}

private struct MachineConfig: Encodable {
    let vcpuCount: Int
    let memSizeMiB: Int

    enum CodingKeys: String, CodingKey {
        case vcpuCount = "vcpu_count"
        case memSizeMiB = "mem_size_mib"
    }
}
