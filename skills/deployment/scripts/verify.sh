#!/usr/bin/env bash
# verify.sh — deployment gate. Run inside YOUR project; CI runs the same file (parity).
#
# Usage:
#   bash scripts/verify.sh
#
# Checks (each skips with a yellow warning if its tool is missing — never fails on absence):
#   1. discover Dockerfiles / compose / workflows  (no artifacts -> exit 0)
#   2. hadolint     each Dockerfile
#   3. actionlint   .github/workflows
#   4. trivy config (Dockerfile/compose/IaC misconfig)
#   5. docker build smoke  (skippable: SKIP_DOCKER_BUILD=1)
#   6. trivy image  (only if step 5 built an image)
#   7. summary; exit non-zero only on a real failure
#
# Env: SKIP_DOCKER_BUILD=1 to skip the build smoke; NO_COLOR=1 to disable color.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

if [[ -n "${NO_COLOR:-}" ]]; then YEL=""; GRN=""; RED=""; RST=""
else YEL=$'\033[33m'; GRN=$'\033[32m'; RED=$'\033[31m'; RST=$'\033[0m'; fi
warn() { printf '%s[skip]%s %s\n' "$YEL" "$RST" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$GRN" "$RST" "$*"; }
fail() { printf '%s[fail]%s %s\n' "$RED" "$RST" "$*"; }

FAILED=0
BUILT_IMAGE=""
SMOKE_TAG="verify-smoke:local"

# 1. discover
mapfile -t DOCKERFILES < <(find . -name 'Dockerfile' -o -name 'Dockerfile.*' 2>/dev/null | grep -v node_modules || true)
WORKFLOWS_DIR=".github/workflows"
HAVE_WORKFLOWS=0; [[ -d "$WORKFLOWS_DIR" ]] && HAVE_WORKFLOWS=1
COMPOSE=$(find . -maxdepth 2 \( -name 'compose*.y*ml' -o -name 'docker-compose*.y*ml' \) 2>/dev/null | head -n1 || true)
if [[ ${#DOCKERFILES[@]} -eq 0 && $HAVE_WORKFLOWS -eq 0 && -z "$COMPOSE" ]]; then
  printf 'No Dockerfiles, compose files, or workflows found — nothing to gate.\n'; exit 0
fi

# 2. hadolint
if have hadolint; then
  for df in "${DOCKERFILES[@]}"; do
    if hadolint --failure-threshold warning "$df"; then ok "hadolint $df"
    else fail "hadolint $df"; FAILED=1; fi
  done
else warn "hadolint not installed — skipping Dockerfile lint"; fi

# 3. actionlint
if [[ $HAVE_WORKFLOWS -eq 1 ]]; then
  if have actionlint; then
    if actionlint; then ok "actionlint"; else fail "actionlint"; FAILED=1; fi
  else warn "actionlint not installed — skipping workflow lint"; fi
fi

# 4. trivy config
if have trivy; then
  if trivy config --exit-code 1 --severity HIGH,CRITICAL .; then ok "trivy config"
  else fail "trivy config"; FAILED=1; fi
else warn "trivy not installed — skipping config/image scan"; fi

# 5. docker build smoke
if [[ -n "${SKIP_DOCKER_BUILD:-}" ]]; then
  warn "SKIP_DOCKER_BUILD set — skipping build smoke"
elif have docker && [[ ${#DOCKERFILES[@]} -gt 0 ]]; then
  DF="${DOCKERFILES[0]}"
  if DOCKER_BUILDKIT=1 docker build --pull -t "$SMOKE_TAG" -f "$DF" "$(dirname "$DF")"; then
    ok "docker build $DF"; BUILT_IMAGE="$SMOKE_TAG"
  else fail "docker build $DF"; FAILED=1; fi
else warn "docker not available or no Dockerfile — skipping build smoke"; fi

# 6. trivy image (only if we built one)
if [[ -n "$BUILT_IMAGE" ]]; then
  if have trivy; then
    if trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$BUILT_IMAGE"; then
      ok "trivy image $BUILT_IMAGE"
    else fail "trivy image $BUILT_IMAGE"; FAILED=1; fi
  else warn "trivy not installed — skipping image scan"; fi
fi

# 7. summary
if [[ $FAILED -eq 0 ]]; then ok "all checks passed (skips are not failures)"
else fail "one or more checks failed"; fi
exit "$FAILED"
