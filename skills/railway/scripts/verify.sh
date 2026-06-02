#!/usr/bin/env bash
set -eu

# Usage: bash scripts/verify.sh [DIR]
# Structurally lints a railway.json (or railway.toml) in DIR (default: cwd).
# Read-only: never writes, never installs, never calls the Railway API.
#
# Behavior:
#   - No railway.json AND no railway.toml present -> PASS (no-op). Using Railway purely
#     via CLI/dashboard is valid; absence is not a failure.
#   - railway.json present -> validate it parses as JSON, that build.builder is an allowed
#     enum, deploy.restartPolicyType is allowed, healthcheck fields are well-typed, and WARN
#     (non-fatal) on values that look like inlined secrets (secrets belong in variables).
#   - railway.toml present (and no json) -> shallow secret/enum sanity scan only (no TOML parser
#     assumed). Never fails on toml structure.
# Exit non-zero ONLY on JSON parse error or an invalid enum value. Warnings never fail.
# Portable to stock macOS bash 3.2.

DIR="${1:-.}"

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; RESET="$(tput sgr0)"
else
  YELLOW=""; RED=""; GREEN=""; RESET=""
fi

rc=0
warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$1" >&2; }
info() { printf '[INFO] %s\n' "$1"; }
fail() { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$1" >&2; rc=1; }
have() { command -v "$1" >/dev/null 2>&1; }

JSON="$DIR/railway.json"
TOML="$DIR/railway.toml"

if [ ! -f "$JSON" ] && [ ! -f "$TOML" ]; then
  info "no railway.json or railway.toml in '$DIR'; nothing to lint (CLI/dashboard-only use is valid)"
  printf '%sverify.sh: OK%s\n' "$GREEN" "$RESET"
  exit 0
fi

# --- secret heuristic: warn if a value looks like a credential ---------------
# postgres:// or mysql:// or redis:// or mongodb:// URLs with creds, sk- keys, long base64.
secret_scan() {
  f="$1"
  if grep -Eq '(postgres(ql)?|mysql|redis|mongodb)(\+srv)?://[^"[:space:]]*:[^"@[:space:]]+@' "$f"; then
    warn "$f: a value looks like a connection string with credentials — secrets belong in variables, not config"
  fi
  if grep -Eq '(sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{12,}|ghp_[A-Za-z0-9]{20,})' "$f"; then
    warn "$f: a value looks like an API key/token — move it to a Railway variable"
  fi
}

# --- JSON path ---------------------------------------------------------------
if [ -f "$JSON" ]; then
  info "linting $JSON"

  # 1. Parse + enum checks via python3 (preferred) or fall back to lenient grep.
  # Python ALWAYS exits 0 and reports outcome on a leading STATUS: line, so the
  # command substitution never trips `set -e`. STATUS is OK | PARSE | ENUM.
  if have python3; then
    py_out="$(python3 - "$JSON" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as fh:
        cfg = json.load(fh)
except Exception as e:
    print("STATUS:PARSE")
    print("  %s" % e)
    sys.exit(0)

if not isinstance(cfg, dict):
    print("STATUS:PARSE")
    print("  top-level value is not an object")
    sys.exit(0)

errs = []
build = cfg.get("build") or {}
deploy = cfg.get("deploy") or {}

b = build.get("builder")
if b is not None and b not in ("RAILPACK", "DOCKERFILE"):
    errs.append("build.builder=%r not in {RAILPACK, DOCKERFILE}" % b)

r = deploy.get("restartPolicyType")
if r is not None and r not in ("ON_FAILURE", "ALWAYS", "NEVER"):
    errs.append("deploy.restartPolicyType=%r not in {ON_FAILURE, ALWAYS, NEVER}" % r)

hp = deploy.get("healthcheckPath")
if hp is not None and not isinstance(hp, str):
    errs.append("deploy.healthcheckPath must be a string")

for nf in ("healthcheckTimeout", "restartPolicyMaxRetries", "numReplicas",
           "overlapSeconds", "drainingSeconds"):
    v = deploy.get(nf)
    if v is not None and (isinstance(v, bool) or not isinstance(v, (int, float))):
        errs.append("deploy.%s must be a number" % nf)

if errs:
    print("STATUS:ENUM")
    for e in errs:
        print("  " + e)
    sys.exit(0)
print("STATUS:OK")
sys.exit(0)
PY
)" || py_out="STATUS:PARSE
  python3 invocation failed"
    pstatus="$(printf '%s\n' "$py_out" | head -1)"
    pdetail="$(printf '%s\n' "$py_out" | tail -n +2)"
    case "$pstatus" in
      STATUS:OK)
        info "$JSON: parses; builder and restartPolicyType enums OK" ;;
      STATUS:PARSE)
        fail "$JSON: invalid JSON"
        [ -n "$pdetail" ] && printf '%s\n' "$pdetail" >&2 ;;
      STATUS:ENUM)
        [ -n "$pdetail" ] && printf '%s\n' "$pdetail" >&2
        fail "$JSON: invalid enum / field type (see above)" ;;
      *)
        fail "$JSON: unexpected lint output: $py_out" ;;
    esac
  elif have jq; then
    if ! jq empty "$JSON" >/dev/null 2>&1; then
      fail "$JSON: invalid JSON (jq could not parse)"
    else
      b="$(jq -r '.build.builder // empty' "$JSON" 2>/dev/null || true)"
      case "$b" in ""|RAILPACK|DOCKERFILE) : ;; *) fail "$JSON: build.builder=$b not in {RAILPACK, DOCKERFILE}";; esac
      r="$(jq -r '.deploy.restartPolicyType // empty' "$JSON" 2>/dev/null || true)"
      case "$r" in ""|ON_FAILURE|ALWAYS|NEVER) : ;; *) fail "$JSON: deploy.restartPolicyType=$r not in {ON_FAILURE, ALWAYS, NEVER}";; esac
      [ "$rc" -eq 0 ] && info "$JSON: parses (jq); enums OK"
    fi
  else
    warn "neither python3 nor jq found; skipping JSON parse/enum checks (run on a host with one)"
  fi

  secret_scan "$JSON"
fi

# --- TOML path (only if no JSON) ---------------------------------------------
if [ ! -f "$JSON" ] && [ -f "$TOML" ]; then
  info "linting $TOML (shallow: no TOML parser assumed)"
  b="$(grep -E '^[[:space:]]*builder[[:space:]]*=' "$TOML" | head -1 | sed 's/.*=[[:space:]]*//; s/"//g; s/[[:space:]]*$//' || true)"
  case "$b" in
    ""|RAILPACK|DOCKERFILE) [ -n "$b" ] && info "builder=$b OK" || : ;;
    *) fail "$TOML: builder=$b not in {RAILPACK, DOCKERFILE}";;
  esac
  r="$(grep -E '^[[:space:]]*restartPolicyType[[:space:]]*=' "$TOML" | head -1 | sed 's/.*=[[:space:]]*//; s/"//g; s/[[:space:]]*$//' || true)"
  case "$r" in
    ""|ON_FAILURE|ALWAYS|NEVER) [ -n "$r" ] && info "restartPolicyType=$r OK" || : ;;
    *) fail "$TOML: restartPolicyType=$r not in {ON_FAILURE, ALWAYS, NEVER}";;
  esac
  secret_scan "$TOML"
fi

if [ "$rc" -ne 0 ]; then
  printf '%sverify.sh: FAILED%s\n' "$RED" "$RESET" >&2
  exit "$rc"
fi
printf '%sverify.sh: OK%s\n' "$GREEN" "$RESET"
exit 0
