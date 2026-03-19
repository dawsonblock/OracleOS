#!/bin/sh
set -eu

CMD_B64="$(tr ' ' '\n' </proc/cmdline | sed -n 's/^oracle_cmd_b64=//p' | head -n 1)"
MAX_OUTPUT_BYTES="${ORACLE_MAX_OUTPUT_BYTES:-50000}"

if [ -z "${CMD_B64}" ]; then
    echo "oracle microvm runner: missing oracle_cmd_b64 boot argument" >&2
    poweroff -f 2>/dev/null || reboot -f 2>/dev/null || exit 1
fi

if ! command -v base64 >/dev/null 2>&1; then
    echo "oracle microvm runner: base64 utility not found" >&2
    poweroff -f 2>/dev/null || reboot -f 2>/dev/null || exit 1
fi

CMD="$(printf '%s' "${CMD_B64}" | base64 -d)"
OUTPUT_FILE="$(mktemp)"
STATUS=0

if ! /bin/sh -lc "${CMD}" >"${OUTPUT_FILE}" 2>&1; then
    STATUS=$?
fi

head -c "${MAX_OUTPUT_BYTES}" "${OUTPUT_FILE}" || true
printf '\noracle_exit_status=%s\n' "${STATUS}"
rm -f "${OUTPUT_FILE}"

poweroff -f 2>/dev/null || reboot -f 2>/dev/null || exit 0
