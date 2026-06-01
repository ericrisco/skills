#!/usr/bin/env bash
#
# verify.sh — design-review gate for the `design` skill.
#
# WHAT IT DOES
#   1. If a dev server is reachable AND Lighthouse is available, runs a
#      performance + accessibility audit and checks Core Web Vitals against the
#      skill's hard thresholds (LCP < 2.5s, CLS < 0.1, INP proxy via TBT < 200ms,
#      a11y score >= 0.9).
#   2. Always runs static, network-free design-review grep checks (one <h1>,
#      no `transition: all`, hardcoded hex vs tokens, missing image alt, missing
#      prefers-reduced-motion, marketing ban-list words).
#   3. If Lighthouse did not run, prints the 14-point manual QA checklist.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                       # static checks + Lighthouse if localhost:3000 is up
#   ./verify.sh --url http://localhost:3001
#   ./verify.sh --strict              # treat warnings as failures (exit 1 on any warn)
#
# EXIT CODES
#   0  no real failures (warnings allowed unless --strict)
#   1  a real failure (failed Lighthouse threshold), or --strict with any warning
#   2  bad usage
#
# Missing tools are SKIPPED with a yellow notice, never failed.

set -euo pipefail

# --- color helpers (no escape codes when not a TTY) -------------------------
if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; skip_count=0; warn_count=0; fail_count=0

