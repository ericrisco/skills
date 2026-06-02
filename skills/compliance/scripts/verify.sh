#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NAME
#   verify.sh — lint a compliance control register
#
# USAGE
#   ./verify.sh <register.md|register.csv>
#   ./verify.sh                       # no arg / empty target -> exits 0
#
# WHAT IT DOES
#   1. Detects the register format (Markdown table or CSV).
#   2. Asserts the required columns exist:
#        control-id, framework, owner, evidence, cadence, status
#      (last-verified is recommended, not required).
#   3. FAILS if any data row is missing owner / evidence / cadence — the
#      cardinal sin of "checklist theater": a control nobody owns and nothing
#      proves.
#   4. WARNS (does not fail) if a framework named in a leading `scope:` line
#      has zero mapped controls in the register.
#
# GUARANTEES
#   - Read-only: never writes to or modifies the target.
#   - No dependencies beyond bash + awk + grep (stock macOS bash 3.2 OK).
#   - Exits 0 on a missing arg, an empty file, or a clean register — never a
#     false failure on nothing.
#
# EXIT CODES
#   0  Clean / empty / nothing to check.
#   1  At least one row missing owner, evidence, or cadence; or a required
#      column is absent.
# ============================================================================

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
if [ -n "${NO_COLOR:-}" ]; then RED=""; YEL=""; GRN=""; RST=""; fi

ok()   { printf '%s[ok]%s %s\n'   "$GRN" "$RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YEL" "$RST" "$*" >&2; }
bad()  { printf '%s[FAIL]%s %s\n' "$RED" "$RST" "$*" >&2; }

TARGET="${1:-}"

# No target, or it is not a regular file, or it is empty -> nothing to verify.
if [ -z "$TARGET" ]; then
  ok "no register given — nothing to verify"
  exit 0
fi
if [ ! -f "$TARGET" ]; then
  warn "register not found: $TARGET — nothing to verify"
  exit 0
fi
if [ ! -s "$TARGET" ]; then
  ok "register is empty — nothing to verify"
  exit 0
fi

REQUIRED="control-id framework owner evidence cadence status"

# awk does the parsing for both Markdown-pipe and CSV registers.
# It prints lint lines on stderr (FAIL:/WARN:) and the final verdict marker.
RESULT="$(awk -v required="$REQUIRED" '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  function norm(s) { s=trim(s); gsub(/[ \t]+/, " ", s); return tolower(s) }

  BEGIN {
    nreq = split(required, req, " ")
    delim = "|"            # assume markdown until a CSV header proves otherwise
    have_header = 0
    fails = 0
    rows = 0
  }

  # Capture a scope: line (markdown or plain) before the header.
  !have_header && tolower($0) ~ /^[ \t]*scope[ \t]*:/ {
    line = $0
    sub(/^[ \t]*[Ss][Cc][Oo][Pp][Ee][ \t]*:[ \t]*/, "", line)
    n = split(line, parts, /[,;]/)
    for (i = 1; i <= n; i++) {
      f = norm(parts[i])
      if (f != "") scope[f] = 1
    }
    next
  }

  # Skip markdown separator rows like | --- | --- |
  /^[ \t]*\|?[ \t:-]*\|[ \t:|-]*$/ && have_header { next }

  {
    raw = $0
    # Choose delimiter from the header line.
    if (!have_header) {
      if (raw ~ /\|/) delim = "|"; else if (raw ~ /,/) delim = ","; else next
    }

    # Split the row on the chosen delimiter.
    if (delim == "|") {
      sub(/^[ \t]*\|/, "", raw); sub(/\|[ \t]*$/, "", raw)
      ncol = split(raw, cells, /\|/)
    } else {
      ncol = split(raw, cells, /,/)
    }

    if (!have_header) {
      for (c = 1; c <= ncol; c++) {
        h = norm(cells[c])
        colidx[h] = c
      }
      # Verify required columns are present.
      missing = ""
      for (k = 1; k <= nreq; k++) {
        if (!(req[k] in colidx)) missing = missing " " req[k]
      }
      if (missing != "") {
        print "FAIL: missing required column(s):" missing > "/dev/stderr"
        fails++
      }
      have_header = 1
      next
    }

    rows++
    rownum = rows

    for (k = 1; k <= nreq; k++) {
      name = req[k]
      if (name != "owner" && name != "evidence" && name != "cadence") continue
      ci = colidx[name]
      val = (ci <= ncol) ? trim(cells[ci]) : ""
      if (val == "" || val == "-" || tolower(val) == "tbd" || tolower(val) == "n/a") {
        idc = colidx["control-id"]
        cid = (idc <= ncol) ? trim(cells[idc]) : ("row " rownum)
        print "FAIL: control [" cid "] has empty " name > "/dev/stderr"
        fails++
      }
    }

    # Record which scoped frameworks are referenced by some control.
    fc = colidx["framework"]
    fval = (fc <= ncol) ? norm(cells[fc]) : ""
    for (s in scope) { if (index(fval, s) > 0) seen[s] = 1 }
  }

  END {
    for (s in scope) {
      if (!(s in seen))
        print "WARN: scoped framework \"" s "\" has zero mapped controls" > "/dev/stderr"
    }
    print "ROWS=" rows " FAILS=" fails
  }
' "$TARGET")"

ROWS="$(printf '%s\n' "$RESULT" | sed -n 's/.*ROWS=\([0-9]*\).*/\1/p')"
FAILS="$(printf '%s\n' "$RESULT" | sed -n 's/.*FAILS=\([0-9]*\).*/\1/p')"
ROWS="${ROWS:-0}"; FAILS="${FAILS:-0}"

if [ "$ROWS" -eq 0 ] && [ "$FAILS" -eq 0 ]; then
  ok "no data rows found — nothing to verify"
  exit 0
fi

if [ "$FAILS" -gt 0 ]; then
  bad "$FAILS issue(s) in register — fix owner/evidence/cadence gaps before audit"
  exit 1
fi

ok "register clean: $ROWS control(s), required columns present, no owner/evidence/cadence gaps"
exit 0
