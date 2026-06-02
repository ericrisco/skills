#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NAME
#   verify.sh — Electron insecure-pattern gate
#
# USAGE
#   ./verify.sh [TARGET_DIR]
#
#   With TARGET_DIR: scans that Electron project's source for insecure
#   patterns and exits non-zero if any are found.
#   With no argument: self-checks THIS skill's own example code fences — the
#   recommended ("Good") snippets must be clean and must contain the secure
#   baseline. Fences flagged with a `// Bad` comment are intentional
#   counter-examples and are skipped; prose, tables, and checklists (which
#   legitimately NAME the banned patterns) are not scanned.
#
# WHAT IT FLAGS (each = FAIL)
#   nodeIntegration: true            renderer gets full Node → XSS becomes RCE
#   contextIsolation: false          page can rewrite the preload bridge
#   sandbox: false                   renderer escapes the OS sandbox
#   @electron/remote                 direct renderer→main escalation path
#   new BrowserView                  deprecated since Electron 30
#   exposeInMainWorld(..., ipcRenderer)  universal IPC weapon (empty obj now)
#
# GUARANTEES
#   - Read-only: never writes to or modifies the target.
#   - Exits 0 on an empty or clean target (no false failure).
#   - Portable to stock macOS bash 3.2 (no mapfile/associative arrays).
#
# EXIT CODES
#   0  clean (or empty target)
#   1  at least one insecure pattern found
#   2  bad usage (target path does not exist)
# ============================================================================

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RST=$'\033[0m'
else
  RED=''; GRN=''; YLW=''; RST=''
fi

FAILED=0
ok()   { printf '%sPASS%s %s\n' "$GRN" "$RST" "$1"; }
bad()  { printf '%sFAIL%s %s\n' "$RED" "$RST" "$1"; FAILED=1; }
info() { printf '%s•%s    %s\n' "$YLW" "$RST" "$1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

PAT_NODEINT='nodeIntegration[[:space:]]*:[[:space:]]*true'
PAT_CTXISO='contextIsolation[[:space:]]*:[[:space:]]*false'
PAT_SANDBOX='sandbox[[:space:]]*:[[:space:]]*false'
PAT_REMOTE='@electron/remote'
PAT_BROWSERVIEW='new[[:space:]]+BrowserView'
PAT_EXPOSE='exposeInMainWorld\([^,]*,[[:space:]]*ipcRenderer[[:space:]]*\)'

scan_lines() { # $1=label $2=pattern $3=haystack ; runs in the CURRENT shell so
               # FAILED mutations stick (a pipe would fork a subshell and lose them)
  local label="$1" pat="$2" hits
  hits="$(printf '%s\n' "$3" | grep -nE "$pat" || true)"
  if [ -n "$hits" ]; then
    bad "$label"
    printf '%s\n' "$hits" | sed 's/^/       /'
  else
    ok "$label"
  fi
}

# ---------------------------------------------------------------------------
if [ "$#" -ge 1 ]; then
  # ---- TARGET MODE: scan a real Electron project's source files ----------
  TARGET="$1"
  if [ ! -e "$TARGET" ]; then
    printf '%sverify.sh: target does not exist: %s%s\n' "$RED" "$TARGET" "$RST" >&2
    exit 2
  fi
  printf 'Scanning %s (target mode)\n\n' "$TARGET"

  SRC="$(
    find "$TARGET" \
      \( -name node_modules -o -name .git -o -name dist -o -name out \) -prune -o \
      \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \) \
      -type f -print 2>/dev/null || true
  )"
  if [ -z "$SRC" ]; then
    info "no Electron source files found under $TARGET"
    ok "clean (nothing to check)"
    exit 0
  fi

  # Concatenate source as file:line so findings point somewhere useful.
  ALL="$(printf '%s\n' "$SRC" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -nH '' "$f" 2>/dev/null || true
  done)"

  scan_lines "no nodeIntegration: true"                 "$PAT_NODEINT"     "$ALL"
  scan_lines "no contextIsolation: false"               "$PAT_CTXISO"      "$ALL"
  scan_lines "no sandbox: false"                        "$PAT_SANDBOX"     "$ALL"
  scan_lines "no @electron/remote"                      "$PAT_REMOTE"      "$ALL"
  scan_lines "no new BrowserView (use WebContentsView)" "$PAT_BROWSERVIEW" "$ALL"
  scan_lines "no ipcRenderer over contextBridge"        "$PAT_EXPOSE"      "$ALL"

else
  # ---- SELF MODE: vet the skill's own "Good" code fences -----------------
  printf 'Self-checking %s (self mode)\n\n' "$SKILL_DIR"
  DOCS="$(find "$SKILL_DIR" -type f \( -name 'SKILL.md' -o -path '*/references/*.md' \) 2>/dev/null || true)"

  # Extract only code-fence bodies, dropping any fence that is marked as a
  # `// Bad` counter-example. Prose/tables/checklists are never scanned.
  GOOD="$(
    printf '%s\n' "$DOCS" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      awk '
        /^```/      { infence = !infence; if (infence) { buf=""; bad=0 } else { if (!bad) printf "%s", buf }; next }
        infence     { if ($0 ~ /\/\/[[:space:]]*Bad/) bad=1; buf = buf $0 "\n" }
      ' "$f"
    done
  )"

  scan_lines "Good snippets: no nodeIntegration: true"   "$PAT_NODEINT"     "$GOOD"
  scan_lines "Good snippets: no contextIsolation: false" "$PAT_CTXISO"      "$GOOD"
  scan_lines "Good snippets: no sandbox: false"          "$PAT_SANDBOX"     "$GOOD"
  scan_lines "Good snippets: no @electron/remote import" "$PAT_REMOTE"      "$GOOD"
  scan_lines "Good snippets: no new BrowserView"         "$PAT_BROWSERVIEW" "$GOOD"
  scan_lines "Good snippets: no exposed ipcRenderer"     "$PAT_EXPOSE"      "$GOOD"

  # Positive assertion: the secure baseline must actually appear somewhere.
  for tok in 'nodeIntegration: false' 'contextIsolation: true' 'sandbox: true'; do
    if printf '%s\n' "$GOOD" | grep -qF "$tok"; then ok "baseline present: $tok"
    else bad "baseline missing from example snippets: $tok"; fi
  done
fi

echo
if [ "$FAILED" -eq 0 ]; then
  ok "no insecure Electron patterns found"
else
  printf '%sinsecure patterns present — fix before shipping%s\n' "$RED" "$RST" >&2
fi
exit "$FAILED"
