#!/usr/bin/env bash
#
# verify.sh — structural lint for a `content-engine` editorial calendar CSV.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static, network-free checks on one calendar CSV emitted by the skill.
#     1. A calendar artifact exists at the given path and has a header row.
#     2. Required columns present:
#        date,pillar,cluster,format,owner,stage,brief_link,atomization,mix
#     3. Every row's `stage` is an allowed pipeline state
#        (idea|brief|draft|edit|atomize|publish-ready).
#     4. Every flagship-format row (format starts with "flagship") has a non-empty
#        `brief_link` AND a non-empty `atomization` — the two hard rules (no flagship
#        slot without a brief or an atomization plan).
#     5. Mix sanity (warn only): warns if >80% of slots are evergreen, or if 0 slots
#        are left open/reactive (catches the over-planned / no-slack anti-pattern).
#
#   Hard failures (missing artifact, missing column, bad stage, flagship missing
#   brief/atomization) exit 1. Mix issues are warnings, not failures. A missing or
#   empty target is reported and exits 0 (no false failure on a clean/empty target).
#   Pure bash + awk, no dependencies. It is a lint, not a strategy oracle.
#
# HOW TO RUN
#   ./verify.sh path/to/calendar.csv     # lint one calendar
#   ./verify.sh                          # no target -> nothing to check, exit 0
#
# EXIT CODES
#   0  clean, or nothing to check
#   1  a hard structural failure
#   2  bad usage
#
# Runs on stock macOS bash 3.2.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

ok_count=0; warn_count=0; fail_count=0
ok()   { printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "$*"; ok_count=$((ok_count + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; warn_count=$((warn_count + 1)); }
fail() { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; fail_count=$((fail_count + 1)); }

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

summary_exit() {
  printf '\nok=%d warn=%d fail=%d\n' "$ok_count" "$warn_count" "$fail_count"
  [ "$fail_count" -gt 0 ] && exit 1
  exit 0
}

# --- arg parse --------------------------------------------------------------
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -*) printf 'unknown flag: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

# No target, or empty/missing file -> nothing to check, clean exit (no false fail).
if [ -z "$TARGET" ]; then
  ok "no calendar path given — nothing to lint"
  summary_exit
fi
if [ ! -f "$TARGET" ]; then
  warn "file not found: $TARGET — nothing to lint"
  summary_exit
fi
if [ ! -s "$TARGET" ]; then
  warn "file is empty: $TARGET — nothing to lint"
  summary_exit
fi

# --- header / required columns ---------------------------------------------
REQUIRED="date pillar cluster format owner stage brief_link atomization mix"

# Map column name -> 1-based index from the header.
get_idx() {
  awk -v want="$1" -F',' 'NR==1{for(i=1;i<=NF;i++){g=$i; gsub(/^[ \t]+|[ \t]+$/,"",g); if(g==want){print i; exit}}}' "$TARGET"
}

missing_cols=""
for col in $REQUIRED; do
  idx="$(get_idx "$col")"
  if [ -z "$idx" ]; then
    missing_cols="$missing_cols $col"
  fi
done

if [ -n "$missing_cols" ]; then
  fail "missing required column(s):$missing_cols"
  summary_exit
fi
ok "all required columns present"

STAGE_IDX="$(get_idx stage)"
FORMAT_IDX="$(get_idx format)"
BRIEF_IDX="$(get_idx brief_link)"
ATOM_IDX="$(get_idx atomization)"
MIX_IDX="$(get_idx mix)"

# --- per-row checks (awk emits FAIL:/WARN:/STAT: lines we count below) ------
RESULT="$(awk -F',' \
  -v si="$STAGE_IDX" -v fi="$FORMAT_IDX" -v bi="$BRIEF_IDX" -v ai="$ATOM_IDX" -v mi="$MIX_IDX" '
  function trim(s){ gsub(/^[ \t\r]+|[ \t\r]+$/,"",s); return s }
  NR==1 { next }
  trim($0)=="" { next }
  {
    total++
    stage=trim($si); fmt=trim($fi); brief=trim($bi); atom=trim($ai); mix=trim($mi)
    if (stage !~ /^(idea|brief|draft|edit|atomize|publish-ready)$/)
      print "FAIL:row " NR ": stage \"" stage "\" not an allowed pipeline state"
    if (fmt ~ /^flagship/) {
      flagship++
      if (brief == "") print "FAIL:row " NR ": flagship \"" fmt "\" has empty brief_link"
      if (atom  == "") print "FAIL:row " NR ": flagship \"" fmt "\" has empty atomization plan"
    }
    if (mix == "evergreen") evergreen++
    if (mix == "reactive-open" || fmt ~ /reactive/) reactive++
  }
  END {
    if (total > 0) {
      ev_pct = (evergreen*100)/total
      if (ev_pct > 80) printf "WARN:%d%% of slots are evergreen (>80%%) — thin on timely/experimental mix\n", ev_pct
      if (reactive == 0) print "WARN:0 slots left open/reactive — calendar has no slack to react"
    }
    printf "STAT:total=%d flagship=%d evergreen=%d reactive=%d\n", total, flagship+0, evergreen+0, reactive+0
  }
' "$TARGET")"

while IFS= read -r line; do
  case "$line" in
    FAIL:*) fail "${line#FAIL:}" ;;
    WARN:*) warn "${line#WARN:}" ;;
    STAT:*) ok  "rows checked — ${line#STAT:}" ;;
  esac
done <<EOF
$RESULT
EOF

summary_exit
