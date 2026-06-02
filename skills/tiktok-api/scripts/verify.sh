#!/usr/bin/env bash
# verify.sh — static, no-network preflight linter for TikTok API integration code.
# Read-only. Flags the patterns this skill bans. Exits 0 on a clean/empty target,
# non-zero with file:line on any hit.
#
# Usage: scripts/verify.sh [TARGET_DIR]   (default: current directory)

set -euo pipefail

TARGET="${1:-.}"
hits=0

if [ ! -d "$TARGET" ]; then
  echo "verify.sh: target '$TARGET' is not a directory" >&2
  exit 2
fi

report() { echo "FAIL [$1] $2"; hits=$((hits + 1)); }

# Files we scan: source + config, skipping vendored/build/VCS dirs. (bash 3.2 compatible)
FILES=()
while IFS= read -r _f; do
  [ -n "$_f" ] && FILES+=("$_f")
done < <(
  find "$TARGET" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/dist/*' \
       -o -path '*/build/*' -o -path '*/.venv/*' -o -path '*/venv/*' \) -prune -o \
    -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.mjs' \
       -o -name '*.json' -o -name '*.env' -o -name '*.yaml' -o -name '*.yml' \) -print 2>/dev/null
)

# (1) Committed TikTok secrets: a tracked token file containing a refresh_token.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if grep -lqs 'refresh_token' "$f" 2>/dev/null; then
    report "tracked-token" "$f: token file contains a refresh_token — do not commit it (gitignore it)"
  fi
done < <(find "$TARGET" \( -path '*/.git/*' \) -prune -o -type f \
           \( -name '*tiktok*token*.json' -o -name 'tiktok_token.json' -o -name 'token*.json' \) -print 2>/dev/null)

# Per-file content scans.
for f in ${FILES[@]+"${FILES[@]}"}; do
  [ -f "$f" ] || continue

  # (1b) Hardcoded client_secret literal in source.
  while IFS= read -r line; do
    report "client-secret" "$f:$line client_secret assigned a literal — load from env/secret store"
  done < <(grep -niE 'client_secret[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_-]{8,}' "$f" 2>/dev/null \
            | grep -viE 'os\.environ|process\.env|getenv|<|placeholder|your_|example|xxxx' | cut -d: -f1)

  # (2) Hardcoded access_token / Bearer literal instead of a refreshable credential object.
  while IFS= read -r line; do
    report "hardcoded-token" "$f:$line hardcoded access_token/Bearer literal — use a refreshable credential (24h expiry)"
  done < <(grep -niE 'access_token[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9._-]{12,}|Bearer[[:space:]]+[A-Za-z0-9._-]{20,}' "$f" 2>/dev/null \
            | grep -viE 'os\.environ|process\.env|getenv|access_token\(\)|\{|\$|f"|`|<|your_|example|placeholder' | cut -d: -f1)

  # Code-structure checks only meaningful in source files, not config/prose.
  case "$f" in
    *.py|*.js|*.ts|*.mjs) ;;
    *) continue ;;
  esac

  # (3) FILE_UPLOAD publish path with no Content-Range chunked PUT and no status poll.
  if grep -qsE 'post/publish/.*init/' "$f" 2>/dev/null && grep -qs 'FILE_UPLOAD' "$f" 2>/dev/null; then
    if ! grep -qsE 'Content-Range' "$f" 2>/dev/null; then
      ln=$(grep -nE 'FILE_UPLOAD' "$f" 2>/dev/null | head -1 | cut -d: -f1)
      report "no-chunked-put" "$f:${ln:-1} FILE_UPLOAD init but no Content-Range chunked PUT (transfer step missing)"
    fi
    if ! grep -qsE 'status/fetch|publish_id' "$f" 2>/dev/null; then
      ln=$(grep -nE 'FILE_UPLOAD' "$f" 2>/dev/null | head -1 | cut -d: -f1)
      report "no-status-poll" "$f:${ln:-1} publish init but no status/fetch poll on publish_id (async result unconfirmed)"
    fi
  fi

  # (4) Wrong-API assumption: reading watch-time/completion fields off the Display video/query response.
  if grep -qsE 'video/query' "$f" 2>/dev/null; then
    while IFS= read -r line; do
      report "wrong-api" "$f:$line watch-time/completion field near Display video/query — those come from the Business API, not Display"
    done < <(grep -nE 'average_time_watched|full_video_watched_rate|total_time_watched|impression_sources' "$f" 2>/dev/null | cut -d: -f1)
  fi

  # (5) Publish/status calls with no backoff/throttle helper around the 6/min cap.
  if grep -qsE 'post/publish/.*(init|status/fetch)' "$f" 2>/dev/null; then
    if ! grep -qsiE 'sleep|backoff|retry|throttle|rate.?limit|time\.sleep|setTimeout' "$f" 2>/dev/null; then
      ln=$(grep -nE 'post/publish/' "$f" 2>/dev/null | head -1 | cut -d: -f1)
      report "no-throttle" "$f:${ln:-1} publish/status calls with no sleep/backoff/throttle (6 req/min cap → rate_limit_exceeded)"
    fi
  fi
done

if [ "$hits" -gt 0 ]; then
  echo "verify.sh: $hits issue(s) found" >&2
  exit 1
fi
echo "OK: no banned TikTok-API patterns found in '$TARGET'"
exit 0
