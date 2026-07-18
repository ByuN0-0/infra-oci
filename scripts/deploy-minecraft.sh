#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PACK_FILE="${PACK_FILE:-${REPO_ROOT}/mode/Craft to Exile 2 SERVER-1.1.3.zip}"
OCI_NAMESPACE="${OCI_NAMESPACE:-axlyuqadnsst}"
OBJECT_STORAGE_BUCKET="${OBJECT_STORAGE_BUCKET:-shared-storage}"
MINECRAFT_PACK_OBJECT="${MINECRAFT_PACK_OBJECT:-minecraft/cte2/releases/1.1.3/Craft-to-Exile-2-SERVER-1.1.3.zip}"

if [[ ! -f "${PACK_FILE}" ]]; then
  echo "Minecraft server pack not found: ${PACK_FILE}" >&2
  exit 1
fi

for command_name in oci shasum; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "${command_name} is required." >&2
    exit 1
  }
done

pack_sha256="$(shasum -a 256 "${PACK_FILE}" | awk '{print $1}')"

oci os object put \
  --namespace-name "${OCI_NAMESPACE}" \
  --bucket-name "${OBJECT_STORAGE_BUCKET}" \
  --name "${MINECRAFT_PACK_OBJECT}" \
  --file "${PACK_FILE}" \
  --force

"${SCRIPT_DIR}/ssh-my-hub-api.sh" \
  "sudo OCI_NAMESPACE='${OCI_NAMESPACE}' OBJECT_STORAGE_BUCKET='${OBJECT_STORAGE_BUCKET}' MINECRAFT_PACK_OBJECT='${MINECRAFT_PACK_OBJECT}' MINECRAFT_PACK_SHA256='${pack_sha256}' bash -s" \
  <"${SCRIPT_DIR}/setup-minecraft-runtime.sh"
