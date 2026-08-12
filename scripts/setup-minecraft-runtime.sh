#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root." >&2
  exit 1
fi

: "${OCI_NAMESPACE:?OCI_NAMESPACE is required}"
: "${OBJECT_STORAGE_BUCKET:?OBJECT_STORAGE_BUCKET is required}"
: "${MINECRAFT_PACK_OBJECT:?MINECRAFT_PACK_OBJECT is required}"
: "${MINECRAFT_PACK_SHA256:?MINECRAFT_PACK_SHA256 is required}"

MINECRAFT_PORT="${MINECRAFT_PORT:-25565}"
MINECRAFT_UID="${MINECRAFT_UID:-1000}"
MINECRAFT_GID="${MINECRAFT_GID:-1000}"
MINECRAFT_LV_SIZE="${MINECRAFT_LV_SIZE:-140G}"
MINECRAFT_IMAGE="${MINECRAFT_IMAGE:-docker.io/itzg/minecraft-server:java17}"
MINECRAFT_ROOT="/srv/minecraft"
MINECRAFT_DATA="${MINECRAFT_ROOT}/data"
MINECRAFT_PACK="${MINECRAFT_ROOT}/packs/Craft-to-Exile-2-SERVER-1.1.3.zip"

install_packages() {
  dnf install -y cloud-utils-growpart lvm2 xfsprogs podman unzip openssl python36-oci-cli || \
    dnf install -y cloud-utils-growpart lvm2 xfsprogs podman unzip openssl python3-oci-cli
}

prepare_storage() {
  growpart /dev/sda 3 || true
  pvresize /dev/sda3

  if ! lvs /dev/ocivolume/minecraft >/dev/null 2>&1; then
    lvcreate -L "${MINECRAFT_LV_SIZE}" -n minecraft ocivolume
  fi

  if [[ -z "$(blkid -o value -s TYPE /dev/ocivolume/minecraft || true)" ]]; then
    mkfs.xfs /dev/ocivolume/minecraft
  fi

  mkdir -p "${MINECRAFT_ROOT}"
  local minecraft_uuid
  minecraft_uuid="$(blkid -o value -s UUID /dev/ocivolume/minecraft)"
  if ! grep -q "UUID=${minecraft_uuid}" /etc/fstab; then
    printf 'UUID=%s %s xfs defaults,nofail 0 2\n' "${minecraft_uuid}" "${MINECRAFT_ROOT}" >>/etc/fstab
  fi
  mountpoint -q "${MINECRAFT_ROOT}" || mount "${MINECRAFT_ROOT}"
  mkdir -p "${MINECRAFT_DATA}" "${MINECRAFT_ROOT}/packs"
  chown -R "${MINECRAFT_UID}:${MINECRAFT_GID}" "${MINECRAFT_ROOT}"
}

download_pack() {
  local current_sha=""
  if [[ -f "${MINECRAFT_PACK}" ]]; then
    current_sha="$(sha256sum "${MINECRAFT_PACK}" | awk '{print $1}')"
  fi

  if [[ "${current_sha}" != "${MINECRAFT_PACK_SHA256}" ]]; then
    rm -f "${MINECRAFT_PACK}.part"
    for attempt in $(seq 1 30); do
      if oci os object get \
        --auth instance_principal \
        --namespace-name "${OCI_NAMESPACE}" \
        --bucket-name "${OBJECT_STORAGE_BUCKET}" \
        --name "${MINECRAFT_PACK_OBJECT}" \
        --file "${MINECRAFT_PACK}.part"; then
        break
      fi
      echo "Waiting for Object Storage access (${attempt}/30)."
      sleep 10
    done
    mv "${MINECRAFT_PACK}.part" "${MINECRAFT_PACK}"
  fi

  printf '%s  %s\n' "${MINECRAFT_PACK_SHA256}" "${MINECRAFT_PACK}" | sha256sum --check --status
  chown "${MINECRAFT_UID}:${MINECRAFT_GID}" "${MINECRAFT_PACK}"
}

install_server_pack() {
  local installed_marker="${MINECRAFT_DATA}/.cte2-server-pack-1.1.3.sha256"
  if [[ ! -f "${installed_marker}" ]] || [[ "$(<"${installed_marker}")" != "${MINECRAFT_PACK_SHA256}" ]]; then
    if [[ -d "${MINECRAFT_DATA}/world" ]]; then
      echo "A world already exists; refusing to overlay a different server pack." >&2
      exit 1
    fi
    unzip -q -o "${MINECRAFT_PACK}" -d "${MINECRAFT_DATA}"
    printf '%s\n' "${MINECRAFT_PACK_SHA256}" >"${installed_marker}"
  fi

  cat >"${MINECRAFT_DATA}/user_jvm_args.txt" <<'EOF'
-Xms12G
-Xmx20G
EOF
  printf 'eula=true\n' >"${MINECRAFT_DATA}/eula.txt"
  chown -R "${MINECRAFT_UID}:${MINECRAFT_GID}" "${MINECRAFT_DATA}"
}

