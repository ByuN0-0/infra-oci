#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root." >&2
  exit 1
fi

: "${OCI_NAMESPACE:?OCI_NAMESPACE is required}"
: "${OBJECT_STORAGE_BUCKET:?OBJECT_STORAGE_BUCKET is required}"
: "${MINECRAFT_OVERRIDES_OBJECT:?MINECRAFT_OVERRIDES_OBJECT is required}"
: "${MINECRAFT_OVERRIDES_SHA256:?MINECRAFT_OVERRIDES_SHA256 is required}"

MINECRAFT_UID="${MINECRAFT_UID:-1000}"
MINECRAFT_GID="${MINECRAFT_GID:-1000}"
MINECRAFT_DATA="/srv/minecraft/data"
OVERRIDES_ZIP="/srv/minecraft/packs/Craft-to-Exile-2-VR-Support-1.1.3-ko_kr-overrides.zip"
OVERRIDES_MARKER="${MINECRAFT_DATA}/.cte2-ko-kr-overrides-1.1.3.sha256"
QUADLET="/etc/containers/systemd/craft-to-exile-2.container"
BACKUP_ROOT="${MINECRAFT_DATA}/simplebackups"
BACKUP_MARKER="$(mktemp /tmp/minecraft-overrides-backup.XXXXXX)"
SERVER_STOPPED=false

cleanup() {
  rm -f "${BACKUP_MARKER}"
  if [[ "${SERVER_STOPPED}" == true ]] && ! systemctl is-active --quiet craft-to-exile-2.service; then
    systemctl start craft-to-exile-2.service || true
  fi
}
trap cleanup EXIT

download_overrides() {
  local current_sha=""
  install -d -o "${MINECRAFT_UID}" -g "${MINECRAFT_GID}" -m 0755 "$(dirname "${OVERRIDES_ZIP}")"

  if [[ -f "${OVERRIDES_ZIP}" ]]; then
    current_sha="$(sha256sum "${OVERRIDES_ZIP}" | awk '{print $1}')"
  fi

  if [[ "${current_sha}" != "${MINECRAFT_OVERRIDES_SHA256}" ]]; then
    rm -f "${OVERRIDES_ZIP}.part"
    oci os object get \
      --auth instance_principal \
      --namespace-name "${OCI_NAMESPACE}" \
      --bucket-name "${OBJECT_STORAGE_BUCKET}" \
      --name "${MINECRAFT_OVERRIDES_OBJECT}" \
      --file "${OVERRIDES_ZIP}.part"
    mv "${OVERRIDES_ZIP}.part" "${OVERRIDES_ZIP}"
  fi

  printf '%s  %s\n' "${MINECRAFT_OVERRIDES_SHA256}" "${OVERRIDES_ZIP}" | sha256sum --check --status
  chown "${MINECRAFT_UID}:${MINECRAFT_GID}" "${OVERRIDES_ZIP}"

  if unzip -Z -1 "${OVERRIDES_ZIP}" | grep -Eq '(^/|(^|/)\.\.(/|$)|\\)'; then
    echo "The overrides ZIP contains an unsafe path." >&2
    exit 1
  fi
}

create_backup() {
  if ! systemctl is-active --quiet craft-to-exile-2.service; then
    echo "Minecraft is not running; refusing to deploy without a fresh backup." >&2
    exit 1
  fi

  touch "${BACKUP_MARKER}"
  podman exec craft-to-exile-2 rcon-cli simplebackups backup start

  for _ in $(seq 1 120); do
    local backup_path
    backup_path="$(find "${BACKUP_ROOT}" -type f -name '*.zip' -newer "${BACKUP_MARKER}" -print -quit 2>/dev/null || true)"
    if [[ -n "${backup_path}" ]] && unzip -tq "${backup_path}" >/dev/null 2>&1; then
      echo "Verified backup: ${backup_path}"
      return
    fi
    sleep 5
  done

  echo "Timed out waiting for a verified Simple Backups archive." >&2
  exit 1
}

set_server_property() {
  local key="$1"
  local value="$2"
  local properties="${MINECRAFT_DATA}/server.properties"

  if grep -q "^${key}=" "${properties}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${properties}"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${properties}"
  fi
}

apply_overrides() {
  systemctl stop craft-to-exile-2.service
  SERVER_STOPPED=true

  unzip -q -o "${OVERRIDES_ZIP}" -d "${MINECRAFT_DATA}"
  printf '%s\n' "${MINECRAFT_OVERRIDES_SHA256}" >"${OVERRIDES_MARKER}"

  sed -i '/^Environment=RESOURCE_PACK/d' "${QUADLET}"
  set_server_property resource-pack ""
  set_server_property resource-pack-sha1 ""
  set_server_property require-resource-pack false

  chown -R "${MINECRAFT_UID}:${MINECRAFT_GID}" "${MINECRAFT_DATA}"
  systemctl daemon-reload
  systemctl start craft-to-exile-2.service
  SERVER_STOPPED=false
}

verify_runtime() {
  for _ in $(seq 1 120); do
    if podman exec craft-to-exile-2 rcon-cli list >/dev/null 2>&1; then
      break
    fi
    sleep 5
  done

  systemctl is-active --quiet craft-to-exile-2.service
  podman exec craft-to-exile-2 rcon-cli list
  grep -E '^(resource-pack|resource-pack-sha1|require-resource-pack)=' "${MINECRAFT_DATA}/server.properties"
  printf 'Applied overrides SHA-256: '
  cat "${OVERRIDES_MARKER}"
}

download_overrides

if [[ -f "${OVERRIDES_MARKER}" ]] && [[ "$(<"${OVERRIDES_MARKER}")" == "${MINECRAFT_OVERRIDES_SHA256}" ]] && ! grep -q '^Environment=RESOURCE_PACK' "${QUADLET}"; then
  echo "The requested overrides are already installed and the resource pack is disabled."
  exit 0
fi

create_backup
apply_overrides
verify_runtime
