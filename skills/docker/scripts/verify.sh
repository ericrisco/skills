#!/usr/bin/env bash
# verify.sh — read-only static checks for docker artifacts (Dockerfile, compose.yaml, .dockerignore)
#
# Usage:
#   ./verify.sh [DIR] [IMAGE_TAG]
#     DIR        directory to scan (default: current dir)
#     IMAGE_TAG  optional built image to scan with trivy/dockle and size-check
#
# Behavior:
#   - Read-only: never builds, never writes, never pulls.
#   - Degrades gracefully: a missing tool is a SKIP (warning), not a failure — CI-safe.
#   - Exits 0 on a clean or empty target (no Dockerfile/compose present => nothing to fail).
#   - Exits 1 only on a real banned pattern or an error-level lint/parse failure.

set -uo pipefail

DIR="${1:-.}"
IMAGE_TAG="${2:-}"
SIZE_LIMIT_BYTES="${DOCKER_VERIFY_SIZE_LIMIT:-524288000}" # 500 MB default, override via env

fail=0
have() { command -v "$1" >/dev/null 2>&1; }
warn() { printf 'SKIP: %s\n' "$1" >&2; }
err()  { printf 'FAIL: %s\n' "$1" >&2; fail=1; }
ok()   { printf 'OK:   %s\n' "$1"; }

# Locate a Dockerfile / Containerfile.
DOCKERFILE=""
for cand in "$DIR/Dockerfile" "$DIR/Containerfile"; do
  [ -f "$cand" ] && DOCKERFILE="$cand" && break
done

# Locate a compose file.
COMPOSE=""
for cand in "$DIR/compose.yaml" "$DIR/compose.yml" "$DIR/docker-compose.yaml" "$DIR/docker-compose.yml"; do
  [ -f "$cand" ] && COMPOSE="$cand" && break
done

if [ -z "$DOCKERFILE" ] && [ -z "$COMPOSE" ]; then
  ok "no Dockerfile or compose file in '$DIR' — nothing to verify"
  exit 0
fi

# ---- Dockerfile checks ----
if [ -n "$DOCKERFILE" ]; then
  ok "found $DOCKERFILE"

  # Ban: :latest base images.
  if grep -nEi '^[[:space:]]*FROM[[:space:]]+[^[:space:]]+:latest([[:space:]]|$)' "$DOCKERFILE" >/dev/null \
     || grep -nEi '^[[:space:]]*FROM[[:space:]]+[^[:space:]@:]+([[:space:]]+AS|[[:space:]]*$)' "$DOCKERFILE" >/dev/null; then
    err "$DOCKERFILE: FROM uses :latest or an unpinned image (pin a tag or digest)"
  else
    ok "all FROM lines are pinned (no :latest)"
  fi

  # Ban: secrets in ARG/ENV.
  if grep -nEi '^[[:space:]]*(ARG|ENV)[[:space:]]+.*(TOKEN|SECRET|PASSWORD|PASSWD|API[_-]?KEY|PRIVATE[_-]?KEY|ACCESS[_-]?KEY)' "$DOCKERFILE" >/dev/null; then
    err "$DOCKERFILE: secret-looking value in ARG/ENV (use RUN --mount=type=secret)"
  else
    ok "no secret-looking ARG/ENV"
  fi

  # Require: a USER instruction (non-root).
  if grep -nEi '^[[:space:]]*USER[[:space:]]+' "$DOCKERFILE" >/dev/null; then
    if grep -nEi '^[[:space:]]*USER[[:space:]]+(root|0)[[:space:]]*$' "$DOCKERFILE" >/dev/null; then
      err "$DOCKERFILE: final USER is root/0 (run as a non-root user)"
    else
      ok "non-root USER present"
    fi
  else
    err "$DOCKERFILE: no USER instruction (container will run as root)"
  fi

  # hadolint (optional).
  if have hadolint; then
    if hadolint --no-fail "$DOCKERFILE" | grep -qiE ' error| DL[0-9]+ error'; then
      err "$DOCKERFILE: hadolint reported error-level findings"
    else
      hadolint --failure-threshold error "$DOCKERFILE" && ok "hadolint clean (error level)" || err "$DOCKERFILE: hadolint error-level findings"
    fi
  else
    warn "hadolint not installed — skipping Dockerfile lint"
  fi
fi

# ---- compose checks ----
if [ -n "$COMPOSE" ]; then
  ok "found $COMPOSE"

  # Ban: obsolete version: key.
  if grep -nE '^[[:space:]]*version[[:space:]]*:' "$COMPOSE" >/dev/null; then
    err "$COMPOSE: obsolete top-level 'version:' key (remove it)"
  else
    ok "no obsolete version: key"
  fi

  # Validate with docker compose if available.
  if have docker && docker compose version >/dev/null 2>&1; then
    if docker compose -f "$COMPOSE" config -q >/dev/null 2>&1; then
      ok "docker compose config -q parses"
    else
      err "$COMPOSE: docker compose config -q failed to parse/resolve"
    fi
  else
    warn "docker compose v2 not available — skipping compose validation"
  fi
fi

# ---- optional image scans (only when a tag is provided) ----
if [ -n "$IMAGE_TAG" ]; then
  if have trivy; then
    trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 "$IMAGE_TAG" \
      && ok "trivy scanned $IMAGE_TAG (review HIGH/CRITICAL above)" \
      || warn "trivy could not scan $IMAGE_TAG"
  else
    warn "trivy not installed — skipping image CVE scan"
  fi

  if have dockle; then
    dockle --exit-code 0 "$IMAGE_TAG" && ok "dockle checked $IMAGE_TAG" || warn "dockle could not check $IMAGE_TAG"
  else
    warn "dockle not installed — skipping image hygiene check"
  fi

  if have docker; then
    size="$(docker image inspect -f '{{.Size}}' "$IMAGE_TAG" 2>/dev/null || echo '')"
    if [ -n "$size" ]; then
      if [ "$size" -gt "$SIZE_LIMIT_BYTES" ]; then
        err "image $IMAGE_TAG is ${size} bytes (> ${SIZE_LIMIT_BYTES}); consider a smaller base / multi-stage"
      else
        ok "image $IMAGE_TAG size ${size} bytes is within limit ${SIZE_LIMIT_BYTES}"
      fi
    else
      warn "could not inspect size of $IMAGE_TAG (not built locally?)"
    fi
  fi
elif have trivy && [ -n "$DOCKERFILE" ]; then
  # No tag: still do a build-free config scan if trivy is present.
  trivy config "$DIR" --severity HIGH,CRITICAL --exit-code 0 \
    && ok "trivy config scanned $DIR (review findings above)" \
    || warn "trivy config could not scan $DIR"
fi

if [ "$fail" -ne 0 ]; then
  printf '\nverify.sh: FAILED\n' >&2
  exit 1
fi
printf '\nverify.sh: PASSED\n'
exit 0
