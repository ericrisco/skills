#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NAME
#   verify.sh — bash-scripting self-lint gate
#
# USAGE
#   ./verify.sh [TARGET_DIR]
#   With no argument it lints the bash-scripting skill itself (the SKILL.md and
#   references/*.md fenced ```bash snippets, plus any *.sh under the skill).
#   Pass a TARGET_DIR to instead lint every *.sh under a project you are
#   hardening with this skill.
#
# WHAT IT DOES
#   1. Self-check  — extracts every ```bash fenced block from SKILL.md and
#                    references/*.md, wraps each in a strict-mode header, and
#                    runs shellcheck on it. This proves the skill never teaches
#                    code that fails its own linter. Blocks explicitly marked
#                    "# Bad" are illustrative wrong-on-purpose examples and are
#                    skipped (only the "# Good" half of a Bad/Good pair lints).
#   2. Script lint — runs shellcheck on every *.sh found under the target.
#
# GUARANTEES
#   - Read-only: never writes to or fixes the target; only reads + temp files.
#   - Graceful skip: if shellcheck is absent it prints a skip notice and EXITS 0
#     (never a false failure in an environment that lacks the linter).
#   - Clean exit on an empty/clean target: no scripts and no findings => exit 0.
#   - Portable to stock macOS bash 3.2 (no mapfile, no associative arrays).
#
# EXIT CODES
#   0  shellcheck absent (skipped), OR everything is clean.
#   1  at least one real shellcheck finding — fix it before shipping.
# ============================================================================

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
if [ -n "${NO_COLOR:-}" ]; then RED=""; YEL=""; GRN=""; RST=""; fi

ok()   { printf '%s[ok]%s %s\n'   "$GRN" "$RST" "$*"; }
warn() { printf '%s[skip]%s %s\n' "$YEL" "$RST" "$*" >&2; }
bad()  { printf '%s[FAIL]%s %s\n' "$RED" "$RST" "$*" >&2; }

# Resolve the skill root from this script's own location (scripts/ lives under it).
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SKILL_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
TARGET="${1:-$SKILL_DIR}"

if ! command -v shellcheck >/dev/null 2>&1; then
  warn "shellcheck not installed (brew install shellcheck / https://github.com/koalaman/shellcheck) — skipping lint"
  exit 0
fi

FAILED=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT   # one idempotent EXIT trap — the pattern this skill teaches

# Context codes that are noise on an isolated snippet (undefined vars/functions
# defined elsewhere in the doc, missing shebang we synthesize, unresolved source,
# unused vars in a fragment). These are excluded ONLY for extracted snippets,
# never for real *.sh files.
SNIPPET_EXCLUDE="SC2148,SC2154,SC2034,SC1090,SC1091,SC2317,SC2168,SC2030,SC2031"

# extract_blocks FILE  — write each ```bash block to $TMP/<base>.NN.sh with a
# strict-mode header. Blocks whose body contains a "# Bad" line are skipped.
extract_blocks() {
  file="$1"
  base=$(basename "$file" .md)
  awk -v dir="$TMP" -v base="$base" '
    /^```bash$/ { inblk=1; n++; body=""; bad=0; next }
    /^```/      { if (inblk) {
                    inblk=0
                    if (!bad) {
                      f = sprintf("%s/%s.%02d.sh", dir, base, n)
                      printf "#!/usr/bin/env bash\nset -euo pipefail\n%s", body > f
                      close(f)
                      print f
                    }
                  }
                  next }
    inblk       { if ($0 ~ /# Bad/) bad=1; body = body $0 "\n" }
  ' "$file"
}

lint_one() { # lint_one FILE EXCLUDE
  if [ -n "$2" ]; then
    shellcheck --exclude="$2" "$1"
  else
    shellcheck "$1"
  fi
}

printf '\n=== Snippet self-check (%s) ===\n' "$SKILL_DIR"
SNIPPET_FILES=""
for src in "$SKILL_DIR/SKILL.md" "$SKILL_DIR"/references/*.md; do
  [ -e "$src" ] || continue
  while IFS= read -r snip; do
    [ -n "$snip" ] || continue
    SNIPPET_FILES="$SNIPPET_FILES $snip"
  done <<EOF
$(extract_blocks "$src")
EOF
done

if [ -z "${SNIPPET_FILES// /}" ]; then
  warn "no \`\`\`bash snippets found to check"
else
  for snip in $SNIPPET_FILES; do
    if lint_one "$snip" "$SNIPPET_EXCLUDE"; then
      ok "snippet clean: $(basename "$snip")"
    else
      bad "snippet has findings: $(basename "$snip")"
      FAILED=1
    fi
  done
fi

printf '\n=== Script lint (%s) ===\n' "$TARGET"
FOUND=0
# find -print0 + NUL read: the space/newline-safe iteration this skill preaches.
while IFS= read -r -d '' sh; do
  FOUND=1
  if shellcheck "$sh"; then
    ok "clean: $sh"
  else
    bad "findings: $sh"
    FAILED=1
  fi
done < <(find "$TARGET" -type f -name '*.sh' ! -path "*/scripts/verify.sh" -print0)

if [ "$FOUND" -eq 0 ]; then
  ok "no *.sh files under target (nothing to lint)"
fi

printf '\n=== Summary ===\n'
if [ "$FAILED" -eq 0 ]; then
  ok "shellcheck clean"
else
  bad "shellcheck findings present — fix before shipping"
fi
exit "$FAILED"
