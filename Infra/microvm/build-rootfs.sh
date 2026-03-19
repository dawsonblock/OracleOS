#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="${SCRIPT_DIR}/rootfs-overlay"
OUTPUT_PATH="${SCRIPT_DIR}/rootfs.ext4"
ROOTFS_SIZE_MB="${ROOTFS_SIZE_MB:-256}"
BASE_IMAGE="${BASE_IMAGE:-alpine:3.20}"
TMP_DIR="$(mktemp -d)"
STAGE_DIR="${TMP_DIR}/rootfs-stage"
CONTAINER_ID=""

cleanup() {
    if [[ -n "${CONTAINER_ID}" ]]; then
        docker rm -f "${CONTAINER_ID}" >/dev/null 2>&1 || true
    fi
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "missing required tool: $1" >&2
        exit 1
    fi
}

require_tool docker
require_tool tar
require_tool dd
require_tool mkfs.ext4

mkdir -p "${STAGE_DIR}"

CONTAINER_ID="$(docker create --platform linux/amd64 "${BASE_IMAGE}" /bin/sh)"
docker export "${CONTAINER_ID}" | tar -x -C "${STAGE_DIR}"
docker rm -f "${CONTAINER_ID}" >/dev/null 2>&1 || true
CONTAINER_ID=""

mkdir -p \
    "${STAGE_DIR}/proc" \
    "${STAGE_DIR}/sys" \
    "${STAGE_DIR}/dev" \
    "${STAGE_DIR}/tmp" \
    "${STAGE_DIR}/run" \
    "${STAGE_DIR}/usr/local/bin"

cp -R "${OVERLAY_DIR}/." "${STAGE_DIR}/"
chmod +x \
    "${STAGE_DIR}/sbin/init" \
    "${STAGE_DIR}/usr/local/bin/oracle-guest-runner.sh"

rm -f "${OUTPUT_PATH}"
dd if=/dev/zero of="${OUTPUT_PATH}" bs=1M count="${ROOTFS_SIZE_MB}" status=none
mkfs.ext4 -d "${STAGE_DIR}" -F "${OUTPUT_PATH}" >/dev/null

echo "created ${OUTPUT_PATH}"
echo "next: place a Firecracker-compatible kernel at ${SCRIPT_DIR}/vmlinux"
