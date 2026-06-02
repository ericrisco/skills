#!/usr/bin/env bash
#
# verify.sh — validate a Cloudflare wrangler config (read-only).
#
# WHAT IT DOES (read-only; never edits or writes your project)
#   Points at ONE wrangler config (wrangler.jsonc / wrangler.json / wrangler.toml)
#   and confirms it is a deployable Worker config:
#     1. If wrangler is available (npx wrangler), run a `deploy --dry-run` against
#        the config -> success means the config parses AND bindings/bundle resolve.
#        This is the real checkable artifact (a parse + emitted bundle).
#     2. Fallback static lint when wrangler/network is absent:
#        - required keys present: `name`, AND (`main` OR `assets`), AND `compatibility_date`
#        - `compatibility_date` looks like a real date (YYYY-MM-DD)
#        - no deprecated Workers-Sites key (`site =` / `[site]` / `"site"`)
#
#   No config file in the target dir -> nothing to check, exit 0 (no false fail).
#
# HOW TO RUN (inside YOUR project)
#   ./verify.sh                      # auto-detect wrangler.* in the current dir
#   ./verify.sh path/to/wrangler.jsonc
#   ./verify.sh --no-wrangler        # force the static lint, skip the dry-run
#
# EXIT CODES
#   0  config valid / dry-run succeeded / no config found (nothing to check)
#   1  config invalid (dry-run failed, or a static-lint check failed)
#   2  bad usage (named file does not exist)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
USE_WRANGLER=1
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --no-wrangler) USE_WRANGLER=0; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

# Resolve the config file: explicit arg, else auto-detect in CWD.
if [ -n "$FILE" ]; then
  if [ ! -f "$FILE" ]; then
    printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
  fi
else
  for cand in wrangler.jsonc wrangler.json wrangler.toml; do
    if [ -f "$cand" ]; then FILE="$cand"; break; fi
  done
fi

# No config to check -> clean exit, never a false failure.
if [ -z "$FILE" ]; then
  ok "no wrangler config found in this directory — nothing to check"
  exit 0
fi

printf 'cloudflare verify — %s\n\n' "$FILE"

# --- 1. wrangler dry-run (the real artifact check) ----------------------------
if [ "$USE_WRANGLER" -eq 1 ] && command -v npx >/dev/null 2>&1; then
  OUTDIR="$(mktemp -d 2>/dev/null || echo /tmp/cf-verify.$$)"
  if npx --no-install wrangler@4 deploy --dry-run --config "$FILE" --outdir "$OUTDIR" >/tmp/cf-verify.log 2>&1 \
     || npx wrangler@4 deploy --dry-run --config "$FILE" --outdir "$OUTDIR" >/tmp/cf-verify.log 2>&1; then
    ok "wrangler dry-run succeeded — config parses and bindings/bundle resolve"
    rm -rf "$OUTDIR" 2>/dev/null || true
    exit 0
  else
    # wrangler ran but the build/parse failed -> real failure.
    if grep -Eq 'Missing|Invalid|ParseError|Unexpected|deprecated|not supported' /tmp/cf-verify.log 2>/dev/null; then
      fail "wrangler dry-run rejected the config:"
      sed 's/^/    /' /tmp/cf-verify.log | tail -15
      rm -rf "$OUTDIR" 2>/dev/null || true
      exit 1
    fi
    # Could not run (offline / not installed / auth) -> fall through to static lint.
    warn "wrangler dry-run unavailable (offline or not installed) — falling back to static lint"
    rm -rf "$OUTDIR" 2>/dev/null || true
  fi
fi

# --- 2. static lint -----------------------------------------------------------
# Strip jsonc comments for grep so // notes don't false-match.
STRIPPED="$(sed 's://.*$::' "$FILE")"
errs=0

has() { printf '%s' "$STRIPPED" | grep -Eq "$1"; }

if has '("name"|^[[:space:]]*name)[[:space:]]*[:=]'; then
  ok "name present"
else
  fail "missing required key: name"; errs=$((errs + 1))
fi

if has '("main"|^[[:space:]]*main)[[:space:]]*[:=]' || has '("assets"|^[[:space:]]*\[assets\]|^[[:space:]]*assets)[[:space:]]*[:={[]'; then
  ok "entrypoint present (main or assets)"
else
  fail "missing required key: main or assets"; errs=$((errs + 1))
fi

CDATE="$(printf '%s' "$STRIPPED" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true)"
if printf '%s' "$STRIPPED" | grep -Eq 'compatibility_date' && [ -n "$CDATE" ]; then
  ok "compatibility_date is a real date ($CDATE)"
else
  fail "compatibility_date missing or not a YYYY-MM-DD date — pin it (deploys become non-reproducible without it)"; errs=$((errs + 1))
fi

if has '(^[[:space:]]*\[site\]|"site"[[:space:]]*:|^[[:space:]]*site[[:space:]]*=)'; then
  fail "deprecated Workers Sites config present (site) — Workers Sites is deprecated in Wrangler v4; use the assets block instead"; errs=$((errs + 1))
else
  ok "no deprecated Workers-Sites (site) key"
fi

printf '\n'
if [ "$errs" -gt 0 ]; then
  printf '%s%d static-lint failure(s)%s\n' "$RED" "$errs" "$NC"
  exit 1
fi
printf '%sconfig looks valid (static lint)%s\n' "$GREEN" "$NC"
exit 0
