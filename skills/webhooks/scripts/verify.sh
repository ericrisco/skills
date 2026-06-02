#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NAME
#   verify.sh — webhooks inbound-handler invariant linter
#
# USAGE
#   ./verify.sh [PATH]
#   Run from the ROOT of YOUR project (the repo containing your webhook
#   handler), NOT from the skills repository. PATH defaults to the current
#   directory. Read-only: it never writes, never fixes, never installs.
#
# WHAT IT DOES
#   Heuristically scans candidate webhook-handler files for the five inbound
#   invariants and prints PASS / WARN / FAIL per file:
#     1. raw body is used for HMAC verification (flags parsed-body verify)
#     2. a constant-time signature compare is present (flags ==/=== on a sig)
#     3. a timestamp / tolerance check exists
#     4. the signing secret comes from env, not a string literal
#     5. a dedupe step references a stable event id
#
#   It is a HEURISTIC (grep-based), advisory not a compiler. A WARN means
#   "no evidence found", which is not necessarily a bug.
#
# EXIT CODES
#   0  no candidate files found (clean/empty tree), OR all candidates PASS
#      every hard check. WARN never fails the run.
#   1  a candidate file FAILS a hard check (parsed-body verify, ==/=== on a
#      signature, or a hard-coded secret).
# ============================================================================

TARGET="${1:-.}"

if [ ! -e "$TARGET" ]; then
  echo "verify.sh: target not found: $TARGET" >&2
  exit 0
fi

# ----------------------------------------------------------------------------
# Find candidate handler files: source files that look like they touch
# webhooks / HMAC signatures. Prune dependency + VCS dirs. NUL-delimited so
# paths with spaces survive.
# ----------------------------------------------------------------------------
# Portable (bash 3.2 / macOS + GNU) NUL-safe array build — no mapfile, no
# process substitution, and -name globs instead of -iregex (BSD/GNU agree on
# globs). We stage the NUL-delimited find output in a temp file, then read it.
LISTFILE="$(mktemp -t webhooks-verify.XXXXXX 2>/dev/null || mktemp)"
trap 'rm -f "$LISTFILE"' EXIT

find "$TARGET" \
  \( -name node_modules -o -name .git -o -name dist -o -name build \
     -o -name vendor -o -name .venv -o -name venv -o -name __pycache__ \) -prune \
  -o -type f \( -name '*.js' -o -name '*.cjs' -o -name '*.mjs' \
                -o -name '*.ts' -o -name '*.tsx' -o -name '*.py' \
                -o -name '*.go' -o -name '*.rb' -o -name '*.php' \) \
  -print0 > "$LISTFILE" 2>/dev/null || true

CANDIDATES=()
while IFS= read -r -d '' f; do
  if grep -Eilq 'webhook|x-hub-signature|stripe-signature|x-slack-signature|hmac' "$f" 2>/dev/null; then
    CANDIDATES+=("$f")
  fi
done < "$LISTFILE"

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  echo "PASS  no webhook-handler files found under '$TARGET' — nothing to lint."
  exit 0
fi

C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
say_pass() { printf '%sPASS%s  %s\n' "$C_GRN" "$C_RESET" "$1"; }
say_warn() { printf '%sWARN%s  %s\n' "$C_YEL" "$C_RESET" "$1"; }
say_fail() { printf '%sFAIL%s  %s\n' "$C_RED" "$C_RESET" "$1"; }

# matches lines, case-insensitive, fixed cost
has() { grep -Eiq "$1" "$2" 2>/dev/null; }

exit_code=0

for f in "${CANDIDATES[@]}"; do
  echo "── $f"

  # 1. raw body used / parsed-body verify NOT used --------------------------
  #    Hard fail if we see a signature/HMAC built from an obviously parsed
  #    body (JSON.stringify(req.body), JSON.parse(...) fed to the digest).
  if has 'createHmac|hmac\.new|OpenSSL::HMAC|hash_hmac|hmac\.New' "$f"; then
    if has 'JSON\.stringify\s*\(\s*req\.body|JSON\.stringify\s*\(\s*request\.body' "$f"; then
      say_fail "(1) HMAC appears to run over re-serialized parsed body (JSON.stringify(req.body)) — verify over the raw bytes"
      exit_code=1
    elif has 'rawbody|raw_body|req\.text\(\)|request\.body\(\)|c\.req\.text\(\)|arraybuffer|express\.raw|isbase64encoded' "$f"; then
      say_pass "(1) raw body captured for HMAC verification"
    else
      say_warn "(1) HMAC found but no clear raw-body capture — confirm you verify over the raw bytes, not parsed JSON"
    fi
  else
    say_warn "(1) no HMAC call detected in this file"
  fi

  # 2. constant-time compare -----------------------------------------------
  if has 'timingsafeequal|compare_digest|hmac\.equal|secure_compare|hash_equals' "$f"; then
    say_pass "(2) constant-time signature compare present"
  elif has 'signature\s*===|signature\s*==|sig\s*===|sig\s*==|=== *expectedsig|== *expectedsig' "$f"; then
    say_fail "(2) signature compared with ==/=== — timing leak; use a constant-time comparator"
    exit_code=1
  else
    say_warn "(2) no constant-time compare detected — confirm timingSafeEqual / compare_digest is used"
  fi

  # 3. timestamp / tolerance check -----------------------------------------
  if has 'webhook-timestamp|x-slack-request-timestamp|timestamp' "$f" \
     && has '300|5 *\* *60|tolerance|skew|maxage|max_age|window' "$f"; then
    say_pass "(3) timestamp tolerance / replay window check present"
  else
    say_warn "(3) no timestamp tolerance check detected — reject events outside ~5 minutes"
  fi

  # 4. secret from env, not a literal --------------------------------------
  if has 'webhook_secret\s*=\s*["'\''][a-z0-9_]{12,}|signing_secret\s*=\s*["'\''][a-z0-9_]{12,}|whsec_[a-z0-9]' "$f"; then
    say_fail "(4) signing secret looks hard-coded — read it from an environment variable"
    exit_code=1
  elif has 'process\.env|os\.environ|os\.getenv|env\(|ENV\[' "$f"; then
    say_pass "(4) signing secret sourced from environment"
  else
    say_warn "(4) no env lookup detected — confirm the signing secret comes from env"
  fi

  # 5. dedupe on event id ---------------------------------------------------
  if has 'unique|setnx|set .* nx|already.processed|already.seen|seen_event|idempoten|webhook-id|event\.id|delivery.id' "$f"; then
    say_pass "(5) dedupe / idempotency on an event id present"
  else
    say_warn "(5) no dedupe step detected — dedupe on the provider's stable event id (UNIQUE / SETNX)"
  fi
done

echo
if [ "$exit_code" -eq 0 ]; then
  echo "${C_GRN}verify.sh: no hard failures.${C_RESET} WARN lines are advisory — review them."
else
  echo "${C_RED}verify.sh: hard failures found.${C_RESET} Fix the FAIL lines above."
fi
exit "$exit_code"
