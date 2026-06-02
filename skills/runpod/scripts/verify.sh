#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/verify.sh [TARGET_DIR]   (default: .)
# Statically lints a RunPod worker directory. Pure grep/parse — no network, no RunPod
# account, never writes or installs anything. Read-only.
#
# Exit 0 = all applicable checks passed (or the target has nothing to check — an empty or
# non-worker dir is NOT a failure). Non-zero = a real problem found in present files.
# Portable to stock macOS bash 3.2: no mapfile, arrays guarded under set -u.

TARGET="${1:-.}"

if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; RESET="$(tput sgr0)"
else
  YELLOW=""; RED=""; GREEN=""; RESET=""
fi

rc=0
pass() { printf '%s[PASS]%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$1" >&2; }
fail() { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$1" >&2; rc=1; }

if [ ! -d "$TARGET" ]; then
  fail "target dir not found: $TARGET"
  exit 1
fi

# Prune patterns as a literal arg array — each token is its own quoted word, so the shell
# can never word-split them or glob-expand them against the cwd. (Unquoted `$PRUNE` here
# silently corrupts find when run from a real project root containing node_modules/.git/venv,
# emptying the file lists so every check — including the hardcoded-key check — passes.)
PRUNE=( '(' -path '*/node_modules/*' -o -path '*/.venv/*' -o -path '*/venv/*' -o -path '*/.git/*' ')' -prune -o )

# Collect file lists (newline-delimited; bash 3.2 safe — arrays only used as literal argv).
PY_FILES="$(find "$TARGET" "${PRUNE[@]}" -name '*.py' -print 2>/dev/null || true)"
DOCKERFILES="$(find "$TARGET" "${PRUNE[@]}" -iname 'Dockerfile*' -print 2>/dev/null || true)"
CONFIGS="$(find "$TARGET" "${PRUNE[@]}" \( -name '*.json' -o -name '*.yaml' -o -name '*.yml' \) -print 2>/dev/null || true)"

checked=0

# 1. Python worker: runpod.serverless.start present, and a handler with return/yield.
if [ -n "$PY_FILES" ]; then
  if printf '%s\n' "$PY_FILES" | xargs grep -lE 'runpod\.serverless\.start\(' 2>/dev/null | grep -q .; then
    checked=1
    pass "found runpod.serverless.start( in a worker file"
    # Any handler-ish def with a body that returns or yields.
    if printf '%s\n' "$PY_FILES" | xargs grep -lE '\b(return|yield)\b' 2>/dev/null | grep -q .; then
      pass "handler returns or yields a result"
    else
      fail "no handler 'return' or 'yield' found — worker would produce no output"
    fi
  else
    warn "no runpod.serverless.start( found — not a serverless worker dir, skipping worker checks"
  fi

  # 2. No hardcoded API key. Flag literal string assignments to api_key / RUNPOD_API_KEY.
  if printf '%s\n' "$PY_FILES" | xargs grep -nE '(runpod\.api_key|RUNPOD_API_KEY)[[:space:]]*=[[:space:]]*["'"'"'][A-Za-z0-9_-]+["'"'"']' 2>/dev/null | grep -q .; then
    checked=1
    fail "hardcoded API key literal found — read it from os.environ['RUNPOD_API_KEY']"
  else
    [ -n "$PY_FILES" ] && pass "no hardcoded API key literal in Python sources"
  fi
fi

# 3. Serverless config (json/yaml) — bounded max_workers + timeout keys present.
if [ -n "$CONFIGS" ]; then
  CFG_WITH_MW="$(printf '%s\n' "$CONFIGS" | xargs grep -lEi 'max[_-]?workers' 2>/dev/null || true)"
  if [ -n "$CFG_WITH_MW" ]; then
    checked=1
    # Must be a finite positive int — fail on missing/0/negative/inf.
    if printf '%s\n' "$CFG_WITH_MW" | xargs grep -hEi 'max[_-]?workers' 2>/dev/null \
        | grep -qE 'max[_-]?[Ww]orkers["'"'"']?[[:space:]]*[:=][[:space:]]*[1-9][0-9]*'; then
      pass "max_workers is a bounded positive integer"
    else
      fail "max_workers present but not a bounded positive int (set a finite ceiling)"
    fi
    if printf '%s\n' "$CFG_WITH_MW" | xargs grep -qiE 'idle[_-]?timeout' 2>/dev/null; then
      pass "idle timeout set in config"
    else
      fail "config has max_workers but no idle timeout — set it explicitly"
    fi
    if printf '%s\n' "$CFG_WITH_MW" | xargs grep -qiE 'execution[_-]?timeout' 2>/dev/null; then
      pass "execution timeout set in config"
    else
      fail "config has max_workers but no execution timeout — a hung job can run for days"
    fi
  fi
fi

# 4. Dockerfile — pinned FROM (not bare/:latest) and a CMD/ENTRYPOINT.
if [ -n "$DOCKERFILES" ]; then
  while IFS= read -r df; do
    [ -n "$df" ] || continue
    checked=1
    fromline="$(grep -iE '^[[:space:]]*FROM[[:space:]]' "$df" 2>/dev/null | head -1 || true)"
    if [ -z "$fromline" ]; then
      fail "$df: no FROM line"
    elif printf '%s' "$fromline" | grep -qiE ':latest([[:space:]]|$)'; then
      fail "$df: FROM uses :latest — pin a version tag"
    elif printf '%s' "$fromline" | grep -qE '[^[:space:]]+:[^[:space:]]+'; then
      pass "$df: FROM is pinned to a tag"
    else
      fail "$df: FROM has no tag — pin a version"
    fi
    if grep -qiE '^[[:space:]]*(CMD|ENTRYPOINT)[[:space:]]' "$df" 2>/dev/null; then
      pass "$df: has CMD/ENTRYPOINT"
    else
      fail "$df: no CMD or ENTRYPOINT — worker has no entrypoint"
    fi
  done <<EOF
$DOCKERFILES
EOF
fi

if [ "$checked" -eq 0 ]; then
  warn "no RunPod worker artifacts found in '$TARGET' — nothing to lint"
fi

if [ "$rc" -ne 0 ]; then
  printf '%sverify.sh: FAILED%s\n' "$RED" "$RESET" >&2
  exit "$rc"
fi
printf '%sverify.sh: OK%s\n' "$GREEN" "$RESET"
exit 0
