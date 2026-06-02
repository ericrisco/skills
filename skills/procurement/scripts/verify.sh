#!/usr/bin/env bash
#
# verify.sh — structural-consistency gate for the `procurement` skill.
#
# WHAT IT DOES (read-only; never edits a file)
#   Static lint over generated procurement artifacts. It checks SHAPE and
#   ARITHMETIC, never which supplier is the right pick (that is the capability
#   eval's job). For each candidate file found:
#
#   On a SCORECARD (a CSV/markdown table with a `weight` column):
#     1. Weights are present and SUM TO 100 (tol via --tol, default 1%).
#     2. Every supplier column has a score on every weighted criterion (no blanks).
#     3. If a weighted_total / total row is declared, recompute Σ(weight×score)
#        per supplier and assert it matches.
#
#   On a TCO comparison (a block mentioning unit/acquisition price):
#     4. It contains MORE than a unit line — at least one of
#        delivery/freight/maintenance/support/training/downtime/exit/disposal.
#
#   On a SOURCING REQUEST (an RFI/RFQ/RFP document):
#     5. It names evaluation criteria AND a deadline/due date — else warn.
#
#   Anywhere:
#     6. A line marked "single source" / "sole source" on a critical/strategic
#        item with NO accompanying backup/contingency line -> warn.
#     7. Placeholder tokens (TBD, XX, #REF, [supplier], ???) -> fail.
#
#   A missing/empty target is a SKIP, never a failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                          # scan ./ for procurement artifacts
#   ./verify.sh --path scorecard.csv     # check one file
#   ./verify.sh --path build/            # scan a directory
#   ./verify.sh --tol 0.02               # widen weight-sum / recompute tolerance
#   ./verify.sh --strict                 # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, empty target, or warnings only without --strict
#   1  a real failure (weights off 100, blank score, total mismatch, placeholder)
#   2  bad usage
#
# Runs on stock macOS bash 3.2: no mapfile, no associative arrays.

set -euo pipefail

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

usage() { sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'; }

SCAN_PATH="."
STRICT=0
TOL="0.01"
while [ $# -gt 0 ]; do
  case "$1" in
    --path)    SCAN_PATH="${2:?--path needs a value}"; shift 2 ;;
    --tol)     TOL="${2:?--tol needs a value}"; shift 2 ;;
    --strict)  STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown argument: %s%s\n\n' "$RED" "$1" "$NC"; usage; exit 2 ;;
  esac
done

emit() { printf '%s\n' "$1"; }   # findings go to stdout, tallied at the end

if [ ! -e "$SCAN_PATH" ]; then
  printf '%s[skip]%s path not found: %s — nothing to check\n' "$YELLOW" "$NC" "$SCAN_PATH"
  printf '\nok=0 skip=1 warn=0 fail=0\n'
  exit 0
fi

have() { command -v "$1" >/dev/null 2>&1; }
if ! have awk; then
  printf '%s[skip]%s awk not found — cannot parse; install awk\n' "$YELLOW" "$NC"
  printf '\nok=0 skip=1 warn=0 fail=0\n'
  exit 0
fi

# Collect candidate files: csv/md/txt that look like procurement artifacts.
FILES=""
if [ -f "$SCAN_PATH" ]; then
  FILES="$SCAN_PATH"
else
  FILES="$(find "$SCAN_PATH" -type f \( -name '*.csv' -o -name '*.md' -o -name '*.txt' \) \
            \( -iname '*scorecard*' -o -iname '*supplier*' -o -iname '*vendor*' \
               -o -iname '*tco*' -o -iname '*rfq*' -o -iname '*rfp*' -o -iname '*rfi*' \
               -o -iname '*sourcing*' -o -iname '*procure*' -o -iname '*quote*' \) \
            2>/dev/null || true)"
fi

if [ -z "$FILES" ]; then
  printf '%s[skip]%s no procurement artifact found under %s — nothing to check (clean)\n' "$YELLOW" "$NC" "$SCAN_PATH"
  printf '\nok=0 skip=1 warn=0 fail=0\n'
  exit 0
fi

OUT="$(mktemp -t proc_verify.XXXXXX 2>/dev/null || echo /tmp/proc_verify.$$)"
trap 'rm -f "$OUT" 2>/dev/null || true' EXIT

