#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root." >&2
  exit 1
fi

: "${MINECRAFT_ADMIN_TUNNEL_SECRET_ID:?MINECRAFT_ADMIN_TUNNEL_SECRET_ID is required}"
: "${MINECRAFT_ADMIN_HOSTNAME:?MINECRAFT_ADMIN_HOSTNAME is required}"
: "${CLOUDFLARE_ACCESS_TEAM_DOMAIN:?CLOUDFLARE_ACCESS_TEAM_DOMAIN is required}"
: "${CLOUDFLARE_ACCESS_AUDIENCE:?CLOUDFLARE_ACCESS_AUDIENCE is required}"

SOURCE_DIR="${SOURCE_DIR:-/srv/minecraft-admin/source}"
ADMIN_ROOT="/srv/minecraft-admin"
ADMIN_AUDIT="${ADMIN_ROOT}/audit"
ADMIN_IMAGE="localhost/minecraft-admin:1.0.0"
ADMIN_BUILDER_IMAGE="docker.io/library/golang@sha256:787328cefd7937073af18fc4b3a725f47e011ffdde9c2908239a25cae6b2f02b"
CLOUDFLARED_IMAGE="docker.io/cloudflare/cloudflared@sha256:a85d5a3d6f22cb3c7e78b2f0d05b0f0daeb72566e9426f656c60b357b7b89c95"
MC_QUADLET="/etc/containers/systemd/craft-to-exile-2.container"

require_file() {
  [[ -f "$1" ]] || {
    echo "Required file does not exist: $1" >&2
    exit 1
  }
}

install_dependencies() {
  command -v podman >/dev/null 2>&1 || dnf install -y podman
  if ! command -v oci >/dev/null 2>&1; then
    dnf install -y python36-oci-cli || dnf install -y python3-oci-cli
  fi
}

prepare_directories() {
  install -d -m 0755 /etc/containers/systemd /etc/minecraft-admin "${ADMIN_ROOT}"
  install -d -o 1000 -g 1000 -m 0700 "${ADMIN_AUDIT}"
  require_file "${SOURCE_DIR}/Containerfile"
  require_file "${SOURCE_DIR}/go.mod"
}

fetch_tunnel_token() {
  local token_file="/etc/minecraft-admin/cloudflared-token"
  local temporary_file="${token_file}.tmp"
  umask 077
  oci secrets secret-bundle get \
    --auth instance_principal \
    --secret-id "${MINECRAFT_ADMIN_TUNNEL_SECRET_ID}" \
    --query 'data."secret-bundle-content".content' \
    --raw-output | base64 --decode >"${temporary_file}"
  [[ -s "${temporary_file}" ]] || {
    echo "OCI Vault returned an empty Tunnel token." >&2
    exit 1
  }
  chown 65532:65532 "${temporary_file}"
  chmod 0400 "${temporary_file}"
  mv "${temporary_file}" "${token_file}"
}

create_manual_backup() {
  if ! systemctl is-active --quiet craft-to-exile-2.service; then
    echo "Minecraft is not active; refusing to deploy without a pre-deployment backup." >&2
    exit 1
  fi

  local marker
  marker="$(mktemp /tmp/minecraft-admin-backup.XXXXXX)"
  touch "${marker}"
  podman exec craft-to-exile-2 rcon-cli simplebackups backup start
  for _ in $(seq 1 120); do
    if find /srv/minecraft/data/simplebackups -type f -name '*.zip' -newer "${marker}" -print -quit 2>/dev/null | grep -q .; then
      rm -f "${marker}"
      echo "Pre-deployment Simple Backups archive completed."
      return 0
    fi
    sleep 5
  done
  rm -f "${marker}"
  echo "Timed out waiting for the pre-deployment backup." >&2
  exit 1
}

