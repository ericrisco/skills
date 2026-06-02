#!/usr/bin/env bash
set -euo pipefail

# verify.sh — planetscale skill content gate. Read-only, idempotent, never writes.
#
# Checks the SKILL's own SKILL.md + references/*.md for accuracy and consistency:
#   1. The deploy-request CLI verbs (create / diff / review / deploy) are all present and
#      correctly named — the workflow is the spine of this skill.
#   2. No claim that PlanetScale "enforces foreign keys by default" (the opposite is true:
#      FKs are an opt-in, unsharded-only feature).
#   3. The serverless driver is spelled EXACTLY @planetscale/database — no invented names
#      (@planetscale/serverless, planetscale-js, @planetscale/mysql, ...).
#   4. Every fenced code block is language-tagged.
#
# Exit code: non-zero ONLY on a real content failure. An empty / clean target exits 0 with no
# false failure: if no SKILL.md is found we [skip] and pass (so this is safe to run anywhere).
#
# Portability: stock macOS bash 3.2 (no mapfile / associative arrays). Arrays are initialised
# so they expand safely under `set -u`.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

# Resolve the skill root: directory containing this script's parent (scripts/ -> skill dir).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_MD="$SKILL_DIR/SKILL.md"

if [ ! -f "$SKILL_MD" ]; then
  skip "no SKILL.md found at $SKILL_MD — nothing to check"
  exit 0
fi

# Gather the content files: SKILL.md + every references/*.md. Initialised array (set -u safe).
FILES=("$SKILL_MD")
if [ -d "$SKILL_DIR/references" ]; then
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(find "$SKILL_DIR/references" -type f -name '*.md' -print0 2>/dev/null)
fi

# Concatenate once for whole-skill greps.
ALL="$(cat "${FILES[@]}" 2>/dev/null || true)"

# ---- 1. deploy-request CLI verbs present ----
MISSING=""
for verb in create diff review deploy; do
  if ! printf '%s' "$ALL" | grep -Eq "deploy-request[[:space:]]+$verb"; then
    MISSING="$MISSING $verb"
  fi
done
if [ -n "$MISSING" ]; then
  err "missing deploy-request verb(s):$MISSING"
else
  ok "deploy-request workflow verbs present (create / diff / review / deploy)"
fi

# ---- 2. no 'enforces foreign keys by default' style claim ----
if printf '%s' "$ALL" | grep -Eiq 'enforce[sd]?[^.]*foreign[[:space:]]+key[^.]*by[[:space:]]+default'; then
  err "found a claim that PlanetScale enforces foreign keys by default — it does not (opt-in, unsharded-only)"
else
  ok "no false 'enforces foreign keys by default' claim"
fi

# ---- 3. serverless driver spelled exactly @planetscale/database ----
# Only inspect lines that actually USE the driver (import / require / from / a pkg-manager add) so
# that an anti-patterns row deliberately LISTING wrong names as a banlist is not a false failure.
USAGE="$(printf '%s' "$ALL" | grep -E '(^|[^A-Za-z])(import|require|from)([^A-Za-z]|$)|(npm|pnpm|yarn|bun)[[:space:]]+(add|install|i)[[:space:]]' || true)"
if printf '%s' "$ALL" | grep -Eq '@planetscale/'; then
  if printf '%s' "$USAGE" | grep -Eoq '@planetscale/[a-z-]+'; then
    BADPKG="$(printf '%s' "$USAGE" | grep -Eo '@planetscale/[a-z-]+' | grep -v '^@planetscale/database$' || true)"
    if [ -n "$BADPKG" ]; then
      err "imported a non-canonical @planetscale package: $(printf '%s' "$BADPKG" | sort -u | tr '\n' ' ')"
    else
      ok "serverless driver imported exactly as @planetscale/database"
    fi
  else
    ok "@planetscale/database referenced; no non-canonical import found"
  fi
else
  skip "@planetscale/* package not referenced — nothing to check"
fi
if printf '%s' "$USAGE" | grep -Eq '\bplanetscale-js\b'; then
  err "imported an invented driver name 'planetscale-js'"
fi

# ---- 4. every code fence is language-tagged ----
# Count opening fences (those followed by a language token) vs total fences. A bare ``` that opens
# a block has no trailing word; closing fences are bare too. We pair them: every other ``` is a
# closer, so opening fences are the odd-indexed ones. Simplest robust check: no opening fence may be
# bare. We walk fences in order and require odd (1st,3rd,...) fences to carry a language tag.
for f in "${FILES[@]}"; do
  bad="$(awk '
    /^```/ {
      n++
      if (n % 2 == 1) {            # opening fence
        tag = substr($0, 4)
        gsub(/[[:space:]]/, "", tag)
        if (tag == "") { print FILENAME ":" NR }
      }
    }
  ' "$f")"
  if [ -n "$bad" ]; then
    err "untagged opening code fence(s) in:"
    printf '%s\n' "$bad"
  fi
done
if [ "$EXIT" -eq 0 ]; then ok "all code fences language-tagged"; fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
