#!/usr/bin/env bash
set -euo pipefail

COMPARTMENT_ID="${COMPARTMENT_ID:-ocid1.compartment.oc1..aaaaaaaaaml3tibap7lgvl6i5qwp3hnaoa3aufft565leyybzr77pbvngika}"
INSTANCE_ID="${INSTANCE_ID:-ocid1.instance.oc1.ap-chuncheon-1.an4w4ljrcanazoacozhnj7teihrxghx23466tnia4x7cmjwgotzgiplljt5a}"
DISPLAY_NAME="${DISPLAY_NAME:-my-hub-run-command}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
WAIT_SECONDS="${WAIT_SECONDS:-600}"
POLL_SECONDS="${POLL_SECONDS:-5}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required."
}

usage() {
  cat <<'EOF'
Usage:
  run-my-hub-api-command.sh --script-file <path>
  run-my-hub-api-command.sh --command '<bash script>'

Runs a bash script on the my-hub API VM through OCI Run Command.

Environment overrides:
  COMPARTMENT_ID, INSTANCE_ID, DISPLAY_NAME, TIMEOUT_SECONDS, WAIT_SECONDS, POLL_SECONDS
EOF
}

SCRIPT_TEXT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --script-file)
      [[ $# -ge 2 ]] || die "--script-file requires a path."
      SCRIPT_TEXT="$(cat "$2")"
      shift 2
      ;;
    --command)
      [[ $# -ge 2 ]] || die "--command requires text."
      SCRIPT_TEXT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "${SCRIPT_TEXT}" ]] || die "provide --script-file or --command."

require_command oci
require_command jq
require_command shasum

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/my-hub-run-command.XXXXXX")"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

SCRIPT_FILE="${WORK_DIR}/script.sh"
TARGET_FILE="${WORK_DIR}/target.json"
CONTENT_FILE="${WORK_DIR}/content.json"

printf '%s\n' "$SCRIPT_TEXT" >"$SCRIPT_FILE"
SCRIPT_SHA="$(shasum -a 256 "$SCRIPT_FILE" | awk '{print $1}')"

jq -n --arg instanceId "$INSTANCE_ID" '{instanceId: $instanceId}' >"$TARGET_FILE"
jq -n \
  --rawfile text "$SCRIPT_FILE" \
  --arg sha "$SCRIPT_SHA" \
  '{
    source: {
      sourceType: "TEXT",
      text: $text,
      textSha256: $sha
    },
    output: {
      outputType: "TEXT"
    }
  }' >"$CONTENT_FILE"

COMMAND_ID="$(
  oci instance-agent command create \
    --compartment-id "$COMPARTMENT_ID" \
    --target "file://${TARGET_FILE}" \
    --content "file://${CONTENT_FILE}" \
    --display-name "$DISPLAY_NAME" \
    --timeout-in-seconds "$TIMEOUT_SECONDS" \
    --query 'data.id' \
    --raw-output
)"

printf 'Run Command submitted: %s\n' "$COMMAND_ID"

deadline=$((SECONDS + WAIT_SECONDS))
state=""
while (( SECONDS < deadline )); do
  state="$(
    oci instance-agent command-execution get \
      --instance-id "$INSTANCE_ID" \
      --command-id "$COMMAND_ID" \
      --query 'data."lifecycle-state"' \
      --raw-output 2>/dev/null || true
  )"

  printf 'state=%s\n' "${state:-PENDING}"
  case "$state" in
    SUCCEEDED|FAILED|TIMED_OUT|CANCELED)
      break
      ;;
  esac

  sleep "$POLL_SECONDS"
done

oci instance-agent command-execution get \
  --instance-id "$INSTANCE_ID" \
  --command-id "$COMMAND_ID"

[[ "$state" == "SUCCEEDED" ]] || die "Run Command did not succeed: ${state:-PENDING}"