install_backup_uploader() {
  cat >/usr/local/sbin/minecraft-backup-to-oci <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

OCI_NAMESPACE="__OCI_NAMESPACE__"
OBJECT_STORAGE_BUCKET="__OBJECT_STORAGE_BUCKET__"
BACKUP_ROOT="/srv/minecraft/data/simplebackups"
BACKUP_PREFIX="minecraft/cte2/backups"

if [[ ! -d "${BACKUP_ROOT}" ]]; then
  echo "No Simple Backups directory exists yet; skipping."
  exit 0
fi

latest_line="$(find "${BACKUP_ROOT}" -type f -name '*.zip' -printf '%T@ %p\n' | sort -nr | head -n 1)"
if [[ -z "${latest_line}" ]]; then
  echo "No completed Simple Backups archive exists yet; skipping."
  exit 0
fi

latest_path="${latest_line#* }"
latest_name="$(basename "${latest_path}")"
object_name="${BACKUP_PREFIX}/$(date -u +%Y-%m-%dT%H-%M-%SZ)-${latest_name}"

oci os object put \
  --auth instance_principal \
  --namespace-name "${OCI_NAMESPACE}" \
  --bucket-name "${OBJECT_STORAGE_BUCKET}" \
  --name "${object_name}" \
  --file "${latest_path}" \
  --force
EOF
  sed -i "s/__OCI_NAMESPACE__/${OCI_NAMESPACE}/g; s/__OBJECT_STORAGE_BUCKET__/${OBJECT_STORAGE_BUCKET}/g" /usr/local/sbin/minecraft-backup-to-oci
  chmod 0755 /usr/local/sbin/minecraft-backup-to-oci

  cat >/etc/systemd/system/minecraft-backup-to-oci.service <<'EOF'
[Unit]
Description=Upload the latest Craft to Exile 2 backup to OCI Object Storage
After=network-online.target craft-to-exile-2.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/minecraft-backup-to-oci
EOF

  cat >/etc/systemd/system/minecraft-backup-to-oci.timer <<'EOF'
[Unit]
Description=Daily Craft to Exile 2 Object Storage backup

[Timer]
# The instance uses UTC; 20:00 UTC is 05:00 Asia/Seoul the following day.
OnCalendar=*-*-* 20:00:00
Persistent=true
RandomizedDelaySec=10m

[Install]
WantedBy=timers.target
EOF
}

install_quadlet() {
  install -d -m 0755 /etc/containers/systemd /etc/minecraft
  if [[ ! -s /etc/minecraft/rcon-password ]]; then
    openssl rand -base64 36 >/etc/minecraft/rcon-password
  fi
  chown "${MINECRAFT_UID}:${MINECRAFT_GID}" /etc/minecraft/rcon-password
  chmod 0400 /etc/minecraft/rcon-password

  podman pull "${MINECRAFT_IMAGE}"
  local pinned_image
  pinned_image="$(podman image inspect "${MINECRAFT_IMAGE}" --format '{{index .RepoDigests 0}}')"
  [[ -n "${pinned_image}" ]] || pinned_image="${MINECRAFT_IMAGE}"

  rm -f /etc/containers/systemd/my-hub-api.container /etc/my-hub-api.env /etc/my-hub-api-image

  cat >/etc/containers/systemd/craft-to-exile-2.container <<EOF
[Unit]
Description=Craft to Exile 2 Minecraft server
After=network-online.target
Wants=network-online.target

[Container]
Image=${pinned_image}
ContainerName=craft-to-exile-2
Environment=EULA=TRUE
Environment=TYPE=FORGE
Environment=VERSION=1.20.1
Environment=FORGE_VERSION=47.4.10
Environment=INIT_MEMORY=12G
Environment=MAX_MEMORY=20G
Environment=MAX_PLAYERS=20
Environment=ONLINE_MODE=TRUE
Environment=ALLOW_FLIGHT=TRUE
Environment=ENABLE_COMMAND_BLOCK=TRUE
Environment=VIEW_DISTANCE=10
Environment=SIMULATION_DISTANCE=8
Environment=WHITELIST=icuL_
Environment=OPS=icuL_
Environment=ENFORCE_WHITELIST=TRUE
Environment=EXISTING_WHITELIST_FILE=MERGE
Environment=EXISTING_OPS_FILE=MERGE
Environment=ENABLE_RCON=TRUE
Environment=RCON_PASSWORD_FILE=/run/secrets/rcon-password
Environment=TZ=Asia/Seoul
Environment=MOTD=Craft-to-Exile-2-1.1.3
Environment=UID=${MINECRAFT_UID}
Environment=GID=${MINECRAFT_GID}
Volume=${MINECRAFT_DATA}:/data:Z
Volume=/etc/minecraft/rcon-password:/run/secrets/rcon-password:ro,Z
PublishPort=${MINECRAFT_PORT}:${MINECRAFT_PORT}/tcp
PublishPort=127.0.0.1:25575:25575/tcp

[Service]
Restart=always
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF
}

enable_runtime() {
  systemctl disable --now my-hub-api.service 2>/dev/null || true
  firewall-cmd --permanent --add-port="${MINECRAFT_PORT}/tcp"
  firewall-cmd --reload
  systemctl daemon-reload
  systemctl enable --now podman.socket
  systemctl start craft-to-exile-2.service
  systemctl enable --now minecraft-backup-to-oci.timer
}

install_packages
prepare_storage
download_pack
install_server_pack
install_backup_uploader
install_quadlet
enable_runtime
