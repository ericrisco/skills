#!/usr/bin/env bash
# Smoke-test of the connection to <TOOL_NAME>.
#
# Confirms the co-located .env credentials are valid by making a cheap
# read-only call. No parameters.
#
# Exit code: 0 if the API responds, ≠ 0 with detail on stderr otherwise.
#
# Usage:
#   ./test_connection.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$SCRIPT_DIR/.env"

[ -f "$ENV_PATH" ] || { echo "ERROR: missing $ENV_PATH" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
source "$ENV_PATH"
set +a

: "${<TOOL>_API_KEY:?<TOOL>_API_KEY not set in $ENV_PATH}"

# TODO: replace with the real read-only call for this provider.
# curl -fsS "https://api.<provider>.com/v1/me" \
#   -H "Authorization: Bearer ${<TOOL>_API_KEY}" \
#   | python3 -m json.tool

echo "OK — credentials valid."
