#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root, for example: sudo IMAGE_URL=... $0" >&2
  exit 1
fi

IMAGE_URL="${IMAGE_URL:-}"
PORT="${PORT:-8080}"
START_SERVICE="${START_SERVICE:-0}"
OCI_ENV_SECRET="${OCI_ENV_SECRET:-}"
OCI_VAULT_ID="${OCI_VAULT_ID:-}"

if [[ -z "${IMAGE_URL}" ]]; then
  echo "IMAGE_URL is required, for example:" >&2
  echo "  sudo IMAGE_URL=ap-chuncheon-1.ocir.io/<namespace>/my-hub-api:latest $0" >&2
  exit 1
fi

OCIR_ENDPOINT="${OCIR_ENDPOINT:-${IMAGE_URL%%/*}}"

install_podman() {
  if command -v podman >/dev/null 2>&1; then
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    dnf install -y podman
  elif command -v microdnf >/dev/null 2>&1; then
    microdnf install -y podman
  else
    echo "Could not find dnf or microdnf to install podman." >&2
    exit 1
  fi
}

install_oci_cli() {
  if [[ -z "${OCI_ENV_SECRET}" || -z "${OCI_VAULT_ID}" ]] || command -v oci >/dev/null 2>&1; then
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    dnf install -y python36-oci-cli || dnf install -y python3-oci-cli
  elif command -v microdnf >/dev/null 2>&1; then
    microdnf install -y python3-oci-cli
  else
    echo "Could not find dnf or microdnf to install OCI CLI." >&2
    exit 1
  fi
}

env_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' /etc/my-hub-api.env 2>/dev/null || true
}

refresh_env_from_vault() {
  if [[ -z "${OCI_ENV_SECRET}" || -z "${OCI_VAULT_ID}" ]]; then
    return
  fi

  oci secrets secret-bundle get-secret-bundle-by-name \
    --auth instance_principal \
    --vault-id "${OCI_VAULT_ID}" \
    --secret-name "${OCI_ENV_SECRET}" \
    --query 'data."secret-bundle-content".content' \
    --raw-output | base64 --decode >/run/my-hub-api.env
  install -m 0600 -o root -g root /run/my-hub-api.env /etc/my-hub-api.env
  rm -f /run/my-hub-api.env
}

login_ocir() {
  local ocir_username
  local ocir_auth_token

  ocir_username="$(env_value OCIR_USERNAME)"
  ocir_auth_token="$(env_value OCIR_AUTH_TOKEN)"

  if [[ -z "${ocir_username}" || -z "${ocir_auth_token}" ]]; then
    return
  fi

  printf '%s' "${ocir_auth_token}" | podman login "${OCIR_ENDPOINT}" \
    --username "${ocir_username}" \
    --password-stdin
}

install_podman
install_oci_cli

mkdir -p /etc/containers/systemd /opt/my-hub/apps /opt/my-hub/examples

if [[ ! -f /etc/my-hub-api.env ]]; then
  cat >/etc/my-hub-api.env <<EOF
PORT=${PORT}
EOF
  chmod 0600 /etc/my-hub-api.env
else
  chmod 0600 /etc/my-hub-api.env
  if ! grep -q '^PORT=' /etc/my-hub-api.env; then
    printf '\nPORT=%s\n' "${PORT}" >>/etc/my-hub-api.env
  fi
fi

refresh_env_from_vault
login_ocir

cat >/etc/my-hub-api-image <<EOF
${IMAGE_URL}
EOF
chmod 0644 /etc/my-hub-api-image

cat >/etc/containers/systemd/my-hub-api.container <<EOF
[Unit]
Description=my-hub API
After=network-online.target
Wants=network-online.target

[Container]
Image=${IMAGE_URL}
ContainerName=my-hub-api
EnvironmentFile=/etc/my-hub-api.env
PublishPort=${PORT}:${PORT}

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 /etc/containers/systemd/my-hub-api.container

cat >/opt/my-hub/examples/redis.container <<'EOF'
[Unit]
Description=my-hub Redis

[Container]
Image=docker.io/library/redis:7-alpine
ContainerName=my-hub-redis
Volume=my-hub-redis-data:/data
PublishPort=127.0.0.1:6379:6379

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 /opt/my-hub/examples/redis.container

cat >/opt/my-hub/README.md <<EOF
# my-hub runtime

Podman and Quadlet are installed for running my-hub services.
The my-hub API Quadlet unit is prepared at:

/etc/containers/systemd/my-hub-api.container

OCIR private repository login:

sudo podman login ${OCIR_ENDPOINT}

Start or restart the API:

sudo systemctl daemon-reload
sudo systemctl enable --now my-hub-api.service
sudo systemctl restart my-hub-api.service

Deploy a new image tag:

sudo podman pull \$(cat /etc/my-hub-api-image)
sudo systemctl restart my-hub-api.service

Useful commands:

sudo systemctl status my-hub-api.service
sudo journalctl -u my-hub-api.service -f
podman ps
podman logs my-hub-api

Secrets are not written through instance metadata.
Add service secrets manually over Bastion SSH, for example:

sudoedit /etc/my-hub-api.env
EOF
chmod 0644 /opt/my-hub/README.md

systemctl enable --now podman.socket
systemctl daemon-reload

if [[ "${START_SERVICE}" == "1" ]]; then
  systemctl enable --now my-hub-api.service
else
  systemctl enable my-hub-api.service
  cat <<EOF
Runtime prepared.

Next steps:
  sudo podman login ${OCIR_ENDPOINT}
  sudo systemctl start my-hub-api.service
  sudo systemctl status my-hub-api.service
EOF
fi