publish_loopback_rcon() {
  require_file "${MC_QUADLET}"
  if grep -Fq 'PublishPort=127.0.0.1:25575:25575/tcp' "${MC_QUADLET}"; then
    return 0
  fi
  sed -i '/^PublishPort=.*:25565\/tcp$/a PublishPort=127.0.0.1:25575:25575/tcp' "${MC_QUADLET}"
  grep -Fq 'PublishPort=127.0.0.1:25575:25575/tcp' "${MC_QUADLET}" || {
    echo "Failed to add the loopback-only RCON publish rule." >&2
    exit 1
  }
  systemctl daemon-reload
  systemctl restart craft-to-exile-2.service
  for _ in $(seq 1 120); do
    if podman exec craft-to-exile-2 rcon-cli list >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done
  echo "Minecraft did not become RCON-ready after restart." >&2
  exit 1
}

build_admin_image() {
  podman pull "${ADMIN_BUILDER_IMAGE}"
  podman build --pull=never --tag "${ADMIN_IMAGE}" --file "${SOURCE_DIR}/Containerfile" "${SOURCE_DIR}"
}

install_quadlets() {
  cat >/etc/containers/systemd/minecraft-admin.container <<EOF
[Unit]
Description=Cloudflare Access protected Minecraft administration application
After=network-online.target craft-to-exile-2.service
Wants=network-online.target craft-to-exile-2.service

[Container]
Image=${ADMIN_IMAGE}
ContainerName=minecraft-admin
Network=host
Environment=LISTEN_ADDRESS=127.0.0.1:8081
Environment=CLOUDFLARE_ACCESS_TEAM_DOMAIN=${CLOUDFLARE_ACCESS_TEAM_DOMAIN}
Environment=CLOUDFLARE_ACCESS_AUDIENCE=${CLOUDFLARE_ACCESS_AUDIENCE}
Environment=RCON_ADDRESS=127.0.0.1:25575
Environment=RCON_PASSWORD_FILE=/run/secrets/rcon-password
Environment=WHITELIST_FILE=/minecraft-data/whitelist.json
Environment=OPS_FILE=/minecraft-data/ops.json
Environment=AUDIT_FILE=/audit/audit.jsonl
Volume=/etc/minecraft/rcon-password:/run/secrets/rcon-password:ro,Z
Volume=/srv/minecraft/data:/minecraft-data:ro,Z
Volume=${ADMIN_AUDIT}:/audit:Z
PodmanArgs=--memory=128m --cpus=0.25 --read-only --cap-drop=all --security-opt=no-new-privileges

[Service]
Restart=always
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF

  cat >/etc/containers/systemd/minecraft-admin-cloudflared.container <<EOF
[Unit]
Description=Cloudflare Tunnel for the Minecraft administration application
After=network-online.target minecraft-admin.service
Wants=network-online.target minecraft-admin.service

[Container]
Image=${CLOUDFLARED_IMAGE}
ContainerName=minecraft-admin-cloudflared
Network=host
Volume=/etc/minecraft-admin/cloudflared-token:/run/secrets/cloudflared-token:ro,Z
Exec=tunnel --no-autoupdate run --token-file /run/secrets/cloudflared-token
PodmanArgs=--memory=256m --cpus=0.25 --read-only --cap-drop=all --security-opt=no-new-privileges

[Service]
Restart=always
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
}

start_and_verify() {
  podman pull "${CLOUDFLARED_IMAGE}"
  systemctl daemon-reload
  systemctl start minecraft-admin.service
  systemctl start minecraft-admin-cloudflared.service
  for _ in $(seq 1 30); do
    if curl --fail --silent http://127.0.0.1:8081/healthz >/dev/null; then
      break
    fi
    sleep 2
  done
  curl --fail --silent http://127.0.0.1:8081/healthz >/dev/null
  systemctl is-active --quiet minecraft-admin.service
  systemctl is-active --quiet minecraft-admin-cloudflared.service
}

install_dependencies
prepare_directories
fetch_tunnel_token
create_manual_backup
publish_loopback_rcon
build_admin_image
install_quadlets
start_and_verify
