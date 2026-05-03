#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-ap-chuncheon-1}"
VM_USER="${VM_USER:-opc}"
VM_PRIVATE_IP="${VM_PRIVATE_IP:-10.0.2.34}"

SSH_KEY="${SSH_KEY:-/private/tmp/my-hub-bastion-key}"
KNOWN_HOSTS_FILE="${KNOWN_HOSTS_FILE:-/private/tmp/my-hub-known-hosts}"
BASTION_HOST="${BASTION_HOST:-host.bastion.${REGION}.oci.oraclecloud.com}"
BASTION_ID="${BASTION_ID:-ocid1.bastion.oc1.ap-chuncheon-1.amaaaaaacanazoaa724jb4tpn3umes65ah5qur42b5njr7knjby2az4rgs7q}"
BASTION_SESSION_ID="${BASTION_SESSION_ID:-}"
BASTION_SESSION_TTL="${BASTION_SESSION_TTL:-10800}"
TARGET_INSTANCE_ID="${TARGET_INSTANCE_ID:-ocid1.instance.oc1.ap-chuncheon-1.an4w4ljrcanazoacozhnj7teihrxghx23466tnia4x7cmjwgotzgiplljt5a}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required."
}

ensure_ssh_key() {
  if [[ ! -f "${SSH_KEY}" ]]; then
    mkdir -p "$(dirname "${SSH_KEY}")"
    ssh-keygen -t ed25519 -N '' -f "${SSH_KEY}" -C my-hub-bastion-session
  fi

  if [[ ! -f "${SSH_KEY}.pub" ]]; then
    ssh-keygen -y -f "${SSH_KEY}" >"${SSH_KEY}.pub"
  fi
}

create_bastion_session() {
  [[ -z "${BASTION_SESSION_ID}" ]] || return

  printf 'Creating OCI Bastion managed SSH session\n' >&2
  BASTION_SESSION_ID="$(
    oci bastion session create-managed-ssh \
      --bastion-id "${BASTION_ID}" \
      --display-name my-hub-api-shell \
      --key-type PUB \
      --ssh-public-key-file "${SSH_KEY}.pub" \
      --target-resource-id "${TARGET_INSTANCE_ID}" \
      --target-os-username "${VM_USER}" \
      --target-port 22 \
      --target-private-ip "${VM_PRIVATE_IP}" \
      --session-ttl "${BASTION_SESSION_TTL}" \
      --wait-for-state SUCCEEDED \
      --max-wait-seconds 300 \
      --wait-interval-seconds 10 \
      --query 'data.resources[0].identifier' \
      --raw-output
  )"
}

connect_vm() {
  local proxy_command
  proxy_command="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=${KNOWN_HOSTS_FILE} -W %h:%p -p 22 ${BASTION_SESSION_ID}@${BASTION_HOST}"

  ssh \
    -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    -o "UserKnownHostsFile=${KNOWN_HOSTS_FILE}" \
    -o "ProxyCommand=${proxy_command}" \
    -p 22 \
    "${VM_USER}@${VM_PRIVATE_IP}"
}

main() {
  require_command oci
  require_command ssh
  require_command ssh-keygen
  ensure_ssh_key
  create_bastion_session
  connect_vm
}

main "$@"
