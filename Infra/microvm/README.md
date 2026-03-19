# MicroVM Assets

`VerifiedExecutor` can switch from container-backed shell execution to a Firecracker-backed
microVM path when `ExecutionPolicy.useMicroVM` is enabled.

The runtime expects these host assets:

- `vmlinux` - Firecracker-compatible kernel image
- `rootfs.ext4` - root filesystem image with an init process that can read
  `oracle_cmd_b64` from the kernel boot arguments and execute it safely
- optional workspace disk image if `microVMWorkspaceImagePath` is configured

The Swift runtime generates a Firecracker config file dynamically and launches:

```text
/usr/local/bin/firecracker --api-sock <temp-socket> --config-file <temp-config>
```

The generated boot args include:

```text
oracle_cmd_b64=<base64 shell command>
```

A practical guest init flow is:

1. read `/proc/cmdline`
2. decode `oracle_cmd_b64`
3. execute the command with bounded output capture
4. emit output to the serial console so the host can record it

This directory intentionally documents the contract without checking large binary
assets into the repository.
