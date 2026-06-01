#!/usr/bin/env bash
#
# verify.sh — deck build/lint gate for the `presentations` skill.
#
# WHAT IT DOES (read-only; detect-or-skip every tool)
#   1. python-pptx: if a build script exists (build_deck.py / a *.py that imports pptx),
#      check `python -c "import pptx"` works.
#   2. Marp: if marp-cli is reachable AND a Marp deck (`marp: true`) exists, print the
#      version and do a DRY PDF export of one sample deck to a temp file.
#   3. Slidev: if a Slidev deck (slides.md with a slidev marker) exists, report whether the
#      CLI is reachable.
#   4. markdownlint of deck sources, if markdownlint is available.
#   5. Static deck-hygiene greps (warn-only): tiny font sizes, 3-D charts, ban-list words.
#
# Everything is WARN-by-default; missing tools are SKIPPED with a yellow notice, never failed.
# Use --strict to turn warnings into failures (CI gate).
#
# HOW TO RUN (inside YOUR deck project, not the skills repo)
#   ./verify.sh
#   ./verify.sh --dir ./decks
#   ./verify.sh --strict
#
# EXIT CODES
#   0  no real failures (warnings allowed unless --strict)
#   1  a real failure (e.g. import pptx fails, marp dry-export fails), or --strict with any warning
#   2  bad usage

set -euo pipefail

# --- portability: runs on stock macOS bash 3.2 -----------------------------
# Avoids bash 4+ features: no `mapfile`/`readarray`, no associative arrays, no
# unguarded `${arr[@]}` under set -u. Scalar counters + `read` loops only.
if [ -z "${BASH_VERSION:-}" ]; then
  printf 'This script requires bash (any version >= 3.2). Run: bash %s\n' "$0" >&2
  exit 2
fi

