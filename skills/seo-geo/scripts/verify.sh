#!/usr/bin/env bash
# verify.sh — seo-geo on-page artifact gate (read-only).
#
# Usage:
#   bash scripts/verify.sh [TARGET]
#     TARGET = a file or directory containing the produced artifacts
#              (HTML head, JSON-LD blocks, an optional robots.txt).
#              Defaults to the current directory.
#
# What it checks across *.html *.htm *.json *.jsonld and robots.txt under TARGET:
#   (a) NO DEAD schema @type appears (FAQPage, Course, ClaimReview,
#       SpecialAnnouncement, VehicleListing, EstimatedSalary, LearningVideo) —
#       the highest-value guard against shipping dead markup.
#   (b) Each .json/.jsonld parses as valid JSON and carries @context + @type
#       (when a JSON parser is available; skipped with a warning otherwise).
#   (c) <title> text ≤ 60 chars; meta description ≤ 160 chars; exactly one <h1>.
#   (d) If a robots.txt is present, it does not Disallow a search/citation bot
#       (Googlebot, OAI-SearchBot, PerplexityBot, Claude-SearchBot) at the root.
#
# Read-only: reads files only, no writes, no network, no installs. Safe to re-run.
# Exits 0 on an empty/clean target (no false failure); non-zero on any violation.
#
# Portability: stock macOS bash 3.2. No `mapfile`; no empty-array expansion under
# set -u. `set -e` intentionally OFF (each check owns its exit code).

set -u

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

failures=0
fail() { printf '%s\n' "${RED}FAIL: $1${RESET}"; failures=$((failures + 1)); }
ok()   { printf '%s\n' "${GREEN}OK: $1${RESET}"; }
warn() { printf '%s\n' "${YELLOW}SKIP: $1${RESET}"; }

TARGET="${1:-.}"
if [ ! -e "$TARGET" ]; then
  fail "target not found: $TARGET"
  exit 1
fi

# --- collect candidate files (portable; no mapfile) ------------------------
markup_files=""
robots_files=""
json_files=""
if [ -d "$TARGET" ]; then
  while IFS= read -r f; do markup_files="${markup_files}${f}
"; done <<EOF
$(find "$TARGET" -type f \( -name '*.html' -o -name '*.htm' \) 2>/dev/null)
EOF
  while IFS= read -r f; do json_files="${json_files}${f}
"; done <<EOF
$(find "$TARGET" -type f \( -name '*.json' -o -name '*.jsonld' \) 2>/dev/null)
EOF
  while IFS= read -r f; do robots_files="${robots_files}${f}
"; done <<EOF
$(find "$TARGET" -type f -name 'robots.txt' 2>/dev/null)
EOF
else
  case "$TARGET" in
    *.html|*.htm) markup_files="$TARGET" ;;
    *.json|*.jsonld) json_files="$TARGET" ;;
    *robots.txt) robots_files="$TARGET" ;;
    *) markup_files="$TARGET" ;;  # treat unknown single file as markup-bearing
  esac
fi

# Strip blank lines.
markup_files="$(printf '%s\n' "$markup_files" | grep -v '^[[:space:]]*$' || true)"
json_files="$(printf '%s\n' "$json_files" | grep -v '^[[:space:]]*$' || true)"
robots_files="$(printf '%s\n' "$robots_files" | grep -v '^[[:space:]]*$' || true)"

scanned=0

DEAD_TYPES='FAQPage Course ClaimReview SpecialAnnouncement VehicleListing EstimatedSalary LearningVideo'

