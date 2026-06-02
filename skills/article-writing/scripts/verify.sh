#!/usr/bin/env bash
#
# verify.sh — structural + banlist lint for an `article-writing` draft.
#
# Usage: scripts/verify.sh path/to/article.md
#
# Read-only. Checks the on-page surface and banned phrasing of a single
# article markdown file. It is a lint of STRUCTURE and PHRASING, not a
# judge of whether the content is good — that is the capability eval's job.
#
# Exit 0 = all hard checks pass (or nothing to check). Exit 1 = a hard
# check failed. Warnings never fail the run.
#
# The file is expected to carry, in YAML front-matter or a clearly
# labelled block, a `title:` and `meta_description:` line, plus a JSON-LD
# block (```json or <script type="application/ld+json">).

set -u

TARGET="${1:-}"

# --- No target / empty target: pass cleanly, never a false failure. -------
if [ -z "$TARGET" ]; then
  echo "verify.sh: no article path given — nothing to check. PASS"
  exit 0
fi
if [ ! -f "$TARGET" ]; then
  echo "verify.sh: '$TARGET' is not a file — nothing to check. PASS"
  exit 0
fi
if [ ! -s "$TARGET" ]; then
  echo "verify.sh: '$TARGET' is empty — nothing to check. PASS"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BANLIST_FILE="$SCRIPT_DIR/../references/ai-tell-banlist.md"

fail=0
warn=0
pass() { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=1; }
note() { printf 'WARN  %s\n' "$1"; warn=1; }

# --- 1. Title length ------------------------------------------------------
# Grab the first `title:` value (front-matter or labelled block).
title_line="$(grep -i -m1 -E '^[[:space:]]*title[[:space:]]*:' "$TARGET" || true)"
if [ -z "$title_line" ]; then
  note "no 'title:' line found — cannot check title length"
else
  title_val="$(printf '%s' "$title_line" | sed -E 's/^[[:space:]]*[Tt][Ii][Tt][Ll][Ee][[:space:]]*:[[:space:]]*//; s/^["'\'']//; s/["'\''][[:space:]]*$//')"
  tlen=${#title_val}
  if [ "$tlen" -ge 50 ] && [ "$tlen" -le 60 ]; then
    pass "title is $tlen chars (50-60 band)"
  elif [ "$tlen" -ge 45 ] && [ "$tlen" -le 65 ]; then
    note "title is $tlen chars (outside 50-60, inside 45-65 tolerance)"
  else
    bad "title is $tlen chars (target 50-60): \"$title_val\""
  fi
fi

# --- 2. Meta description length ------------------------------------------
meta_line="$(grep -i -m1 -E '^[[:space:]]*(meta_description|meta|description)[[:space:]]*:' "$TARGET" || true)"
if [ -z "$meta_line" ]; then
  note "no 'meta_description:' line found — cannot check meta length"
else
  meta_val="$(printf '%s' "$meta_line" | sed -E 's/^[[:space:]]*[A-Za-z_]+[[:space:]]*:[[:space:]]*//; s/^["'\'']//; s/["'\''][[:space:]]*$//')"
  mlen=${#meta_val}
  if [ "$mlen" -ge 140 ] && [ "$mlen" -le 160 ]; then
    pass "meta description is $mlen chars (140-160 band)"
  elif [ "$mlen" -ge 120 ] && [ "$mlen" -le 170 ]; then
    note "meta description is $mlen chars (outside 140-160, inside 120-170 tolerance)"
  else
    bad "meta description is $mlen chars (target 140-160)"
  fi
fi

# --- 3. Exactly one H1, at least two H2s ----------------------------------
h1_count="$(grep -c -E '^# [^#]' "$TARGET" || true)"
h2_count="$(grep -c -E '^## [^#]' "$TARGET" || true)"
if [ "$h1_count" -eq 1 ]; then
  pass "exactly one H1"
else
  bad "found $h1_count H1 headings (need exactly 1)"
fi
if [ "$h2_count" -ge 2 ]; then
  pass "$h2_count H2 headings (>=2)"
else
  bad "found $h2_count H2 headings (need >=2)"
fi

# --- 4. JSON-LD present with Article/BlogPosting; FAQPage if FAQ exists ----
has_jsonld=0
grep -q -E 'application/ld\+json' "$TARGET" && has_jsonld=1
grep -q -E '"@type"[[:space:]]*:[[:space:]]*"(Article|BlogPosting)"' "$TARGET" && has_jsonld=1
if grep -q -E '"@type"[[:space:]]*:[[:space:]]*"(Article|BlogPosting)"' "$TARGET"; then
  pass "JSON-LD has @type Article/BlogPosting"
elif [ "$has_jsonld" -eq 1 ]; then
  bad "JSON-LD block present but no @type Article/BlogPosting"
else
  bad "no JSON-LD block with @type Article/BlogPosting found"
fi

# FAQ section present? (English / Catalan / Spanish heading)
if grep -q -i -E '^#{1,3}[[:space:]].*(faq|preguntes|preguntas|frequently asked)' "$TARGET"; then
  if grep -q -E '"@type"[[:space:]]*:[[:space:]]*"FAQPage"' "$TARGET"; then
    pass "FAQ section has matching FAQPage JSON-LD"
  else
    bad "FAQ section present but no FAQPage JSON-LD"
  fi
fi

# --- 5. At least one internal-link slot (relative / site path) ------------
# Markdown link whose target is not an absolute external http(s) URL.
if grep -q -E '\]\((/|\.{1,2}/|#)[^)]*\)' "$TARGET"; then
  pass "internal-link slot present"
else
  note "no internal-link slot found (target 3-5 contextual internal links)"
fi

# --- 6. AI-tell / fluff banlist scan -------------------------------------
if [ ! -f "$BANLIST_FILE" ]; then
  note "banlist file not found at $BANLIST_FILE — skipping phrase scan"
else
  # Extract the fenced ```text BANLIST block: lines between the first
  # ```text after the '## BANLIST' header and the next ``` fence.
  banlist="$(awk '
    /^## BANLIST/      { insec=1; next }
    insec && /^```text/ { infence=1; next }
    infence && /^```/   { infence=0; insec=0; next }
    infence            { print }
  ' "$BANLIST_FILE")"

  hits=0
  while IFS= read -r phrase; do
    [ -z "$phrase" ] && continue
    # strip a trailing comma-only token nuance; match literal, case-insensitive
    if matches="$(grep -i -n -F -- "$phrase" "$TARGET")"; then
      while IFS= read -r m; do
        [ -z "$m" ] && continue
        printf 'BANNED  "%s"  -> %s\n' "$phrase" "$m"
        hits=$((hits + 1))
      done <<< "$matches"
    fi
  done <<< "$banlist"

  if [ "$hits" -eq 0 ]; then
    pass "banlist scan clean (0 matches)"
  else
    bad "banlist scan found $hits AI-tell/fluff match(es) — rewrite the lines above"
  fi
fi

# --- Summary --------------------------------------------------------------
echo "---"
if [ "$fail" -ne 0 ]; then
  echo "verify.sh: FAIL (one or more hard checks failed)"
  exit 1
fi
if [ "$warn" -ne 0 ]; then
  echo "verify.sh: PASS with warnings"
else
  echo "verify.sh: PASS"
fi
exit 0