check_one() {
  f="$1"
  [ -s "$f" ] || { emit "SKIP empty file: $f"; return; }
  emit "HEAD —— $f"

  # 6/7 — whole-file lints (placeholders + silent single source).
  if grep -niE 'TBD|#REF|\[supplier\]|\[vendor\]|\?\?\?|(^|[,;[:space:]])XX([,;[:space:]]|$)' "$f" >/dev/null 2>&1; then
    emit "FAIL $f: placeholder token (TBD/XX/#REF/[supplier]/???) present"
  else
    emit "OK $f: no placeholder tokens"
  fi

  if grep -niE 'single[ -]?source|sole[ -]?source' "$f" >/dev/null 2>&1; then
    if grep -niE 'backup|contingenc|secondary supplier|dual[ -]?sourc|alternate supplier|fallback' "$f" >/dev/null 2>&1; then
      emit "OK $f: single/sole source named with a backup/contingency line"
    else
      emit "WARN $f: 'single/sole source' present but no backup/contingency line found"
    fi
  fi

  # 5 — sourcing request: needs criteria + a deadline.
  if grep -niE 'RF[IQP]\b|request for (information|quotation|proposal)|sourcing request' "$f" >/dev/null 2>&1; then
    has_crit=0; has_dead=0
    grep -niE 'evaluation criteria|criteria.*weight|weights?.*(sum|100)|scoring' "$f" >/dev/null 2>&1 && has_crit=1
    grep -niE 'deadline|due (by|date)|responses? due|valid through|submit by' "$f" >/dev/null 2>&1 && has_dead=1
    [ "$has_crit" -eq 1 ] && emit "OK $f: sourcing request discloses evaluation criteria" \
                          || emit "WARN $f: sourcing request names no evaluation criteria"
    [ "$has_dead" -eq 1 ] && emit "OK $f: sourcing request states a deadline" \
                          || emit "WARN $f: sourcing request states no deadline/due date"
  fi

  # 4 — TCO: more than a unit line.
  if grep -niE 'tco|total cost of ownership|acquisition' "$f" >/dev/null 2>&1 \
     || grep -niE 'unit price' "$f" >/dev/null 2>&1; then
    if grep -niE 'freight|delivery|shipping|maintenance|support|training|downtime|disposal|exit|residual|true[ -]?up' "$f" >/dev/null 2>&1; then
      emit "OK $f: cost comparison includes more than unit price"
    else
      emit "WARN $f: looks like a cost comparison but only a unit line — TCO needs freight/support/etc."
    fi
  fi

  # 1/2/3 — scorecard arithmetic (CSV-shaped tables with a weight column).
  #
  # SCOPING: a scorecard is ONE contiguous table. A blank line or a code-fence
  # marker (```) ends the current table; we evaluate it, then reset all state so
  # the next fenced block starts clean. Without this, a file that holds both a
  # scorecard CSV and a TCO comparison (e.g. references/scorecard-and-tco.md)
  # would let the parser keep `seen_header` set across blocks and treat TCO rows
  # (acquisition/freight/tco) as zero-score criteria — ~10 spurious failures.
  out="$(awk -v tol="$TOL" '
    function norm(s){ gsub(/^[ \t"|]+|[ \t"|]+$/,"",s); return tolower(s) }
    function num(s){ gsub(/[ \t"$,%|]/,"",s); if(s=="") return ""; if(s+0==s) return s+0; return "" }
    # Evaluate the table accumulated so far, then clear all per-table state.
    function flush_table(   k,d,diff,base){
      if(have_weight && wsum>0){
        found=1
        d = (wsum>100)?(wsum-100):(100-wsum)
        if (d > tol*100) printf "FAIL weights sum to %g, not 100\n", wsum
        else             printf "OK weights sum to %g (~100)\n", wsum
        if (has_total){
          for(k=1;k<=ns;k++){
            if(decl[k]=="") continue
            diff=(decl[k]>acc[k])?(decl[k]-acc[k]):(acc[k]-decl[k])
            base=(acc[k]<1)?1:acc[k]
            if (diff/base > tol*5)
              printf "FAIL %s weighted total %g != recomputed %g\n", sname[k], decl[k], acc[k]
            else
              printf "OK %s weighted total %g matches recompute %g\n", sname[k], decl[k], acc[k]
          }
        }
      }
      # reset every table-local accumulator
      seen_header=0; have_weight=0; wcol=0; ccol=0; ns=0; wsum=0; has_total=0
      delete scol; delete sname; delete acc; delete decl
    }
    BEGIN{ FS=","; have_weight=0; found=0 }
    # A blank line or a fence marker closes the current contiguous table.
    /^[ \t]*$/ || /^[ \t]*```/ { flush_table(); next }
    {
      line=$0
      # support markdown pipe tables too: convert | to , for parsing
      if (index(line,"|")>0 && index(line,",")==0){ gsub(/\|/,",",line); $0=line }
    }
    # header row: find the weight column + supplier columns
    !seen_header {
      for(i=1;i<=NF;i++){
        h=norm($i)
        if(h=="weight"||h=="weights"){ wcol=i; have_weight=1 }
        if(h=="criterion"||h=="criteria"){ ccol=i }
      }
      if(have_weight){
        seen_header=1
        # supplier columns = numeric-data columns that are not weight/criterion
        for(i=1;i<=NF;i++){
          if(i==wcol||i==ccol) continue
          h=norm($i)
          if(h!=""){ scol[++ns]=i; sname[ns]=h }
        }
        next
      }
      next
    }
    {
      crit = (ccol? norm($(ccol)) : "")
      w = num($(wcol))
      # the declared-total row (criterion says total/weighted_total)
      if (crit ~ /total/){
        for(k=1;k<=ns;k++){ decl[k]=num($(scol[k])) }
        has_total=1
        next
      }
      if (w=="") next
      wsum += w
      for(k=1;k<=ns;k++){
        v=num($(scol[k]))
        if(v==""){ printf "FAIL blank score for %s on criterion %s\n", sname[k], (crit?crit:NR) }
        else { acc[k]+=w*v }
      }
    }
    END{
      flush_table()        # close the last table if the file did not end on a boundary
      if(!found){ print "NOSCORE" }
    }
  ' "$f" 2>/dev/null)"

  if [ "$out" = "NOSCORE" ] || [ -z "$out" ]; then
    : # not a scorecard table; other checks already ran
  else
    printf '%s\n' "$out" | while IFS= read -r l; do
      [ -z "$l" ] && continue
      case "$l" in
        FAIL*) emit "FAIL $f: ${l#FAIL }" ;;
        OK*)   emit "OK $f: ${l#OK }" ;;
        WARN*) emit "WARN $f: ${l#WARN }" ;;
      esac
    done
  fi
}

printf 'Checking procurement artifacts under: %s (tol=%s)\n\n' "$SCAN_PATH" "$TOL"

: > "$OUT"
printf '%s\n' "$FILES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  check_one "$f"
done >> "$OUT" 2>&1 || true

# Render findings with color, tally as we go.
while IFS= read -r line; do
  case "$line" in
    HEAD*) printf '%s%s%s\n' "$YELLOW" "${line#HEAD }" "$NC" ;;
    OK*)   printf '%s[ ok ]%s %s\n' "$GREEN"  "$NC" "${line#OK }" ;;
    WARN*) printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "${line#WARN }" ;;
    FAIL*) printf '%s[fail]%s %s\n' "$RED"    "$NC" "${line#FAIL }" ;;
    SKIP*) printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "${line#SKIP }" ;;
  esac
done < "$OUT"

tally() { { grep -c "^$1" "$OUT" 2>/dev/null || true; } | tr -dc '0-9'; }
ok_count=$(tally 'OK');     ok_count=${ok_count:-0}
warn_count=$(tally 'WARN'); warn_count=${warn_count:-0}
fail_count=$(tally 'FAIL'); fail_count=${fail_count:-0}
skip_count=$(tally 'SKIP'); skip_count=${skip_count:-0}

printf '\nok=%d skip=%d warn=%d fail=%d\n' "$ok_count" "$skip_count" "$warn_count" "$fail_count"

cat <<'EOF'

Note: this gate proves the artifact is STRUCTURALLY SOUND (weights total 100, no
blank scores, totals recompute, TCO has more than a unit line, a sourcing request
names criteria + a deadline, a single source carries a backup). It does NOT judge
which supplier is correct — that is the capability eval's job. Re-run --strict to
gate CI on a clean pass.
EOF

if [ "$fail_count" -gt 0 ]; then exit 1; fi
if [ "$STRICT" -eq 1 ] && [ "$warn_count" -gt 0 ]; then exit 1; fi
exit 0
