#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NAME
#   verify.sh — security-scan gate over security-scan-report.json
#
# USAGE
#   ./verify.sh [path/to/security-scan-report.json]
#   Defaults to ./security-scan-report.json in the current directory.
#
# WHAT IT DOES (read-only — never writes, never auto-fixes, never runs scanners)
#   1. Locates the report. If it is ABSENT, exits 0 with a notice — the gate is
#      vacuously clean (nothing scanned yet is not a failure).
#   2. Parses it as JSON (requires jq).
#   3. Validates the schema: schemaVersion, summary object, findings array, and
#      that each finding carries class/ruleId/path/severity/status.
#   4. Enforces the gate: any finding with status "open" at severity "critical"
#      fails (exit 1). With STRICT=1, "open" + "high" also fails.
#
#   An empty/clean report (no open criticals, or an empty findings array)
#   exits 0 — no false failure.
#
# ENV TOGGLES
#   STRICT=1     Also fail on open HIGH findings (default: criticals only).
#   NO_COLOR=1   Disable ANSI color.
#
# EXIT CODES
#   0  Clean: report missing, empty, or no open critical (/high under STRICT).
#   1  At least one open critical (or open high under STRICT).
#   2  Usage / schema / tooling error (jq missing, malformed JSON, bad schema).
# ============================================================================

REPORT="${1:-./security-scan-report.json}"
STRICT="${STRICT:-0}"

if [ -n "${NO_COLOR:-}" ]; then
  RED=""; YEL=""; GRN=""; RST=""
else
  RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
fi

note() { printf '%s\n' "$*" >&2; }

# --- 1. report absent => vacuously clean -----------------------------------
if [ ! -e "$REPORT" ]; then
  note "${YEL}notice:${RST} no report at '$REPORT' — nothing to gate. Clean."
  exit 0
fi

# --- tooling ---------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  note "${RED}error:${RST} jq is required to validate the report."
  exit 2
fi

# --- 2. valid JSON ---------------------------------------------------------
if ! jq -e . "$REPORT" >/dev/null 2>&1; then
  note "${RED}error:${RST} '$REPORT' is not valid JSON."
  exit 2
fi

# --- 3. schema -------------------------------------------------------------
schema_ok=$(jq -e '
  (has("schemaVersion"))
  and (has("summary") and (.summary | type == "object"))
  and (has("findings") and (.findings | type == "array"))
  and (
    .findings
    | all(
        (has("class")) and (has("ruleId")) and (has("path"))
        and (has("severity")) and (has("status"))
      )
  )
' "$REPORT" 2>/dev/null || echo "false")

if [ "$schema_ok" != "true" ]; then
  note "${RED}error:${RST} '$REPORT' does not conform to the schema"
  note "       (need schemaVersion, summary{}, findings[] with"
  note "        class/ruleId/path/severity/status on every finding)."
  exit 2
fi

# --- 4. gate ---------------------------------------------------------------
open_crit=$(jq '[.findings[] | select(.status == "open" and .severity == "critical")] | length' "$REPORT")
open_high=$(jq '[.findings[] | select(.status == "open" and .severity == "high")] | length' "$REPORT")
total=$(jq '.findings | length' "$REPORT")
suppressed=$(jq '[.findings[] | select(.status == "suppressed")] | length' "$REPORT")

note "Report: $REPORT  (findings: ${total}, suppressed: ${suppressed}, open-critical: ${open_crit}, open-high: ${open_high})"

fail=0
if [ "$open_crit" -gt 0 ]; then
  note "${RED}FAIL:${RST} ${open_crit} open CRITICAL finding(s) — resolve or suppress with justification before merge."
  jq -r '.findings[] | select(.status=="open" and .severity=="critical") | "  - [\(.class)] \(.ruleId)  \(.path)  \(.title // "")"' "$REPORT" >&2
  fail=1
fi
if [ "$STRICT" = "1" ] && [ "$open_high" -gt 0 ]; then
  note "${RED}FAIL (STRICT):${RST} ${open_high} open HIGH finding(s)."
  jq -r '.findings[] | select(.status=="open" and .severity=="high") | "  - [\(.class)] \(.ruleId)  \(.path)  \(.title // "")"' "$REPORT" >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  note "${GRN}PASS:${RST} no open critical$([ "$STRICT" = "1" ] && echo "/high") findings."
  exit 0
fi
exit 1
