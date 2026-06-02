#!/usr/bin/env bash
# verify.sh — instagram-api
# Read-only, offline, deterministic lint of generated IG Graph API artifacts/scripts.
# Exits 0 on a clean OR empty target (no false failure). Non-zero only on a real violation.
#
# Checks:
#   1. No deprecated metric tokens REQUESTED in code/config (the trap names are
#      plays / clips_replays_count / ig_reels_aggregated_all_plays_count and a
#      bare "impressions" used as a metric value).
#   2. If a publish script is present, it references all 3 steps: /media, status_code, /media_publish
#   3. GRAPH_VERSION (or graph_version) is pinned, not blank
#
# Usage: verify.sh [TARGET_DIR]   (default: current directory)
#
# The skill's OWN source files (this dir) document the deprecated-metric trap
# in prose and in eval prompts; they are not emitted artifacts, so they are
# skipped. The lint is therefore trustworthy even when the target workspace
# contains a checked-out copy of this skill.

set -euo pipefail

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "verify: target '$TARGET' is not a directory; nothing to check."
  exit 0
fi

# Absolute path of THIS skill's root (scripts/ -> skill dir). Files inside it are
# skill source (SKILL.md, references, evals, this script), never emitted output.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Files worth scanning: scripts, configs, and ingested wiki artifacts.
# Portable across bash 3.2 (macOS) — no mapfile; newline-delimited list.
FILES=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Skip this skill's own source tree: it documents the trap on purpose.
  abs="$(cd "$(dirname "$f")" 2>/dev/null && pwd)/$(basename "$f")"
  case "$abs" in
    "$SELF_DIR"/*) continue ;;
  esac
  FILES+=("$f")
done < <(
  find "$TARGET" -type f \
    \( -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.ts' \
       -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.md' \
       -o -name '*.env' -o -name '.env' \) \
    2>/dev/null
)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "verify: no candidate files under '$TARGET'; clean by default."
  exit 0
fi

fail=0

note_fail() { echo "FAIL: $1"; fail=1; }

# --- Check 1: deprecated metric tokens ---------------------------------------
# We only flag metrics actually REQUESTED in emitted code/config, not prose that
# merely names them. A request context is a `metric=` / `"metric":` parameter
# whose value contains a deprecated token. This is scoped to artifact/code files;
# the skill's own SKILL.md (which documents the trap) is not an emitted artifact.
DEP='plays|clips_replays_count|ig_reels_aggregated_all_plays_count|impressions'
# A real request context, NOT prose. The `metric` token must sit at a genuine
# request boundary — start of line, a URL query delim (? or &), an opener
# (quote / { / ( / =), or a curl flag (-d / --data) — so an English sentence like
# "why does metric=impressions error?" (preceded by the word "does ") is ignored.
# It must then be a metric=value / "metric":"value" param whose comma-separated
# value list contains a deprecated token as a WHOLE field (the dep token ends the
# field), so mid-word matches like "displays" or "impressions_rate" don't trip.
REQ_LEAD='(^|[?&{("'"'"']|=|-d |--data[ =]|--data-urlencode )'
REQ_CTX="${REQ_LEAD}metric[\"' ]*[:=][\"' ]*([a-z0-9_]+,)*(${DEP})([,\"' &]|$)"
for f in "${FILES[@]}"; do
  case "$f" in
    *.sh|*.py|*.js|*.ts|*.json|*.yaml|*.yml|*.env|.env) ;;
    *) continue ;;  # skip free-prose .md docs; they may legitimately name the trap
  esac
  if grep -nEi "$REQ_CTX" "$f" >/dev/null 2>&1; then
    while IFS= read -r line; do
      note_fail "deprecated metric requested in $f: $line"
    done < <(grep -nEi "$REQ_CTX" "$f")
  fi
done

# Wiki artifacts (.md / .yaml) store metrics as YAML keys. Flag a deprecated
# token used AS a metric key (e.g. "  plays: 123"), which won't match prose.
KEY_CTX="^[[:space:]]+(${DEP})[[:space:]]*:"
for f in "${FILES[@]}"; do
  case "$f" in
    *.md|*.yaml|*.yml) ;;
    *) continue ;;
  esac
  if grep -nE "$KEY_CTX" "$f" >/dev/null 2>&1; then
    while IFS= read -r line; do
      note_fail "deprecated metric key in artifact $f: $line"
    done < <(grep -nE "$KEY_CTX" "$f")
  fi
done

# --- Check 2: publish scripts must reference all 3 steps ----------------------
# Only applies to executable code (.sh/.py/.js/.ts) that calls media_publish —
# not to prose/yaml docs that merely mention it.
for f in "${FILES[@]}"; do
  case "$f" in
    *.sh|*.py|*.js|*.ts) ;;
    *) continue ;;
  esac
  if grep -qE 'media_publish' "$f" 2>/dev/null; then
    grep -qE '/media([^_]|$|")' "$f" 2>/dev/null || note_fail "publish script $f missing the create step (/media)"
    grep -qE 'status_code'      "$f" 2>/dev/null || note_fail "publish script $f missing the status poll (status_code)"
    # media_publish is present by definition of entering this branch.
  fi
done

# --- Check 3: GRAPH_VERSION pinned, not blank --------------------------------
# Only enforce in files that actually mention the version variable.
for f in "${FILES[@]}"; do
  if grep -qiE 'GRAPH_VERSION|graph_version' "$f" 2>/dev/null; then
    # Flag an explicit blank/empty assignment.
    if grep -nEi 'GRAPH_VERSION[[:space:]]*[=:][[:space:]]*("")?[[:space:]]*$' "$f" >/dev/null 2>&1; then
      while IFS= read -r line; do
        note_fail "GRAPH_VERSION unpinned (blank) in $f: $line"
      done < <(grep -nEi 'GRAPH_VERSION[[:space:]]*[=:][[:space:]]*("")?[[:space:]]*$' "$f")
    fi
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "verify: violations found."
  exit 1
fi

echo "verify: OK — no deprecated metrics, publish steps complete, version pinned."
exit 0
