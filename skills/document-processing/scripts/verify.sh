#!/usr/bin/env bash
#
# verify.sh — static guardrail for document-processing skill content.
#
# WHAT IT DOES (read-only; never edits, moves, runs, or installs anything)
#   Network-free, dependency-free static checks over a target file or
#   directory of skill content (defaults to the SKILL.md next to this script).
#   It does NOT execute any PDF/OCR library — it only greps the text:
#     1. No dead `import PyPDF2` / `from PyPDF2` — must use the maintained
#        `pypdf` import.                                            (FAIL)
#     2. Every form-fill call (`update_page_form_field_values`) sits in a
#        file that also sets `auto_regenerate=False`.               (FAIL)
#     3. The OCR guidance names BOTH a local engine (docling/marker/
#        tesseract) AND the hosted option (mistral).                (FAIL)
#     4. Code fences are language-tagged (no bare ``` opening a block). (WARN)
#     5. references/engines.md exists alongside the skill.          (WARN)
#
#   Checks 1-3 are hard failures. 4-5 are warnings (don't fail) unless
#   --strict. An empty / content-free / non-skill target exits 0 — never a
#   false failure on nothing.
#
# HOW TO RUN
#   bash scripts/verify.sh                 # checks ../SKILL.md by default
#   bash scripts/verify.sh path/to/SKILL.md
#   bash scripts/verify.sh path/to/dir/    # checks every *.md under dir
#   bash scripts/verify.sh --strict ...    # treat warnings as failures
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/non-skill target
#   1  a hard failure — or any warning under --strict
#   2  bad usage (target does not exist)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays, no bc.

set -u

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

fail_count=0; warn_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

STRICT=0
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --strict)  STRICT=1; shift ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *)  if [ -z "$TARGET" ]; then TARGET="$1"; fi; shift ;;
  esac
done

# Default target: the SKILL.md beside this script's directory.
if [ -z "$TARGET" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  TARGET="$SCRIPT_DIR/../SKILL.md"
fi

if [ ! -e "$TARGET" ]; then
  printf 'no such target: %s\n' "$TARGET" >&2
  exit 2
fi

# Build the list of files to inspect.
FILES=""
if [ -d "$TARGET" ]; then
  FILES="$(find "$TARGET" -name '*.md' -type f 2>/dev/null)"
  DIR_ROOT="$TARGET"
else
  FILES="$TARGET"
  DIR_ROOT="$(cd "$(dirname "$TARGET")" && pwd)"
fi

# Nothing with content -> exit 0, no false failure.
HAS_CONTENT=0
for f in $FILES; do
  if [ -s "$f" ] && grep -q '[^[:space:]]' "$f"; then HAS_CONTENT=1; fi
done
if [ "$HAS_CONTENT" -eq 0 ]; then
  ok "empty or content-free target: nothing to verify"
  exit 0
fi

# --- 1. No dead PyPDF2 import ----------------------------------------------
# Only flag a real import line in CODE: skip Markdown table rows (lines
# starting with '|', where it may be cited as the bad example to AVOID) and
# inline-code mentions wrapped in backticks within prose.
PYPDF2_HITS="$(grep -REn 'import[[:space:]]+PyPDF2|from[[:space:]]+PyPDF2' $FILES 2>/dev/null \
  | grep -vE ':[[:space:]]*\|' \
  | grep -vE '`[^`]*PyPDF2' || true)"
if [ -n "$PYPDF2_HITS" ]; then
  fail "found a PyPDF2 import in code — use the maintained 'pypdf' instead"
  printf '%s\n' "$PYPDF2_HITS" | sed 's/^/        /'
else
  ok "no dead PyPDF2 import in code"
fi

# --- 2. Form fills set auto_regenerate=False -------------------------------
for f in $FILES; do
  if grep -q 'update_page_form_field_values' "$f"; then
    if grep -q 'auto_regenerate[[:space:]]*=[[:space:]]*False' "$f"; then
      ok "form-fill in $(basename "$f") sets auto_regenerate=False"
    else
      fail "$(basename "$f") fills a form but never sets auto_regenerate=False (spurious 'save changes' prompt)"
    fi
  fi
done

# --- 3. OCR names a local AND a hosted engine ------------------------------
ALLTEXT="$(cat $FILES 2>/dev/null)"
if printf '%s' "$ALLTEXT" | grep -qiE 'ocr'; then
  has_local=0; has_hosted=0
  printf '%s' "$ALLTEXT" | grep -qiE 'docling|marker|tesseract' && has_local=1
  printf '%s' "$ALLTEXT" | grep -qiE 'mistral' && has_hosted=1
  if [ "$has_local" -eq 1 ] && [ "$has_hosted" -eq 1 ]; then
    ok "OCR guidance names a local engine and the hosted Mistral option"
  else
    [ "$has_local" -eq 0 ] && fail "OCR section names no local engine (docling/marker/tesseract)"
    [ "$has_hosted" -eq 0 ] && fail "OCR section names no hosted option (mistral)"
  fi
fi

# --- 4. Code fences are language-tagged (warn) -----------------------------
for f in $FILES; do
  # Count fence lines; a bare ``` that OPENS a block (odd-indexed) is untagged.
  # We approximate: any line that is exactly ``` may be a close OR a bad open.
  # Flag files where a ``` opener has no language by tracking parity.
  awk '
    /^```/ {
      if (inblock == 0) {
        # opening fence: must have a language after the backticks
        if ($0 ~ /^```[[:space:]]*$/) { bad++ }
        inblock = 1
      } else {
        inblock = 0
      }
    }
    END { exit (bad > 0 ? 1 : 0) }
  ' "$f" || warn "$(basename "$f") has an untagged code fence (bare \`\`\`) — tag the language"
done
[ "$warn_count" -eq 0 ] && ok "code fences appear language-tagged"

# --- 5. references/engines.md exists (warn) --------------------------------
if [ -d "$TARGET" ]; then
  REF_DIR="$TARGET/references"
else
  REF_DIR="$DIR_ROOT/references"
fi
if [ -f "$REF_DIR/engines.md" ]; then
  ok "references/engines.md present"
else
  warn "references/engines.md not found at $REF_DIR — install/licensing depth is expected there"
fi

# --- Summary ---------------------------------------------------------------
printf '\n'
if [ "$fail_count" -gt 0 ]; then
  printf '%s%d failure(s), %d warning(s)%s\n' "$RED" "$fail_count" "$warn_count" "$NC"
  exit 1
fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then
  printf '%s0 failures but %d warning(s) under --strict%s\n' "$YELLOW" "$warn_count" "$NC"
  exit 1
fi
printf '%spassed: 0 failures, %d warning(s)%s\n' "$GREEN" "$warn_count" "$NC"
exit 0