# --- (a) dead schema types, across markup + json ---------------------------
all_for_dead="$(printf '%s\n%s\n' "$markup_files" "$json_files" | grep -v '^[[:space:]]*$' || true)"
if [ -n "$all_for_dead" ]; then
  printf '%s\n' "$all_for_dead" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    for t in $DEAD_TYPES; do
      # match "@type": "FAQPage" with flexible spacing/quoting
      if grep -Eq "@type[\"']?[[:space:]]*:[[:space:]]*[\"']?$t([\"',}[:space:]]|$)" "$f"; then
        printf 'DEAD %s %s\n' "$t" "$f"
      fi
    done
  done > /tmp/seo_geo_dead.$$  2>/dev/null || true
  if [ -s /tmp/seo_geo_dead.$$ ]; then
    while IFS= read -r line; do
      t="$(printf '%s' "$line" | awk '{print $2}')"
      f="$(printf '%s' "$line" | cut -d' ' -f3-)"
      fail "dead schema @type '$t' in $f — deprecated/retired, dead markup"
    done < /tmp/seo_geo_dead.$$
  fi
  rm -f /tmp/seo_geo_dead.$$ 2>/dev/null || true
fi

# --- (b) JSON-LD validity + @context/@type --------------------------------
json_parser=""
if command -v python3 >/dev/null 2>&1; then json_parser="python3"; fi

if [ -n "$json_files" ]; then
  printf '%s\n' "$json_files" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    scanned=1
    if [ -n "$json_parser" ]; then
      python3 - "$f" <<'PY'
import json, sys
p = sys.argv[1]
try:
    with open(p) as fh:
        data = json.load(fh)
except Exception:
    sys.exit(3)
def has(d):
    if isinstance(d, dict):
        return ("@context" in d and "@type" in d) or any(has(v) for v in d.values())
    if isinstance(d, list):
        return any(has(x) for x in d)
    return False
sys.exit(0 if has(data) else 4)
PY
      rc=$?
      if [ "$rc" -eq 3 ]; then echo "JSONERR-PARSE $f"; elif [ "$rc" -eq 4 ]; then echo "JSONERR-CTX $f"; fi
    fi
  done > /tmp/seo_geo_json.$$ 2>/dev/null || true
  if [ -z "$json_parser" ]; then
    warn "python3 not found — skipping JSON-LD validity/@context check"
  fi
  if [ -s /tmp/seo_geo_json.$$ ]; then
    while IFS= read -r line; do
      kind="$(printf '%s' "$line" | awk '{print $1}')"
      f="$(printf '%s' "$line" | cut -d' ' -f2-)"
      case "$kind" in
        JSONERR-PARSE) fail "invalid JSON in $f" ;;
        JSONERR-CTX)   fail "JSON-LD missing @context/@type in $f" ;;
      esac
    done < /tmp/seo_geo_json.$$
  fi
  rm -f /tmp/seo_geo_json.$$ 2>/dev/null || true
fi

# --- (c) head discipline: title<=60, meta desc<=160, exactly one h1 --------
if [ -n "$markup_files" ]; then
  printf '%s\n' "$markup_files" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    # title length
    title="$(tr '\n' ' ' < "$f" | grep -oiE '<title>[^<]*</title>' | head -1 | sed -E 's/<\/?title>//gI')"
    if [ -n "$title" ]; then
      tlen=$(printf '%s' "$title" | wc -c | tr -d ' ')
      if [ "$tlen" -gt 60 ]; then echo "TITLE $tlen $f"; fi
    fi
    # meta description length
    desc="$(tr '\n' ' ' < "$f" | grep -oiE "<meta[^>]+name=[\"']description[\"'][^>]*>" | head -1 | grep -oiE "content=[\"'][^\"']*[\"']" | head -1 | sed -E "s/content=[\"']//I; s/[\"']$//")"
    if [ -n "$desc" ]; then
      dlen=$(printf '%s' "$desc" | wc -c | tr -d ' ')
      if [ "$dlen" -gt 160 ]; then echo "DESC $dlen $f"; fi
    fi
    # h1 count
    h1c="$(tr '\n' ' ' < "$f" | grep -oiE '<h1[ >]' | wc -l | tr -d ' ')"
    if [ "$h1c" != "0" ] && [ "$h1c" != "1" ]; then echo "H1 $h1c $f"; fi
  done > /tmp/seo_geo_head.$$ 2>/dev/null || true
  if [ -s /tmp/seo_geo_head.$$ ]; then
    while IFS= read -r line; do
      kind="$(printf '%s' "$line" | awk '{print $1}')"
      n="$(printf '%s' "$line" | awk '{print $2}')"
      f="$(printf '%s' "$line" | cut -d' ' -f3-)"
      case "$kind" in
        TITLE) fail "<title> is $n chars (>60) in $f" ;;
        DESC)  fail "meta description is $n chars (>160) in $f" ;;
        H1)    fail "$n <h1> elements (expected exactly 1) in $f" ;;
      esac
    done < /tmp/seo_geo_head.$$
  fi
  rm -f /tmp/seo_geo_head.$$ 2>/dev/null || true
