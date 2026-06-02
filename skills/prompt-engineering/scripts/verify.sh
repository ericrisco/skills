#!/usr/bin/env bash
set -euo pipefail

# Lints prompt artifacts in a target dir (default: cwd) against this skill.
# Read-only: greps only, never writes, never installs, no network.
# Scope: *.prompt, *.prompt.md, *.prompt.txt, prompts/**, and *.md/*.txt that
#   contain a prompt marker (a "Role:"/"Task:" block or a fenced ```prompt).
# Exit 0 = clean OR no prompt artifacts found (empty target is not a failure).
# Exit 1 = a banned vague hedge was found in prompt text.
# WARN (still exit 0) = JSON requested with no schema/contract nearby.

TARGET="${1:-.}"
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  YELLOW="$(tput setaf 3)"; RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; RESET="$(tput sgr0)"
else
  YELLOW=""; RED=""; GREEN=""; RESET=""
fi
rc=0
warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$1" >&2; }
info() { printf '[INFO] %s\n' "$1"; }
fail() { printf '%s[FAIL]%s %s\n' "$RED" "$RESET" "$1" >&2; rc=1; }

if [ ! -e "$TARGET" ]; then
  warn "target '$TARGET' does not exist; nothing to lint"
  exit 0
fi

PRUNE='-path */node_modules/* -o -path */.venv/* -o -path */venv/* -o -path */.git/* -o -path */dist/* -o -path */build/*'

# Collect candidate prompt files (newline-delimited; bash 3.2 safe, no mapfile).
candidates=""
add() { [ -n "$1" ] && candidates="${candidates}$1
"; return 0; }
while IFS= read -r f; do add "$f"; done <<EOF
$(find "$TARGET" \( $PRUNE \) -prune -o -type f \
   \( -name '*.prompt' -o -name '*.prompt.md' -o -name '*.prompt.txt' \) -print 2>/dev/null || true)
EOF
# Promote .md/.txt that carry an explicit ```prompt fence. Skill docs (SKILL.md and
# files under references/) describe prompts and quote banned phrases on purpose, so they
# are NOT prompt artifacts and must not be linted as such.
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in */SKILL.md|*/references/*) continue ;; esac
  if grep -qE '```[[:space:]]*prompt' "$f" 2>/dev/null; then add "$f"; fi
done <<EOF
$(find "$TARGET" \( $PRUNE \) -prune -o -type f \( -name '*.md' -o -name '*.txt' \) -print 2>/dev/null || true)
EOF

# De-dup.
files="$(printf '%s' "$candidates" | awk 'NF && !seen[$0]++')"
if [ -z "$files" ]; then
  info "no prompt artifacts found under '$TARGET'; nothing to lint (ok)"
  exit 0
fi

# Eval-set presence: a written prompt should ship with cases somewhere in the target.
if find "$TARGET" \( $PRUNE \) -prune -o -type f -name 'cases.y*ml' -print 2>/dev/null | grep -q . \
   || grep -rqsE '^[[:space:]]*should_trigger:|^[[:space:]]*cases:' "$TARGET" 2>/dev/null; then
  info "eval cases present near the prompt(s)"
else
  warn "prompt artifacts found but no eval cases (cases.yaml or 'cases:'/'should_trigger:') — write a small set before tuning"
fi

# Banned vague hedges in prompt text -> hard fail.
BANNED='try to|please attempt|if possible|as best you can|do your best'
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if grep -niE "$BANNED" "$f" >/dev/null 2>&1; then
    fail "vague hedge in prompt text: $f"
    grep -niE "$BANNED" "$f" | sed 's/^/    /' >&2
  fi
  # JSON requested but no schema/contract signal nearby -> warn only.
  if grep -qiE 'json' "$f" 2>/dev/null \
     && ! grep -qiE 'schema|strict|response_format|json_schema|tool[_ ]?use|responseSchema' "$f" 2>/dev/null; then
    warn "JSON requested with no schema/contract signal in $f (JSON mode guarantees valid JSON, not your schema)"
  fi
done <<EOF
$files
EOF

if [ "$rc" -eq 0 ]; then
  printf '%s[OK]%s prompt lint passed\n' "$GREEN" "$RESET"
fi
exit "$rc"
