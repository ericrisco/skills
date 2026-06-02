#!/usr/bin/env bash
set -euo pipefail

# verify.sh — coolify skill gate. Run from your PROJECT root (or this skill's dir).
#
# Static, read-only lint of any committed docker-compose artifact (docker-compose.yml/.yaml,
# compose.yml/.yaml) plus a check that this skill's SKILL.md documents the canonical port matrix.
# It NEVER writes, NEVER connects to the network, and NEVER deploys.
#
# Per compose file it asserts:
#   (a) no hardcoded secret literal — values for *PASSWORD*/*SECRET*/*TOKEN*/*_KEY*/DATABASE_URL
#       must be env-refs (${...}) , not inline literals.
#   (b) any database service (postgres/mysql/mariadb/mongo) is backed by a NAMED volume (data-loss guard).
#   (c) at least one healthcheck: present.
#   (d) no floating ":latest" image tag, and no image without an explicit tag (also "floating").
# And once: SKILL.md mentions every canonical port (8000 80 443 6001 6002).
#
# Exit code: non-zero ONLY on a hard failure (a/b/c/d or a missing port). An EMPTY/CLEAN target
# (no compose files found) exits 0 with a skip — never a false failure. Missing optional context
# (no SKILL.md to check) is advisory, not fatal.
#
# Portability: stock macOS bash 3.2 (no mapfile, no associative arrays). Arrays are initialised so
# they expand safely under `set -u`.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- discover compose files (skip vendor dirs) ---
COMPOSE_FILES=()
while IFS= read -r -d '' f; do
  COMPOSE_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/.venv/*' \) -prune -o \
    -type f \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \
               -o -name 'compose.yml' -o -name 'compose.yaml' \) -print0 2>/dev/null
)

lint_compose() {
  file="$1"
  base="$(basename "$file")"

  # (a) hardcoded secrets: a *PASSWORD/SECRET/TOKEN/_KEY/DATABASE_URL key whose value is NOT a ${...} ref
  #     and is not empty. We look at "key: value" pairs (env blocks are key: value in compose).
  if grep -Eiq '^[[:space:]]*[A-Za-z_]*(password|secret|token|_key|database_url)[A-Za-z_]*[[:space:]]*:[[:space:]]*[^$[:space:]"'"'"'].*' "$file"; then
    # exclude the case where the value is an env-ref like ${FOO}
    if grep -Ei '^[[:space:]]*[A-Za-z_]*(password|secret|token|_key|database_url)[A-Za-z_]*[[:space:]]*:[[:space:]]*' "$file" \
       | grep -Eiv ':[[:space:]]*("?\$\{|\$[A-Za-z_])' \
       | grep -Eq ':[[:space:]]*[^[:space:]$]'; then
      err "$base: hardcoded secret literal — use an env-ref (\${VAR}) injected by Coolify, not an inline value"
    fi
  fi

  # (b) named volume for any database service. If a db image is present, require a top-level `volumes:` map.
  if grep -Eiq 'image:[[:space:]]*("?)(postgres|mysql|mariadb|mongo)' "$file"; then
    if grep -Eq '^volumes:' "$file"; then
      ok "$base: database service has a named volume declaration"
    else
      err "$base: database service without a named volume — data is wiped on recreate"
    fi
  fi

  # (c) at least one healthcheck
  if grep -Eq '^[[:space:]]*healthcheck:' "$file"; then
    ok "$base: healthcheck present"
  else
    err "$base: no healthcheck: — Coolify/Traefik can't tell when the container is ready"
  fi

  # (d) floating tags: image: foo:latest, or image: foo with no tag at all
  while IFS= read -r line; do
    img="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*image:[[:space:]]*"?//; s/"?[[:space:]]*$//')"
    case "$img" in
      \$*) : ;;                                   # env-ref image, skip
      *:latest) err "$base: floating ':latest' tag on image '$img' — pin a tag or digest" ;;
      *@sha256:*) : ;;                            # digest-pinned, fine
      *:*) : ;;                                   # has an explicit tag, fine
      *) err "$base: image '$img' has no tag (floating) — pin a tag or digest" ;;
    esac
  done < <(grep -E '^[[:space:]]*image:[[:space:]]*' "$file" || true)
}

if [ "${#COMPOSE_FILES[@]}" -eq 0 ]; then
  skip "no docker-compose files found — nothing to lint (clean)"
else
  for f in "${COMPOSE_FILES[@]}"; do
    lint_compose "$f"
  done
fi

# --- port matrix documented in SKILL.md (look next to this script, then under ROOT) ---
SKILL_MD=""
if [ -f "$SCRIPT_DIR/../SKILL.md" ]; then
  SKILL_MD="$SCRIPT_DIR/../SKILL.md"
else
  cand="$(find "$ROOT" -type f -name 'SKILL.md' -path '*coolify*' -print 2>/dev/null | head -n1 || true)"
  [ -n "$cand" ] && SKILL_MD="$cand"
fi

if [ -n "$SKILL_MD" ] && [ -f "$SKILL_MD" ]; then
  missing=""
  for p in 8000 80 443 6001 6002; do
    grep -Eq "(^|[^0-9])$p([^0-9]|$)" "$SKILL_MD" || missing="$missing $p"
  done
  if [ -n "$missing" ]; then
    err "SKILL.md missing canonical port(s):$missing"
  else
    ok "SKILL.md documents the canonical port matrix (8000/80/443/6001/6002)"
  fi
else
  skip "no coolify SKILL.md found to check the port matrix"
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