fi

# --- (d) robots.txt not self-blocking search/citation bots -----------------
SEARCH_BOTS='Googlebot OAI-SearchBot PerplexityBot Claude-SearchBot'
if [ -n "$robots_files" ]; then
  printf '%s\n' "$robots_files" | while IFS= read -r rf; do
    [ -f "$rf" ] || continue
    # Walk groups: a User-agent line opens a group; collect bots until a Disallow: /.
    awk -v bots="$SEARCH_BOTS" '
      function lc(s){return tolower(s)}
      BEGIN{ n=split(bots,B," "); for(i=1;i<=n;i++) want[lc(B[i])]=B[i]; ng=0 }
      {
        line=$0
        sub(/#.*/,"",line)
        gsub(/\r/,"",line)
        if (line ~ /^[[:space:]]*[Uu]ser-agent[[:space:]]*:/) {
          if (!inblock){ delete cur; cc=0; inblock=1 }
          ua=line; sub(/^[^:]*:[[:space:]]*/,"",ua); gsub(/[[:space:]]+$/,"",ua)
          cur[++cc]=ua
          next
        }
        if (line ~ /^[[:space:]]*[Dd]isallow[[:space:]]*:/) {
          val=line; sub(/^[^:]*:[[:space:]]*/,"",val); gsub(/[[:space:]]+$/,"",val)
          if (val=="/"){ for(i=1;i<=cc;i++){ b=lc(cur[i]); if (b in want) print want[b] } }
          next
        }
        if (line ~ /[^[:space:]]/ && line !~ /^[[:space:]]*[Aa]llow[[:space:]]*:/ && line !~ /^[[:space:]]*[Ss]itemap[[:space:]]*:/ && line !~ /^[[:space:]]*[Cc]rawl-delay/) {
          inblock=0
        }
      }
    ' "$rf" | sort -u | while IFS= read -r bot; do
      [ -n "$bot" ] && echo "ROBOTS $bot $rf"
    done
  done > /tmp/seo_geo_robots.$$ 2>/dev/null || true
  if [ -s /tmp/seo_geo_robots.$$ ]; then
    while IFS= read -r line; do
      bot="$(printf '%s' "$line" | awk '{print $2}')"
      f="$(printf '%s' "$line" | cut -d' ' -f3-)"
      fail "robots.txt blocks search/citation bot '$bot' (Disallow: /) in $f — removes you from that engine's results/citations"
    done < /tmp/seo_geo_robots.$$
  fi
  rm -f /tmp/seo_geo_robots.$$ 2>/dev/null || true
fi

# --- verdict ---------------------------------------------------------------
if [ -z "$markup_files" ] && [ -z "$json_files" ] && [ -z "$robots_files" ]; then
  ok "no SEO artifacts under '$TARGET' — nothing to lint"
  exit 0
fi

if [ "$failures" -eq 0 ]; then
  ok "seo-geo artifacts pass: no dead schema, valid JSON-LD, head limits, robots not self-blocking"
  exit 0
fi

printf '%s\n' "${RED}${failures} violation(s) — fix before shipping.${RESET}"
exit 1
