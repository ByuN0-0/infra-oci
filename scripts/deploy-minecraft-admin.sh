#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_BIN="${TERRAFORM_BIN:-terraform}"
REMOTE_SOURCE_DIR="/srv/minecraft-admin/source"

for command_name in "${TERRAFORM_BIN}" tar; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "${command_name} is required." >&2
    exit 1
  }
done

output() {
  "${TERRAFORM_BIN}" -chdir="${REPO_ROOT}" output -raw "$1"
}

tunnel_secret_id="${MINECRAFT_ADMIN_TUNNEL_SECRET_ID:-$(output minecraft_admin_tunnel_secret_id)}"
admin_hostname="${MINECRAFT_ADMIN_HOSTNAME:-$(output minecraft_admin_hostname)}"
team_domain="${CLOUDFLARE_ACCESS_TEAM_DOMAIN:-$(output cloudflare_access_team_domain)}"
access_audience="${CLOUDFLARE_ACCESS_AUDIENCE:-$(output cloudflare_access_audience)}"

tar -C "${REPO_ROOT}/minecraft-admin" -czf - . | \
  "${SCRIPT_DIR}/ssh-my-hub-api.sh" \
    "sudo install -d -m 0755 '${REMOTE_SOURCE_DIR}' && sudo find '${REMOTE_SOURCE_DIR}' -mindepth 1 -maxdepth 1 -delete && sudo tar -xzf - -C '${REMOTE_SOURCE_DIR}'"

"${SCRIPT_DIR}/ssh-my-hub-api.sh" \
  "sudo MINECRAFT_ADMIN_TUNNEL_SECRET_ID='${tunnel_secret_id}' MINECRAFT_ADMIN_HOSTNAME='${admin_hostname}' CLOUDFLARE_ACCESS_TEAM_DOMAIN='${team_domain}' CLOUDFLARE_ACCESS_AUDIENCE='${access_audience}' bash -s" \
  <"${SCRIPT_DIR}/setup-minecraft-admin-runtime.sh"
