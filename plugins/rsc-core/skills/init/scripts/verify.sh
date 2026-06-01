#!/usr/bin/env bash
#
# verify.sh — bootstrap gate for the `init` skill.
#
# WHAT IT DOES (read-only; never edits or creates a file)
#   Static checks that Phase 1 (PROFILE) actually landed in the workspace:
#     1. 02-DOCS/wiki/harness/user-profile.md exists and carries technical_level
#        and accompaniment_level lines.
#     2. 02-DOCS/wiki/harness/decisions.md exists (append-only decisions log).
#     3. Root CLAUDE.md exists and its "## Knowledge map" section links the profile.
#   Everything is detect-or-skip: a missing workspace piece is a WARNING, never a
#   failure — `init` may simply not have run yet. The script never fails the build;
#   it only reports. (No --strict mode: this is a presence check, not a CI gate.)
#
# HOW TO RUN (inside YOUR workspace, not the skills repo)
#   ./verify.sh                 # check ./ for the profile + Knowledge-map link
#   ./verify.sh --path some/dir # check a different workspace root
#
# EXIT CODES
#   0  always, unless usage is wrong (this is a warn-only presence check)
#   2  bad usage
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays, no process
# substitution; arrays avoided; everything POSIX-ish under `set -euo pipefail`.

set -euo pipefail

# --- color helpers (no escape codes when not a TTY) -------------------------
if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; skip_count=0; warn_count=0

ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; skip_count=$((skip_count + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }

usage() {
  # print the header comment block (lines 2..24), stripping the leading "# "
  sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
}

# --- arg parse --------------------------------------------------------------
ROOT="."
while [ $# -gt 0 ]; do
  case "$1" in
    --path)    ROOT="${2:?--path needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
  esac
done

if [ ! -e "$ROOT" ]; then
  printf '%sPath not found: %s%s\n' "$RED" "$ROOT" "$NC"; exit 2
fi

PROFILE="$ROOT/02-DOCS/wiki/harness/user-profile.md"
DECISIONS="$ROOT/02-DOCS/wiki/harness/decisions.md"
CLAUDE_MD="$ROOT/CLAUDE.md"

# has <file> <pattern>: true if a non-empty file contains a case-insensitive match.
has() {
  [ -s "$1" ] || return 1
  grep -iq -e "$2" "$1" 2>/dev/null
}

printf 'Checking init PROFILE artifacts under: %s\n\n' "$ROOT"

# --- 1. user profile --------------------------------------------------------
if [ ! -s "$PROFILE" ]; then
  warn "no user profile at 02-DOCS/wiki/harness/user-profile.md — run init's PROFILE phase first"
else
  ok "user profile present: $PROFILE"
  if has "$PROFILE" 'technical_level'; then
    ok "profile records technical_level"
  else
    warn "profile is missing a technical_level line"
  fi
  if has "$PROFILE" 'accompaniment_level'; then
    ok "profile records accompaniment_level"
  else
    warn "profile is missing an accompaniment_level line"
  fi
fi

# --- 2. decisions log -------------------------------------------------------
if [ ! -s "$DECISIONS" ]; then
  warn "no decisions log at 02-DOCS/wiki/harness/decisions.md — significant decisions should be appended here"
else
  ok "decisions log present: $DECISIONS"
fi

# --- 3. CLAUDE.md Knowledge map link ----------------------------------------
if [ ! -s "$CLAUDE_MD" ]; then
  warn "no root CLAUDE.md — init should create it with a '## Knowledge map' section"
else
  ok "root CLAUDE.md present"
  if has "$CLAUDE_MD" '## *Knowledge map'; then
    ok "CLAUDE.md has a '## Knowledge map' section"
    if has "$CLAUDE_MD" 'user-profile.md'; then
      ok "Knowledge map links the user profile"
    else
      warn "Knowledge map does not link 02-DOCS/wiki/harness/user-profile.md"
    fi
  else
    warn "CLAUDE.md has no '## Knowledge map' section linking the profile"
  fi
fi

# --- summary ----------------------------------------------------------------
printf '\nok=%d skip=%d warn=%d\n' "$ok_count" "$skip_count" "$warn_count"

cat <<'EOF'

Note: every finding is a presence WARNING, not a failure. If init has not run yet,
warnings are expected. Run init's PROFILE phase, then re-run this check.
EOF

exit 0
