#!/usr/bin/env bash
#
# verify.sh — structural guardrail for a drafted newsletter issue.
#
# WHAT IT DOES (read-only; never edits or writes a file)
#   Static, network-free checks over ONE issue draft you point it at. The draft
#   is plain text / markdown with a `subject:` line, a `preview:` (or
#   `preheader:`) line, the issue body, and a footer. Checks:
#     1. Subject present and <= ceiling chars (default 50)        -> FAIL if over.
#     2. Subject payload position: first non-trivial word starts past char 33
#        (i.e. the line opens with filler)                        -> warn.
#     3. Preview/preheader present                                -> FAIL if missing.
#     4. Preview not byte-identical to the subject text           -> FAIL if same.
#     5. Emoji count in the subject <= 2, and the subject is not
#        all-emoji (must contain real word characters)            -> FAIL.
#     6. Exactly one primary CTA marker in the body. Convention: a single
#        line containing a "[CTA]" tag, an arrow "->"/"→" call, or a markdown
#        button-link. Zero -> warn; more than one -> FAIL.
#     7. An unsubscribe / opt-out line present anywhere           -> FAIL if missing.
#
#   A clean OR empty/whitespace-only file exits 0 — never a false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh issue.md                 # run all checks
#   ./verify.sh issue.md --ceiling 45    # tighten the subject ceiling
#   ./verify.sh issue.md --strict        # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, warnings only (without --strict), or empty/missing-content file
#   1  a hard failure — or any warning under --strict
#   2  bad usage (no file given, or file does not exist)
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays, no bc.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

FILE=""
CEILING=50
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --ceiling) CEILING="${2:-50}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) if [ -z "$FILE" ]; then FILE="$1"; fi; shift ;;
  esac
done

if [ -z "$FILE" ]; then
  printf '%sno issue file given%s\n' "$RED" "$NC" >&2; usage; exit 2
fi
if [ ! -f "$FILE" ]; then
  printf '%sfile not found: %s%s\n' "$RED" "$FILE" "$NC" >&2; exit 2
fi

# Empty / whitespace-only file: nothing to check, do not false-fail.
if [ ! -s "$FILE" ] || ! grep -q '[^[:space:]]' "$FILE" 2>/dev/null; then
  ok "empty file — nothing to check"
  exit 0
fi

printf 'newsletter verify — %s (subject ceiling=%s chars)\n\n' "$FILE" "$CEILING"

# --- extract subject + preview lines ------------------------------------------
# Take the first matching line for each, strip the label and surrounding space.
SUBJECT_LINE="$(grep -iE '^[[:space:]]*(subject|asunto|assumpte)[[:space:]]*:' "$FILE" | head -1 || true)"
PREVIEW_LINE="$(grep -iE '^[[:space:]]*(preview|preheader|prehead|previsualitzaci|vista previa)[^:]*:' "$FILE" | head -1 || true)"

SUBJECT="$(printf '%s' "$SUBJECT_LINE" | sed -E 's/^[[:space:]]*[A-Za-z]+[^:]*:[[:space:]]*//' | sed -E 's/[[:space:]]+$//')"
PREVIEW="$(printf '%s' "$PREVIEW_LINE" | sed -E 's/^[[:space:]]*[A-Za-z]+[^:]*:[[:space:]]*//' | sed -E 's/[[:space:]]+$//')"

# --- 1. subject present + length (hard) ---------------------------------------
if [ -z "$SUBJECT" ]; then
  fail "no subject line found (expected a line like 'subject: ...')"
