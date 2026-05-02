#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root, for example: sudo $0" >&2
  exit 1
fi

if [[ ! -f /etc/my-hub-api-image ]]; then
  echo "/etc/my-hub-api-image does not exist. Run setup-my-hub-api-runtime.sh first." >&2
  exit 1
fi

IMAGE_URL="$(tr -d '[:space:]' </etc/my-hub-api-image)"

if [[ -z "${IMAGE_URL}" ]]; then
  echo "/etc/my-hub-api-image is empty." >&2
  exit 1
fi

podman pull "${IMAGE_URL}"
systemctl daemon-reload
systemctl restart my-hub-api.service
systemctl status my-hub-api.service --no-pager
