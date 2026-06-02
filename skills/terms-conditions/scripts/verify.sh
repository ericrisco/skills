#!/usr/bin/env bash
# verify.sh — lint a drafted Terms / AUP / notice document.
#
# Read-only. Checks a generated legal document for two things:
#   1. archaic legalese the skill is told never to use (always FAIL),
#   2. if the doc self-identifies as a full Terms of Service, the required
#      structural sections (governing law, limitation of liability, attorney-
#      review disclaimer); a missing DMCA notice is a WARN, not a FAIL.
#
# Usage:
#   scripts/verify.sh [path]
#   - path to a .md file, OR
#   - a directory (globs for *.md), OR
#   - nothing (globs the current working directory for *.md).
#
# Exits 0 on a clean target AND on an empty target (no docs found => nothing to
# fail). Exits 1 only when a real FAIL is found. No dependencies beyond a POSIX
# shell + grep.

set -u

FAILS=0
WARNS=0
CHECKED=0

BANLIST='heretofore|hereinafter|witnesseth|party of the first part|aforementioned|whereas the parties'

is_full_tos() {
  # Only treat a document as a full ToS if the phrase appears in a HEADING or a
  # title line — not merely mentioned in prose (e.g. an AUP that says "the
  # Terms of Service"). A heading is a Markdown '#'-line or a line that is
  # *only* the title.
  grep -Eiq '^[[:space:]]*#{1,6}[[:space:]].*(terms of service|terms of use|terms (and|&) conditions)' "$1" \
    || grep -Eiq '^[[:space:]]*(terms of service|terms of use|terms (and|&) conditions)([[:space:]]*[—:-].*)?[[:space:]]*$' "$1"
}

check_file() {
  local f="$1"
  CHECKED=$((CHECKED + 1))
  local file_failed=0

  # 1. Archaic-legalese banlist (case-insensitive). Always a FAIL.
  if grep -Eiq "$BANLIST" "$f"; then
    echo "FAIL  $f: archaic legalese found ->"
    grep -Eino "$BANLIST" "$f" | sed 's/^/        line /'
    file_failed=1
  fi

  # 2. Structural checks, only for a full ToS.
  if is_full_tos "$f"; then
    grep -Eiq 'governing law|governed by the laws' "$f" || {
      echo "FAIL  $f: full ToS missing a governing-law clause"; file_failed=1; }
    grep -Eiq 'limitation of liability|aggregate liability|total .*liability' "$f" || {
      echo "FAIL  $f: full ToS missing a limitation-of-liability clause"; file_failed=1; }
    grep -Eiq 'attorney|legal advice|not a lawyer|licensed (counsel|attorney)' "$f" || {
      echo "FAIL  $f: full ToS missing an attorney-review / not-legal-advice disclaimer"; file_failed=1; }
    grep -Eiq 'dmca|designated agent|copyright complaints' "$f" || {
      echo "WARN  $f: full ToS has no DMCA notice (fine only if there is no user-generated content)"
      WARNS=$((WARNS + 1)); }
  fi

  if [ "$file_failed" -eq 0 ]; then
    echo "ok    $f"
  else
    FAILS=$((FAILS + 1))
  fi
}

# Resolve the target into a list of .md files.
TARGET="${1:-.}"
FILES=()
if [ -f "$TARGET" ]; then
  FILES=("$TARGET")
elif [ -d "$TARGET" ]; then
  while IFS= read -r line; do FILES+=("$line"); done < <(find "$TARGET" -type f -name '*.md' 2>/dev/null)
else
  echo "verify.sh: target not found: $TARGET" >&2
  exit 0
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "verify.sh: no .md documents to check under '$TARGET' — nothing to verify."
  exit 0
fi

for f in "${FILES[@]}"; do
  check_file "$f"
done

echo "---"
echo "checked: $CHECKED  fails: $FAILS  warns: $WARNS"
[ "$FAILS" -eq 0 ] && exit 0 || exit 1
