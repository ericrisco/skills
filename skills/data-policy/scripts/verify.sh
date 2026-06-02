#!/usr/bin/env bash
# verify.sh — data-policy
# Read-only, offline, deterministic lint of a GENERATED governance artifact
# (a finished retention schedule / ROPA / consent matrix / data policy).
# Exits 0 on a clean OR empty/missing target (no false failure).
# Non-zero only on a real violation. grep/awk only, no deps. bash 3.2-safe.
#
# Checks (per the plan):
#   1. A retention/schedule table row must not be missing its period or lawful
#      basis (empty or dash cell under a period/retention/basis column).
#   2. Vague period language ("as long as necessary", "indefinitely", "forever",
#      "permanently", "until no longer needed") must NOT be the only period —
#      fail if present and no concrete period (number+unit, or "criteria") exists.
#   3. A full policy must carry a disclaimer: "DPO" / "counsel" /
#      "legal review" / "not legal advice".
#   4. If the text mentions deletion it must also mention "backup" or "archive"
#      (the enforcement gap).
#
# This lints FINISHED artifacts only. Blank-celled templates (a file whose
# heading or text marks it a "template", or that carries empty `| |` fill-in
# rows) are skipped — an unfilled template is not a failed policy.
#
# Usage: verify.sh [FILE_OR_DIR]   (default: current directory)
#        verify.sh -               (read from stdin)

set -uo pipefail

TARGET="${1:-.}"

TMP=""
cleanup() { [ -n "$TMP" ] && rm -f "$TMP"; }
trap cleanup EXIT

# --- gather candidate files (or stdin), bash-3.2 safe ------------------------
LIST="$(mktemp)"
trap 'cleanup; rm -f "$LIST"' EXIT

if [ "$TARGET" = "-" ]; then
  TMP="$(mktemp)"
  cat > "$TMP"
  printf '%s\n' "$TMP" > "$LIST"
elif [ -d "$TARGET" ]; then
  find "$TARGET" -type f \( -name '*.md' -o -name '*.markdown' -o -name '*.txt' \) 2>/dev/null > "$LIST"
elif [ -f "$TARGET" ]; then
  printf '%s\n' "$TARGET" > "$LIST"
else
  echo "verify: target '$TARGET' not found; nothing to check."
  exit 0
fi

if [ ! -s "$LIST" ]; then
  echo "verify: no candidate files under '$TARGET'; clean by default."
  exit 0
fi

fail=0
checked=0
note_fail() { echo "FAIL: $1"; fail=1; }

VAGUE='as long as necessary|indefinitely|forever|permanently|until no longer needed'
CONCRETE='[0-9]+[[:space:]]*(day|days|week|weeks|month|months|year|years|yr|yrs|mo)|criteria'
DISCLAIMER='DPO|counsel|legal review|not legal advice'
DELETION='delet|erase|purge'
BACKUPS='backup|archive'
ARTIFACT='retention|lawful basis|record of processing|ropa|consent matrix|storage limitation|expiry'

while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  label="$f"; [ "$f" = "$TMP" ] && label="<stdin>"

  # Only lint files that look like a governance ARTIFACT, not prose docs that
  # merely name retention. Require an artifact signal AND a markdown table
  # (a line with two or more pipes) — schedules/ROPAs/consent matrices are tabular.
  grep -qiE "$ARTIFACT" "$f" 2>/dev/null || continue
  grep -qE '\|.*\|' "$f" 2>/dev/null || continue

  # Skip unfilled TEMPLATES: a file that announces itself a template, or carries
  # an empty markdown fill-in row like "|  |  |  |". Those legitimately have
  # blank cells and are not a failed policy.
  if grep -qiE 'template|fill-?able|fill-?in|copy-?ready' "$f" 2>/dev/null \
     || grep -qE '^\|[[:space:]]*\|([[:space:]]*\|)+[[:space:]]*$' "$f" 2>/dev/null; then
    continue
  fi

  checked=$((checked+1))

  # --- Check 1: table rows missing period or lawful basis --------------------
  awk -v FNAME="$label" '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/,"",s); return s }
    BEGIN{ FS="|"; rc=0 }
    /\|/ && /[Pp]eriod|[Rr]etention|[Ll]awful basis|[Bb]asis/ {
      delete col
      for (i=1;i<=NF;i++){
        c=tolower(trim($i))
        if (c ~ /period|retention/ || c ~ /lawful basis|^basis$/){ col[i]=c }
      }
      n=0; for (k in col) n++
      if (n>0){ inhdr=NR; next }
    }
    # an optional markdown separator row (---|---) right after the header
    inhdr && NR==inhdr+1 && /^[ \t]*\|?[ \t:|-]+$/ { next }
    inhdr && NR>inhdr {
      if ($0 !~ /\|/){ inhdr=0; next }
      for (i in col){
        cell=trim($i)
        if (cell=="" || cell ~ /^-+$/){
          printf("FAIL: %s: table row %d missing %s cell\n", FNAME, NR, col[i]); rc=1
        }
      }
    }
    END{ exit rc }
  ' "$f" || fail=1

  # --- Check 2: vague period as the ONLY period ------------------------------
  if grep -qiE "$VAGUE" "$f" 2>/dev/null; then
    grep -qiE "$CONCRETE" "$f" 2>/dev/null \
      || note_fail "$label: vague period with no concrete period or criteria"
  fi

  # --- Check 3: missing disclaimer -------------------------------------------
  grep -qiE "$DISCLAIMER" "$f" 2>/dev/null \
    || note_fail "$label: no DPO / counsel / legal-review / 'not legal advice' disclaimer"

  # --- Check 4: deletion without backups/archives ----------------------------
  if grep -qiE "$DELETION" "$f" 2>/dev/null; then
    grep -qiE "$BACKUPS" "$f" 2>/dev/null \
      || note_fail "$label: mentions deletion but never backups/archives (the enforcement gap)"
  fi
done < "$LIST"

if [ "$fail" -ne 0 ]; then
  echo "verify: violations found."
  exit 1
fi

if [ "$checked" -eq 0 ]; then
  echo "verify: no finished policy artifacts to lint (templates/non-artifacts only); clean by default."
  exit 0
fi

echo "verify: OK — periods + bases present, no vague-only periods, disclaimer present, backups covered."
exit 0