ok()   { printf '%s[ ok ]%s %s\n'   "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
skip() { printf '%s[skip]%s %s\n'   "$YELLOW" "$NC" "$*"; skip_count=$((skip_count + 1)); }
warn() { printf '%s[warn]%s %s\n'   "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n'   "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

# --- arg parse --------------------------------------------------------------
URL="http://localhost:3000"
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --url)    URL="${2:?--url needs a value}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# search wrapper: ripgrep if present, else portable grep -rnE. Both print file:line.
search() {
  if have rg; then
    rg -n --no-heading "$@"
  else
    # last arg is the pattern; everything before are paths/globs we ignore for grep
    local pattern="${*: -1}"
    grep -rnE "$pattern" . 2>/dev/null
  fi
}

LH_RAN=0

# --- Lighthouse step (guarded) ---------------------------------------------
run_lighthouse() {
  if ! { have lighthouse || have npx; }; then
    skip "lighthouse not found — skipping perf/a11y run"
    return
  fi
  if ! have curl || ! curl -sf --max-time 3 "$URL" >/dev/null 2>&1; then
    skip "no dev server at $URL — start it (e.g. npm run dev) to run Lighthouse"
    return
  fi

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  local out="$tmp/lh.json"
  printf 'Running Lighthouse against %s ...\n' "$URL"
  if have lighthouse; then
    lighthouse "$URL" --quiet --chrome-flags="--headless=new" \
      --only-categories=performance,accessibility \
      --output=json --output-path="$out" >/dev/null 2>&1 || true
  else
    npx --no-install lighthouse "$URL" --quiet --chrome-flags="--headless=new" \
      --only-categories=performance,accessibility \
      --output=json --output-path="$out" >/dev/null 2>&1 || true
  fi

  if [ ! -s "$out" ]; then
    skip "Lighthouse produced no report (Chrome missing?) — skipping perf/a11y"
    return
  fi
  LH_RAN=1

  # metric extractor: jq preferred, node fallback
  metric() {
    local jqpath="$1" nodeexpr="$2"
    if have jq; then
      jq -r "$jqpath // empty" "$out" 2>/dev/null
    elif have node; then
      node -e "const d=require('$out');const v=$nodeexpr;process.stdout.write(v==null?'':String(v))" 2>/dev/null
    fi
  }

  local lcp cls tbt a11y
  lcp="$(metric '.audits["largest-contentful-paint"].numericValue' 'd.audits["largest-contentful-paint"].numericValue')"
  cls="$(metric '.audits["cumulative-layout-shift"].numericValue' 'd.audits["cumulative-layout-shift"].numericValue')"
  tbt="$(metric '.audits["total-blocking-time"].numericValue' 'd.audits["total-blocking-time"].numericValue')"
  a11y="$(metric '.categories.accessibility.score' 'd.categories.accessibility.score')"

  if [ -n "$lcp" ]; then
    if awk "BEGIN{exit !($lcp < 2500)}"; then ok "LCP ${lcp}ms < 2500ms"; else fail "LCP ${lcp}ms >= 2500ms"; fi
  else
    skip "LCP not reported"
  fi
  if [ -n "$cls" ]; then
    if awk "BEGIN{exit !($cls < 0.1)}"; then ok "CLS ${cls} < 0.1"; else fail "CLS ${cls} >= 0.1"; fi
  else
    skip "CLS not reported"
  fi
  if [ -n "$tbt" ]; then
    if awk "BEGIN{exit !($tbt < 200)}"; then ok "INP proxy (TBT) ${tbt}ms < 200ms"; else fail "INP proxy (TBT) ${tbt}ms >= 200ms"; fi
  else
    skip "TBT (INP proxy) not reported"
  fi
  if [ -n "$a11y" ]; then
    if awk "BEGIN{exit !($a11y >= 0.9)}"; then ok "a11y score ${a11y} >= 0.9"; else fail "a11y score ${a11y} < 0.9"; fi
  else
    skip "a11y score not reported"
  fi
}

# --- static design-review checks (always run, no network) -------------------
static_checks() {
  local hits

  # 1. more than one <h1> in any single file
  if have rg; then
    while IFS= read -r line; do
      [ -n "$line" ] && warn "multiple <h1> in one file: $line"
    done < <(rg -c '<h1' --glob '*.{tsx,jsx,html,vue,svelte}' . 2>/dev/null | awk -F: '$NF>1' || true)
  else
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if [ "$(grep -c '<h1' "$f" 2>/dev/null || echo 0)" -gt 1 ]; then warn "multiple <h1> in one file: $f"; fi
    done < <(grep -rl '<h1' . 2>/dev/null || true)
  fi

  # 2. transition: all / transition-all
  hits="$(search 'transition:\s*all|transition-all' 2>/dev/null || true)"
  if [ -n "$hits" ]; then warn "transition: all / transition-all found:"; printf '%s\n' "$hits" | head -n 5; fi

  # 3. hardcoded hex when a token system exists
  if search '@theme|--color-' >/dev/null 2>&1; then
    hits="$(search '#[0-9a-fA-F]{3,8}\b' 2>/dev/null | grep -E '\.(tsx|jsx|css)' || true)"
    if [ -n "$hits" ]; then warn "hardcoded hex colors despite a token system (heuristic):"; printf '%s\n' "$hits" | head -n 5; fi
  fi

  # 4. <img> / <Image without alt
  hits="$(search '<img(?![^>]*\balt=)|<Image(?![^>]*\balt=)' 2>/dev/null || true)"
  if [ -n "$hits" ]; then warn "image without alt= found:"; printf '%s\n' "$hits" | head -n 5; fi

  # 5. animations present but no prefers-reduced-motion anywhere
  if search '@keyframes|animation:|animate-' >/dev/null 2>&1; then
    if ! search 'prefers-reduced-motion' >/dev/null 2>&1; then
      warn "animations present but no prefers-reduced-motion guard found"
    fi
  fi

  # 6. ban-list marketing words in copy
  hits="$(search 'revolutionary|game-?changer|cutting-edge|supercharge|seamless|unlock' 2>/dev/null | grep -iE '\.(tsx|jsx|html|md|mdx)' || true)"
  if [ -n "$hits" ]; then warn "ban-list marketing words found in copy:"; printf '%s\n' "$hits" | head -n 5; fi
}

# --- fallback manual checklist ----------------------------------------------
print_checklist() {
  cat <<'EOF'

Manual design-review checklist (Lighthouse did not run):
  [ ] Value prop legible in 5 seconds above the fold.
  [ ] Text contrast >= 4.5:1 (3:1 for large text / UI).
  [ ] Visible focus state on all interactive elements.
  [ ] Touch targets >= 44x44px.
  [ ] prefers-reduced-motion honored.
  [ ] Exactly one <h1> on the page.
  [ ] Semantic landmarks present (header/nav/main/section/footer).
  [ ] LCP image has priority.
  [ ] Fonts use next/font (no CLS / FOUT swap shift).
  [ ] No transition: all / transition-all.
  [ ] Tokens used (no magic hex / px).
  [ ] Ban-list words absent from copy.
  [ ] Text fits at 360px and desktop without overflow.
  [ ] Empty / loading / hover / error states designed.
EOF
}

# --- run --------------------------------------------------------------------
run_lighthouse
static_checks
[ "$LH_RAN" -eq 0 ] && print_checklist

printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