else
  SLEN="$(printf '%s' "$SUBJECT" | wc -m | tr -d '[:space:]')"
  if [ "${SLEN:-0}" -gt "$CEILING" ]; then
    fail "subject is ${SLEN} chars (over the ${CEILING} ceiling) — it will truncate on mobile"
  else
    ok "subject length ${SLEN} chars (<= ${CEILING})"
  fi

  # --- 2. payload position (warn) ---------------------------------------------
  # Strip a leading run of common filler words; if the first "real" word lands
  # past char 33, the payload is buried.
  TRIMMED="$(printf '%s' "$SUBJECT" | sed -E 's/^([Tt]he|[Aa]|[Aa]n|[Ww]e|[Oo]ur|[Yy]ou|[Yy]our|[Hh]ey|[Hh]i|[Jj]ust|[Ss]o|[Vv]ery|[Ee]xcited|[Tt]o|[Ff]inally|[Aa]re|[Ii]s|[Tt]his|[Ii]ntroducing|[Aa]nnouncing)([[:space:]]+|$)//g')"
  ORIGLEN="$(printf '%s' "$SUBJECT" | wc -m | tr -d '[:space:]')"
  TRIMLEN="$(printf '%s' "$TRIMMED" | wc -m | tr -d '[:space:]')"
  PAYLOAD_AT=$(( ORIGLEN - TRIMLEN ))
  if [ "$PAYLOAD_AT" -gt 33 ]; then
    warn "subject payload appears to start past char ${PAYLOAD_AT} — front-load the hook into the first ~33 chars"
  else
    ok "subject payload is in the first ~33 chars"
  fi

  # --- 5. emoji rule (hard) ---------------------------------------------------
  # Strip ASCII + common punctuation/space; whatever multibyte remains is
  # treated as emoji/symbol glyphs. all-emoji => no ASCII word chars survive.
  WORDCHARS="$(printf '%s' "$SUBJECT" | tr -cd 'A-Za-z0-9' | wc -m | tr -d '[:space:]')"
  EMOJI_BYTES="$(printf '%s' "$SUBJECT" | LC_ALL=C tr -d '\000-\177' | wc -c | tr -d '[:space:]')"
  # A UTF-8 emoji is ~3-4 bytes; approximate the count conservatively.
  EMOJI_APPROX=$(( (EMOJI_BYTES + 3) / 4 ))
  if [ "${WORDCHARS:-0}" -eq 0 ]; then
    fail "subject has no real word characters — an all-emoji subject trips spam filters"
  elif [ "${EMOJI_APPROX:-0}" -gt 2 ]; then
    fail "subject looks like it has ~${EMOJI_APPROX} emoji (> 2) — keep it to <=2, at the end"
  else
    ok "subject emoji within limit (<=2, has real words)"
  fi
fi

# --- 3 + 4. preview present + not identical (hard) ----------------------------
if [ -z "$PREVIEW" ]; then
  fail "no preview/preheader line found — the preview is half the inbox row"
elif [ "$PREVIEW" = "$SUBJECT" ]; then
  fail "preview is identical to the subject — make it EXTEND the subject, not repeat it"
else
  ok "preview present and differs from the subject"
fi

# --- 6. exactly one primary CTA (hard on >1, warn on 0) -----------------------
# CTA convention: a line bearing a [CTA] tag, an arrow call-to-action, or a
# markdown button-link [text](url). Count distinct CTA-bearing lines.
CTA_COUNT="$(grep -cE '\[CTA\]|(->|→)[[:space:]]*[A-Za-z].*\[?https?://|\[[^]]+\]\((https?|mailto):' "$FILE" 2>/dev/null || true)"
# Fallback: also count plain "[CTA]" markers if the above missed link-less ones.
if [ "${CTA_COUNT:-0}" -eq 0 ]; then
  CTA_COUNT="$(grep -cE '\[CTA\]' "$FILE" 2>/dev/null || true)"
fi
if [ "${CTA_COUNT:-0}" -gt 1 ]; then
  fail "found ${CTA_COUNT} primary CTAs — one issue gets exactly one primary CTA"
elif [ "${CTA_COUNT:-0}" -eq 0 ]; then
  warn "no primary CTA detected (mark it with [CTA] or a button-link) — every issue needs one action"
else
  ok "exactly one primary CTA"
fi

# --- 7. unsubscribe line present (hard) ---------------------------------------
if grep -Eiq 'unsubscribe|opt[- ]out|darse de baja|cancelar la suscripci|dar-se de baixa|cancel·la la subscripci' "$FILE"; then
  ok "unsubscribe / opt-out line present"
else
  fail "no unsubscribe line found — one-click unsubscribe + a visible footer link are mandatory"
fi

# --- summary ------------------------------------------------------------------
printf '\n'
if [ "$fail_count" -gt 0 ]; then
  printf '%s%d hard failure(s), %d warning(s)%s\n' "$RED" "$fail_count" "$warn_count" "$NC"
  exit 1
fi
if [ "$warn_count" -gt 0 ]; then
  if [ "$STRICT" -eq 1 ]; then
    printf '%s%d warning(s) — failing under --strict%s\n' "$YELLOW" "$warn_count" "$NC"
    exit 1
  fi
  printf '%s%d warning(s), 0 hard failures%s\n' "$YELLOW" "$warn_count" "$NC"
  exit 0
fi
printf '%sall checks passed%s\n' "$GREEN" "$NC"
exit 0
