#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REGION="${REGION:-ap-chuncheon-1}"
OCIR_NAMESPACE="${OCIR_NAMESPACE:-axlyuqadnsst}"
REPOSITORY="${REPOSITORY:-my-hub-api}"
TAG="${TAG:-latest}"
IMAGE="${IMAGE:-${REGION}.ocir.io/${OCIR_NAMESPACE}/${REPOSITORY}:${TAG}}"
SERVICE_NAME="${SERVICE_NAME:-my-hub-api.service}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8080/health}"
HEALTH_RETRIES="${HEALTH_RETRIES:-30}"
HEALTH_INTERVAL_SECONDS="${HEALTH_INTERVAL_SECONDS:-2}"

REMOTE_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/my-hub-api-deploy.XXXXXX")"
cleanup() {
  rm -f "$REMOTE_SCRIPT"
}
trap cleanup EXIT

cat >"$REMOTE_SCRIPT" <<EOF
set -euo pipefail

IMAGE='${IMAGE}'

sudo /usr/local/sbin/myhub-deploy-my-hub-api "\${IMAGE}"
EOF

DISPLAY_NAME="${DISPLAY_NAME:-my-hub-api-deploy-${TAG}}" \
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}" \
"${SCRIPT_DIR}/run-my-hub-api-command.sh" --script-file "$REMOTE_SCRIPT"
