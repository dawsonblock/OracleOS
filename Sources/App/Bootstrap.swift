import Core
import Foundation

enum Bootstrap {
    static func makeRuntime() -> AgentRuntime {
        let repoRoot = URL(fileURLWithPath: ".", isDirectory: true).standardizedFileURL
        let workspaceRoot = URL(
            fileURLWithPath: "workspace",
            relativeTo: repoRoot
        ).standardizedFileURL.path
        let seccompProfile = URL(
            fileURLWithPath: "Infra/executor/seccomp/default.json",
            relativeTo: repoRoot
        ).standardizedFileURL.path
        let microVMKernel = URL(
            fileURLWithPath: "Infra/microvm/vmlinux",
            relativeTo: repoRoot
        ).standardizedFileURL.path
        let microVMRootfs = URL(
            fileURLWithPath: "Infra/microvm/rootfs.ext4",
            relativeTo: repoRoot
        ).standardizedFileURL.path
        let policy = ExecutionPolicy(
            allowedShellCommands: ["ls", "echo", "cat"],
            allowedWriteRoots: [workspaceRoot],
            networkWhitelist: ["example.com"],
            maxExecutionTime: 3,
            maxOutputBytes: 20_000,
            useContainers: true,
            containerImage: "oracle-executor",
            seccompProfilePath: seccompProfile,
            useMicroVM: false,
            firecrackerBinaryPath: "/usr/local/bin/firecracker",
            microVMKernelPath: microVMKernel,
            microVMRootfsPath: microVMRootfs,
            microVMWorkspaceImagePath: nil,
            microVMCPUCount: 1,
            microVMMemoryMiB: 128
        )
        let store = FileEventStore(path: "events.log")
        let loop = AgentLoop(
            planner: BasicPlanner(),
            resolver: CommandResolver(),
            executor: VerifiedExecutor(policy: PolicyEngine(policy: policy)),
            store: store,
            reducer: DefaultReducer(),
            critic: BasicCritic(),
            repair: RepairEngine()
        )

        return AgentRuntime(loop: loop)
    }
}
