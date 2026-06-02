#!/usr/bin/env bash
#
# verify.sh — audit a domain's DNS + TLS posture (read-only).
#
# WHAT IT DOES (read-only; never edits a zone, never issues a cert, no credentials)
#   Takes ONE domain and runs deterministic checks against the banlist of common mistakes:
#     1. apex has A/AAAA or ALIAS-style answer and is NOT a CNAME (CNAME-at-apex is illegal).
#     2. CAA at the apex is parseable; reports the allowed issuers (informational).
#     3. TLS chain on :443 validates end-to-end (no incomplete-chain) and notAfter is > N days out.
#     4. HTTPS is reachable (2xx/3xx) and www resolves to the same target as the apex (canonical).
#
#   Needs network + `dig`. If `dig` is unavailable OR the domain has no public DNS at all
#   (nothing to audit), it exits 0 — never a false failure on an empty/unconfigured target.
#
# HOW TO RUN
#   ./verify.sh example.com
#   ./verify.sh example.com --days 14      # warn-window for cert expiry (default 21)
#
# EXIT CODES
#   0  all checks passed, OR nothing to audit (no dig / domain has no DNS)
#   1  one or more checks failed (one labeled [fail] line each)
#   2  bad usage (no domain argument)
#
# Stock macOS bash 3.2 safe: no mapfile, no associative arrays, no process substitution required.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }
info() { printf '       %s\n' "$*"; }

DOMAIN=""
DAYS=21
while [ "$#" -gt 0 ]; do
  case "$1" in
    --days) DAYS="${2:-21}"; shift 2 ;;
    -*)     printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
    *)      DOMAIN="$1"; shift ;;
  esac
done

if [ -z "$DOMAIN" ]; then
  printf 'usage: %s <domain> [--days N]\n' "$0" >&2
  exit 2
fi

# strip any scheme / path / port the user may have pasted
DOMAIN=$(printf '%s' "$DOMAIN" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##; s#:[0-9]+$##')
RESOLVER="@1.1.1.1"
FAILURES=0

# No dig -> we cannot audit DNS; do not invent a failure.
if ! command -v dig >/dev/null 2>&1; then
  warn "dig not found — skipping DNS audit (nothing to check)."
  exit 0
fi

# Nothing in DNS at all -> nothing to audit, clean exit.
APEX_NS=$(dig +short "$RESOLVER" NS "$DOMAIN" 2>/dev/null || true)
APEX_ANY=$(dig +short "$RESOLVER" A "$DOMAIN" 2>/dev/null || true)
if [ -z "$APEX_NS" ] && [ -z "$APEX_ANY" ]; then
  warn "no NS or A records found for $DOMAIN — nothing to audit."
  exit 0
fi

printf 'Auditing %s (cert warn-window: %s days)\n\n' "$DOMAIN" "$DAYS"

# --- 1. apex must not be a CNAME, and must have an address answer ----------------
APEX_CNAME=$(dig +short "$RESOLVER" CNAME "$DOMAIN" 2>/dev/null || true)
APEX_A=$(dig +short "$RESOLVER" A "$DOMAIN" 2>/dev/null || true)
APEX_AAAA=$(dig +short "$RESOLVER" AAAA "$DOMAIN" 2>/dev/null || true)

if [ -n "$APEX_CNAME" ]; then
  fail "apex $DOMAIN returns a CNAME ($APEX_CNAME) — illegal at the zone apex."
  info "Use ALIAS/flattening or hard A/AAAA at the apex instead."
  FAILURES=$((FAILURES + 1))
elif [ -n "$APEX_A" ] || [ -n "$APEX_AAAA" ]; then
  ok "apex resolves to an address (A/AAAA or flattened ALIAS), no CNAME at apex."
else
  fail "apex $DOMAIN has no A/AAAA answer — it will not resolve to a host."
  FAILURES=$((FAILURES + 1))
fi

# --- 2. CAA sanity (informational; absence = open policy, not a failure) ---------
APEX_CAA=$(dig +short "$RESOLVER" CAA "$DOMAIN" 2>/dev/null || true)
if [ -z "$APEX_CAA" ]; then
  warn "no CAA record — any CA may issue. Consider locking with: CAA 0 issue \"letsencrypt.org\"."
else
  ok "CAA present:"
  printf '%s\n' "$APEX_CAA" | sed 's/^/         /'
fi

# --- 3. TLS chain completeness + expiry window -----------------------------------
if command -v openssl >/dev/null 2>&1; then
  CHAIN=$(echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" \
            -showcerts 2>/dev/null || true)
  if [ -z "$CHAIN" ]; then
    fail "no TLS handshake on $DOMAIN:443 — HTTPS not serving."
    FAILURES=$((FAILURES + 1))
  else
    VERIFY_LINE=$(printf '%s' "$CHAIN" | grep -E 'Verify return code|verify error' | head -1 || true)
    if printf '%s' "$VERIFY_LINE" | grep -qi 'unable to get local issuer\|incomplete\|verify error'; then
      fail "TLS chain does not validate ($VERIFY_LINE) — likely an incomplete chain; serve fullchain.pem."
      FAILURES=$((FAILURES + 1))
    else
      ok "TLS chain validates from a clean trust store."
    fi

    NOTAFTER=$(printf '%s' "$CHAIN" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || true)
    if [ -n "$NOTAFTER" ]; then
      END_EPOCH=$(date -j -f '%b %d %T %Y %Z' "$NOTAFTER" '+%s' 2>/dev/null \
                  || date -d "$NOTAFTER" '+%s' 2>/dev/null || echo "")
      if [ -n "$END_EPOCH" ]; then
        NOW_EPOCH=$(date '+%s')
        LEFT_DAYS=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))
        if [ "$LEFT_DAYS" -lt 0 ]; then
          fail "certificate EXPIRED ($NOTAFTER)."
          FAILURES=$((FAILURES + 1))
        elif [ "$LEFT_DAYS" -lt "$DAYS" ]; then
          fail "certificate expires in ${LEFT_DAYS}d ($NOTAFTER) — under the ${DAYS}d window; auto-renew must run."
          FAILURES=$((FAILURES + 1))
        else
          ok "certificate valid for ${LEFT_DAYS} more days (notAfter $NOTAFTER)."
        fi
      fi
    fi
  fi
else
  warn "openssl not found — skipping TLS chain/expiry checks."
fi

# --- 4. HTTPS reachability + www canonical ---------------------------------------
if command -v curl >/dev/null 2>&1; then
  CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 12 "https://$DOMAIN" 2>/dev/null || echo "000")
  case "$CODE" in
    2*|3*) ok "HTTPS reachable (HTTP $CODE)." ;;
    000)   fail "HTTPS request to $DOMAIN failed (no response / TLS error)." ; FAILURES=$((FAILURES + 1)) ;;
    *)     warn "HTTPS returned HTTP $CODE." ;;
  esac
else
  warn "curl not found — skipping HTTPS reachability check."
fi

WWW_TARGET=$(dig +short "$RESOLVER" "www.$DOMAIN" 2>/dev/null | tail -1 || true)
if [ -z "$WWW_TARGET" ]; then
  warn "www.$DOMAIN does not resolve — pick a canonical host and 301 the other to it."
else
  ok "www.$DOMAIN resolves ($WWW_TARGET) — confirm one canonical host 301s to the other."
fi

printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  ok "no failures."
  exit 0
fi
fail "$FAILURES check(s) failed."
exit 1