# --- color helpers (no escape codes when not a TTY) ------------------------
if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; skip_count=0; warn_count=0; fail_count=0

ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; skip_count=$((skip_count + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() {
  sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
}

# --- arg parse -------------------------------------------------------------
DIR="."
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)    DIR="${2:?--dir needs a value}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
  esac
done

if [ ! -d "$DIR" ]; then
  printf '%sNo such directory: %s%s\n' "$RED" "$DIR" "$NC"; exit 2
fi

have() { command -v "$1" >/dev/null 2>&1; }

# Find first file matching a grep pattern, or empty. Prints one path.
first_with() {
  # $1 = file glob (find -name), $2 = grep pattern
  find "$DIR" -type f -name "$1" 2>/dev/null | while IFS= read -r f; do
    if grep -lqE "$2" "$f" 2>/dev/null; then printf '%s\n' "$f"; break; fi
  done | head -n 1
}

# ---------------------------------------------------------------------------
# 1. python-pptx — only if a build script that imports pptx exists
# ---------------------------------------------------------------------------
check_pptx() {
  local script
  script="$(first_with '*.py' 'import +pptx|from +pptx')"
  if [ -z "$script" ]; then
    skip "no python-pptx build script found (no *.py importing pptx) — skipping import check"
    return
  fi
  local py=""
  if have python3; then py=python3; elif have python; then py=python; fi
  if [ -z "$py" ]; then
    skip "python not found — cannot verify python-pptx for $script"
    return
  fi
  if "$py" -c 'import pptx' >/dev/null 2>&1; then
    local ver
    ver="$("$py" -c 'import pptx;print(pptx.__version__)' 2>/dev/null || echo '?')"
    ok "python-pptx importable (v$ver); build script: $script"
  else
    fail "python-pptx build script present ($script) but \`import pptx\` fails — pip install python-pptx"
  fi
}

# ---------------------------------------------------------------------------
# 2. Marp — only if a Marp deck exists; print version + DRY pdf export
# ---------------------------------------------------------------------------
MARP_CMD=""
marp_cmd() {
  if have marp; then MARP_CMD="marp"; return 0; fi
  if have npx;  then MARP_CMD="npx --no-install @marp-team/marp-cli"; return 0; fi
  return 1
}
check_marp() {
  local deck
  deck="$(first_with '*.md' '^marp: *true')"
  if [ -z "$deck" ]; then
    skip "no Marp deck found (no markdown with 'marp: true') — skipping Marp checks"
    return
  fi
  if ! marp_cmd; then
    skip "marp-cli not found (install @marp-team/marp-cli or have npx) — found Marp deck: $deck"
    return
  fi
  local ver
  ver="$($MARP_CMD --version 2>/dev/null | head -n 1 || echo '?')"
  ok "marp-cli available ($ver); Marp deck: $deck"

  local tmp out
  tmp="$(mktemp -d)"; out="$tmp/_verify.pdf"
  printf 'Dry PDF export of %s ...\n' "$deck"
  if $MARP_CMD "$deck" --pdf -o "$out" >/dev/null 2>&1 && [ -s "$out" ]; then
    ok "marp --pdf dry export succeeded ($deck)"
  else
    warn "marp --pdf dry export did not produce a PDF for $deck (Chromium/Chrome installed? remote fonts reachable?)"
  fi
  rm -rf "$tmp"
}

# ---------------------------------------------------------------------------
# 3. Slidev — report presence + CLI reachability (no full export in CI)
# ---------------------------------------------------------------------------
check_slidev() {
  local deck
  deck="$(first_with 'slides.md' 'layout:|^---|theme:')"
  [ -z "$deck" ] && deck="$(first_with '*.md' '@slidev|slidev')"
  if [ -z "$deck" ]; then
    skip "no Slidev deck found — skipping Slidev checks"
    return
  fi
  if have slidev; then
    ok "slidev CLI on PATH; Slidev deck: $deck"
  elif have npx; then
    ok "slidev runnable via npx; Slidev deck: $deck (export needs playwright-chromium installed)"
  else
    skip "slidev CLI not found (install @slidev/cli) — found Slidev deck: $deck"
  fi
}

# ---------------------------------------------------------------------------
# 4. markdownlint of deck sources
# ---------------------------------------------------------------------------
check_markdownlint() {
  local linter=""
  if have markdownlint; then linter="markdownlint"
  elif have markdownlint-cli2; then linter="markdownlint-cli2"
  else
    skip "markdownlint not found — skipping deck source lint"
    return
  fi
  local any
  any="$(find "$DIR" -type f -name '*.md' 2>/dev/null | head -n 1)"
  if [ -z "$any" ]; then
    skip "no markdown deck sources to lint"
    return
  fi
  if find "$DIR" -type f -name '*.md' -print0 2>/dev/null | xargs -0 "$linter" >/dev/null 2>&1; then
    ok "markdownlint clean on deck sources"
  else
    warn "markdownlint reported issues in deck sources (run '$linter \"$DIR\"/**/*.md' for detail)"
  fi
}

# ---------------------------------------------------------------------------
# 5. Static deck-hygiene greps (warn-only)
# ---------------------------------------------------------------------------
search() {
  if have rg; then rg -n --no-heading "$@" "$DIR" 2>/dev/null
  else grep -rnE "${*: -1}" "$DIR" 2>/dev/null; fi
}
static_checks() {
  local hits

  # tiny font sizes in themes/build scripts (legibility floor ~24pt body)
  hits="$(search 'font-size: *(1[0-9]|2[0-3])px|Pt\((1[0-9]|2[0-3])\)' 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    warn "possible sub-24 font sizes (legibility from the back of the room):"
    printf '%s\n' "$hits" | head -n 5
  fi

  # 3-D / rainbow chart smells
  hits="$(search '_3D|THREE_D|3-?D (pie|chart|bar)' 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    warn "3-D chart usage found (banned — use flat charts, one highlighted series):"
    printf '%s\n' "$hits" | head -n 5
  fi

  # ban-list marketing words in deck copy
  hits="$(search 'revolutionary|game-?changer|cutting-edge|supercharge|seamless|unlock|world-class' 2>/dev/null \
          | grep -iE '\.(md|mdx|py|html)' || true)"
  if [ -n "$hits" ]; then
    warn "ban-list marketing words in deck copy (replace with a number / mechanism):"
    printf '%s\n' "$hits" | head -n 5
  fi
}

# --- run -------------------------------------------------------------------
check_pptx
check_marp
check_slidev
check_markdownlint
static_checks

cat <<'EOF'

Manual deck QA (mechanical checks above don't cover these):
  [ ] Brand study located, complete, and cited.
  [ ] One idea per slide; assertion headlines, not topic labels.
  [ ] Body >= 24pt (>= 28-32 for a talk); contrast >= 4.5:1; reads at 3 metres.
  [ ] Colors / type / spacing from design tokens, not per-slide hex.
  [ ] Deliberate arc + single thesis; opens with a hook, ends with one ask.
  [ ] Every number sourced; gaps marked [[NEEDS PROOF]]; none invented.
  [ ] Each chart makes one point named in the headline; no 3-D/rainbow/dual-axis.
  [ ] Motion = one family <= 300ms; reduced-motion honored (HTML); builds reveal meaning.
  [ ] 16:9; PDF vector with fonts embedded (pdffonts -> emb yes); PPTX opens clean.
  [ ] PPTX editability matches the promise (python-pptx if "editable", not flattened images).
EOF

printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
