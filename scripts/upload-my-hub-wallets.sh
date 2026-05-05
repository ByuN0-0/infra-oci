#!/usr/bin/env bash
set -euo pipefail

BUCKET_NAME="${BUCKET_NAME:-shared-storage}"
NAMESPACE="${NAMESPACE:-}"
ADW_WALLET_FILE="${ADW_WALLET_FILE:-/private/tmp/Wallet_MYHUBADW.zip}"
AJD_WALLET_FILE="${AJD_WALLET_FILE:-/private/tmp/Wallet_MYHUBJSON.zip}"
ADW_OBJECT_NAME="${ADW_OBJECT_NAME:-wallets/Wallet_MYHUBADW.zip}"
AJD_OBJECT_NAME="${AJD_OBJECT_NAME:-wallets/Wallet_MYHUBJSON.zip}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required."
}

put_wallet() {
  local source_file="$1"
  local object_name="$2"

  [[ -f "$source_file" ]] || die "$source_file does not exist."

  oci os object put \
    --namespace "$NAMESPACE" \
    --bucket-name "$BUCKET_NAME" \
    --name "$object_name" \
    --file "$source_file" \
    --force
}

main() {
  require_command oci

  if [[ -z "$NAMESPACE" ]]; then
    NAMESPACE="$(oci os ns get --query data --raw-output)"
  fi

  put_wallet "$ADW_WALLET_FILE" "$ADW_OBJECT_NAME"
  put_wallet "$AJD_WALLET_FILE" "$AJD_OBJECT_NAME"

  cat <<EOF
Uploaded wallet zips.

Bucket:
  $BUCKET_NAME

Objects:
  $ADW_OBJECT_NAME
  $AJD_OBJECT_NAME
EOF
}

main "$@"
