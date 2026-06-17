#!/usr/bin/env bash
# Push a PEM edition JSON payload to Aptoma Print Edition Manager.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="${SCRIPT_DIR}/config/pem.env"
DEFAULT_BASE_URL="https://print-edition-manager.aptoma.no"

usage() {
  cat <<'EOF'
Usage: pem-push.sh [options] <payload.json>

Send a Print Edition Manager (PEM) import payload. Create and update are the same
operation: POST with the same editionName updates the edition.

Options:
  -c, --config FILE   Config file (default: config/pem.env)
  --dry-run           Validate only (default)
  --live              Apply changes (dryRun=false)
  --edition           Force POST /edition (single object)
  --editions          Force POST /editions (array of editions, sharing)
  --auto              Pick /edition vs /editions from JSON root (default)
  -h, --help          Show this help

Examples:
  ./pem-push.sh payloads/edition-shared-pages.json
  ./pem-push.sh --live payloads/my-edition.json
  ./pem-push.sh --editions --dry-run payloads/edition-shared-pages.json

Config: copy config/pem.env.sample to config/pem.env and set APTOM_PEM_API_KEY.
EOF
}

die() {
  echo "pem-push: $*" >&2
  exit 1
}

load_config() {
  local config_file="$1"
  [[ -f "$config_file" ]] || die "config not found: $config_file (copy config/pem.env.sample to config/pem.env)"

  # shellcheck disable=SC1090
  source "$config_file"

  [[ -n "${APTOM_PEM_API_KEY:-}" ]] || die "APTOM_PEM_API_KEY is not set in $config_file"
  PEM_BASE_URL="${APTOM_PEM_BASE_URL:-$DEFAULT_BASE_URL}"
}

detect_endpoint_mode() {
  local payload_file="$1"
  local first_char

  first_char="$(
    tr -d '[:space:]' <"$payload_file" | head -c 1 || true
  )"

  case "$first_char" in
    "[") echo "editions" ;;
    "{") echo "edition" ;;
    *)
      die "cannot detect payload type from $payload_file (expected JSON object or array)"
      ;;
  esac
}

config_file="$DEFAULT_CONFIG"
dry_run="true"
endpoint_mode="auto"
payload_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c | --config)
      [[ $# -ge 2 ]] || die "missing value for $1"
      config_file="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --live)
      dry_run="false"
      shift
      ;;
    --edition)
      endpoint_mode="edition"
      shift
      ;;
    --editions)
      endpoint_mode="editions"
      shift
      ;;
    --auto)
      endpoint_mode="auto"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1 (try --help)"
      ;;
    *)
      [[ -z "$payload_file" ]] || die "unexpected argument: $1"
      payload_file="$1"
      shift
      ;;
  esac
done

[[ -n "$payload_file" ]] || {
  usage >&2
  exit 1
}

[[ -f "$payload_file" ]] || die "payload file not found: $payload_file"

load_config "$config_file"

if [[ "$endpoint_mode" == "auto" ]]; then
  endpoint_mode="$(detect_endpoint_mode "$payload_file")"
fi

case "$endpoint_mode" in
  edition) path="/edition" ;;
  editions) path="/editions" ;;
  *) die "internal error: invalid endpoint mode: $endpoint_mode" ;;
esac

url="${PEM_BASE_URL%/}${path}?dryRun=${dry_run}"

echo "pem-push: POST ${url}" >&2
echo "pem-push: payload ${payload_file}" >&2

response_file="$(mktemp)"
http_code="$(
  curl -sS -w "%{http_code}" -o "$response_file" \
    -X POST "$url" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${APTOM_PEM_API_KEY}" \
    --data-binary "@${payload_file}"
)"

echo "pem-push: HTTP ${http_code}" >&2

if command -v jq >/dev/null 2>&1; then
  jq . <"$response_file" || cat "$response_file"
else
  cat "$response_file"
fi

rm -f "$response_file"

if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
  exit 0
fi

if [[ "$http_code" == "409" ]]; then
  echo "pem-push: 409 — another import may be running for this edition; retry later" >&2
fi

exit 1
