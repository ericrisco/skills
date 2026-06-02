#!/usr/bin/env bash
#
# verify.sh — Angular modern-baseline copy-banlist (heuristic lint, NOT a compiler).
#
# USAGE
#   bash scripts/verify.sh [PATH ...]
#   Run from your Angular project root. With no args it scans ./src (falling back
#   to the current dir). Pass explicit paths to scope it to just-edited files:
#     bash scripts/verify.sh src/app/users
#
# WHAT IT DOES
#   Greps Angular .ts/.html sources for legacy patterns this skill bans, so the
#   agent can self-correct toward standalone + signals + built-in control flow:
#     - @NgModule in new code
#     - legacy structural directives  *ngIf / *ngFor / *ngSwitch
#     - decorator I/O  @Input() / @Output()
#     - @for blocks missing a `track` expression
#     - constructor-based DI (constructor(private x: X)) where inject() is the rule
#   Each hit prints file:line. It is a best-effort heuristic, not a parser, so it
#   may have false positives/negatives — treat it as a hint.
#
# GUARANTEES
#   - Read-only: never writes, fixes, installs, or hits the network.
#   - Exits 0 on an empty/clean target (no sources, or no hits) — no false failure.
#   - Exits 1 only when at least one banned pattern is found, so it can gate a loop.
#   - Portable to stock macOS bash 3.2 (no mapfile, no associative arrays).

set -u

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

hits=0
ok() { printf '%s\n' "${GREEN}ok${RESET}  $1"; }

# --- resolve scan roots -----------------------------------------------------
roots=""
if [ "$#" -gt 0 ]; then
  roots="$*"
elif [ -d ./src ]; then
  roots="./src"
else
  roots="."
fi

# Collect candidate Angular source files (.ts/.html), skipping vendor/build dirs
# and *.spec.ts / *.d.ts. Newline-delimited list; empty if nothing matches.
files="$(
  find $roots \
    \( -name node_modules -o -name dist -o -name .angular -o -name .git -o -name coverage \) -prune -o \
    -type f \( -name '*.ts' -o -name '*.html' \) \
    ! -name '*.spec.ts' ! -name '*.d.ts' -print 2>/dev/null
)"

if [ -z "$files" ]; then
  printf '%s\n' "${YELLOW}skip${RESET} no Angular .ts/.html sources under: $roots"
  exit 0
fi

# Grep a pattern across all files, reporting each match as "file:line: text".
# $1 = ERE pattern, $2 = human label. Counts hits into the global $hits.
scan() {
  pattern="$1"; label="$2"
  out="$(printf '%s\n' "$files" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -nE "$pattern" "$f" 2>/dev/null | sed "s|^|$f:|"
  done)"
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | while IFS= read -r m; do
      [ -n "$m" ] && printf '%s\n' "${RED}HIT${RESET} $label  $m"
    done
    n="$(printf '%s\n' "$out" | grep -c . )"
    hits=$((hits + n))
  else
    ok "no $label"
  fi
}

# @for openers that do NOT contain `track` on the same line — track is required.
scan_for_track() {
  out="$(printf '%s\n' "$files" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -nE '@for[[:space:]]*\(' "$f" 2>/dev/null | grep -v 'track' | sed "s|^|$f:|"
  done)"
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | while IFS= read -r m; do
      [ -n "$m" ] && printf '%s\n' "${RED}HIT${RESET} @for without track (track is required)  $m"
    done
    n="$(printf '%s\n' "$out" | grep -c . )"
    hits=$((hits + n))
  else
    ok "no @for without track"
  fi
}

printf '=== Angular banlist (%s files under %s) ===\n' "$(printf '%s\n' "$files" | grep -c .)" "$roots"

# 1. NgModule in new code.
scan '@NgModule' '@NgModule (use standalone components)'

# 2. Legacy structural directives.
scan '\*ng(If|For|Switch)\b' 'legacy *ngIf/*ngFor/*ngSwitch (use @if/@for/@switch)'

# 3. Decorator I/O.
scan '@(Input|Output)\(' '@Input()/@Output() decorator (use input()/output())'

# 4. @for blocks missing the required `track` expression.
scan_for_track

# 5. Constructor-based DI.
scan 'constructor[[:space:]]*\([^)]*(private|public|protected|readonly)[[:space:]]+[A-Za-z_]+[[:space:]]*:' 'constructor DI (use inject())'

printf '\n'
if [ "$hits" -gt 0 ]; then
  printf '%sFAIL%s %d banned-pattern hit(s) — migrate toward standalone + signals.\n' "$RED" "$RESET" "$hits"
  exit 1
fi
printf '%sPASS%s clean — no banned legacy Angular patterns found.\n' "$GREEN" "$RESET"
exit 0
