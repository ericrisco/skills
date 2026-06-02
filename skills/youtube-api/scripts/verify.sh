#!/usr/bin/env bash
# verify.sh — static, no-network preflight linter for YouTube API integration code.
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

# (1) Committed OAuth secrets: client_secret*.json present, or token.json containing a refresh_token.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  report "secret-file" "$f: OAuth client_secret file should not be tracked (gitignore it)"
done < <(find "$TARGET" \( -path '*/.git/*' \) -prune -o -type f -name 'client_secret*.json' -print 2>/dev/null)

while IFS= read -r f; do
  [ -n "$f" ] || continue
  if grep -lqs 'refresh_token' "$f" 2>/dev/null; then
    report "tracked-token" "$f: token file contains a refresh_token — do not commit it"
  fi
done < <(find "$TARGET" \( -path '*/.git/*' \) -prune -o -type f -name 'token*.json' -print 2>/dev/null)

# Per-file content scans.
for f in ${FILES[@]+"${FILES[@]}"}; do
  [ -f "$f" ] || continue

  # (2) Over-broad full-management scope where least-privilege would do.
  while IFS= read -r line; do
    report "full-scope" "$f:$line over-broad scope auth/youtube (use youtube.upload + yt-analytics.readonly)"
  done < <(grep -nE 'auth/youtube"|auth/youtube'"'"'|auth/youtube[[:space:]]*$|auth/youtube,' "$f" 2>/dev/null \
            | grep -vE 'youtube\.(upload|force-ssl|readonly)|yt-analytics' | cut -d: -f1)

  # (3) videos.insert path with no resumable/uploadType and no retry/backoff helper in the same file.
  # Code-structure check — only meaningful in source files, not config/prose.
  case "$f" in
    *.py|*.js|*.ts|*.mjs) ;;
    *) continue ;;
  esac
  if grep -qE 'videos\(\)\.insert|videos\.insert' "$f" 2>/dev/null; then
    if ! grep -qiE 'resumable|uploadType|next_chunk|MediaFileUpload' "$f" 2>/dev/null; then
      ln=$(grep -nE 'videos\(\)\.insert|videos\.insert' "$f" 2>/dev/null | head -1 | cut -d: -f1)
      report "no-resumable" "$f:${ln:-?} videos.insert with no resumable/uploadType — use the resumable protocol"
    fi
    if ! grep -qiE 'backoff|retry|sleep|next_chunk' "$f" 2>/dev/null; then
      ln=$(grep -nE 'videos\(\)\.insert|videos\.insert' "$f" 2>/dev/null | head -1 | cut -d: -f1)
      report "no-backoff" "$f:${ln:-?} videos.insert with no retry/backoff helper — back off on 403/429"
    fi
  fi

  # (4) Hardcoded access_token / Bearer literal instead of a refreshable credential.
  while IFS= read -r line; do
    report "hardcoded-token" "$f:$line hardcoded access_token/Bearer — use a refreshable credential object"
  done < <(grep -nE 'access_token[[:space:]]*=[[:space:]]*["'"'"']ya29\.|Authorization:[[:space:]]*Bearer[[:space:]]+ya29\.|Bearer[[:space:]]+ya29\.' "$f" 2>/dev/null | cut -d: -f1)
done

if [ "$hits" -gt 0 ]; then
  echo "verify.sh: $hits issue(s) found in '$TARGET'"
  exit 1
fi

echo "OK: no banned YouTube-API patterns found in '$TARGET'"
exit 0
