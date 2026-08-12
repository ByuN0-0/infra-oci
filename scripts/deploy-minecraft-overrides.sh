#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OVERRIDES_FILE="${OVERRIDES_FILE:-${REPO_ROOT}/mode/Craft to Exile 2 (VR Support)-1.1.3-ko_kr-overrides.zip}"
OCI_NAMESPACE="${OCI_NAMESPACE:-axlyuqadnsst}"
OBJECT_STORAGE_BUCKET="${OBJECT_STORAGE_BUCKET:-shared-storage}"
MINECRAFT_OVERRIDES_OBJECT="${MINECRAFT_OVERRIDES_OBJECT:-minecraft/cte2/overrides/1.1.3/Craft-to-Exile-2-VR-Support-1.1.3-ko_kr-overrides.zip}"

if [[ ! -f "${OVERRIDES_FILE}" ]]; then
  echo "Minecraft overrides ZIP not found: ${OVERRIDES_FILE}" >&2
  exit 1
fi

for command_name in oci shasum unzip; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "${command_name} is required." >&2
    exit 1
  }
done

if unzip -Z -1 "${OVERRIDES_FILE}" | grep -Eq '(^/|(^|/)\.\.(/|$)|\\)'; then
  echo "The overrides ZIP contains an unsafe path." >&2
  exit 1
fi

overrides_sha256="$(shasum -a 256 "${OVERRIDES_FILE}" | awk '{print $1}')"

oci os object put \
  --namespace-name "${OCI_NAMESPACE}" \
  --bucket-name "${OBJECT_STORAGE_BUCKET}" \
  --name "${MINECRAFT_OVERRIDES_OBJECT}" \
  --file "${OVERRIDES_FILE}" \
  --force

"${SCRIPT_DIR}/ssh-my-hub-api.sh" \
  "sudo OCI_NAMESPACE='${OCI_NAMESPACE}' OBJECT_STORAGE_BUCKET='${OBJECT_STORAGE_BUCKET}' MINECRAFT_OVERRIDES_OBJECT='${MINECRAFT_OVERRIDES_OBJECT}' MINECRAFT_OVERRIDES_SHA256='${overrides_sha256}' bash -s" \
  <"${SCRIPT_DIR}/setup-minecraft-overrides-runtime.sh"
