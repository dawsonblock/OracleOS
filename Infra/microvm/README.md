# MicroVM Assets

`VerifiedExecutor` can switch from container-backed shell execution to a Firecracker-backed
microVM path when `ExecutionPolicy.useMicroVM` is enabled.

## Expected runtime assets

The runtime looks for:

- `vmlinux` - Firecracker-compatible kernel image
- `rootfs.ext4` - root filesystem image with a guest init that can decode
  `oracle_cmd_b64` from the kernel boot arguments and execute it safely
- optional workspace image if `microVMWorkspaceImagePath` is configured

The Swift runtime generates a Firecracker config file dynamically and launches:

```text
/usr/local/bin/firecracker --api-sock <temp-socket> --config-file <temp-config>
```

The generated boot args include:

```text
oracle_cmd_b64=<base64 shell command>
```

## Scaffold included in this repository

This directory now contains the guest-side scaffold needed to build a usable rootfs:

- `rootfs-overlay/sbin/init` - minimal init process for the guest
- `rootfs-overlay/usr/local/bin/oracle-guest-runner.sh` - decodes and runs
  `oracle_cmd_b64`, emits bounded output, and powers off
- `build-rootfs.sh` - builds `rootfs.ext4` from an Alpine base image using Docker
  export + `mkfs.ext4 -d`

## Build the rootfs image

Requirements on the host:

- Docker
- `tar`
- `dd`
- `mkfs.ext4`

Then run:

```bash
./Infra/microvm/build-rootfs.sh
```

Optional environment variables:

```bash
BASE_IMAGE=alpine:3.20
ROOTFS_SIZE_MB=256
./Infra/microvm/build-rootfs.sh
```

This creates:

```text
Infra/microvm/rootfs.ext4
```

You still need to provide a Firecracker-compatible kernel at:

```text
Infra/microvm/vmlinux
```

## Guest execution contract

The guest boot flow is:

1. boot with `init=/sbin/init`
2. mount minimal kernel filesystems
3. extract `oracle_cmd_b64` from `/proc/cmdline`
4. decode and execute the command via `/bin/sh -lc`
5. print bounded output to the serial console
6. power off the guest

This repository intentionally does not check large binary artifacts like
`vmlinux` or `rootfs.ext4` into git.
