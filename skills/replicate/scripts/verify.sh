#!/usr/bin/env bash
#
# verify.sh — static lint for a Replicate/Cog artifact dir (read-only, network-free).
#
# WHAT IT DOES (never edits, builds, or runs Docker)
#   Points at a directory you emitted (default: current dir) and checks the
#   things that are mechanically wrong before any Cog build:
#     1. cog.yaml present -> must declare a top-level `build:` and a `predict:`
#        key. A present-but-malformed cog.yaml is a HARD failure.
#     2. predict.py present -> should define a `Predictor` class with both
#        `setup` and `predict` methods (warn if missing — naming is conventional
#        but Cog needs the class your cog.yaml names).
#     3. requirements/pyproject pinning -> an unpinned `replicate` dep warns
#        (a fresh resolve can pull the 2.0 alpha).
#     4. FileOutput misuse -> Python that writes a run()/predict output object
#        directly to a text file (e.g. write(output[0])) without .read()/.url
#        warns.
#
#   Only a malformed cog.yaml is a hard failure. A dir with no cog.yaml and no
#   Python (nothing to check) exits 0 — never a false failure.
#
# HOW TO RUN (inside YOUR project, not the skills repo)
#   ./verify.sh                 # check current directory
#   ./verify.sh path/to/dir     # check a specific artifact dir
#   ./verify.sh dir --strict    # treat warnings as failures (CI gate)
#
# EXIT CODES
#   0  clean, warnings-only (without --strict), or nothing to check
#   1  a hard failure (malformed cog.yaml) — or any warning under --strict
#   2  bad usage (target dir does not exist)
#
# Runs on stock macOS bash 3.2.

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

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

DIR="."
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --strict) STRICT=1; shift ;;
    -*) printf '%sunknown option: %s%s\n' "$RED" "$1" "$NC" >&2; usage; exit 2 ;;
    *) DIR="$1"; shift ;;
  esac
done

if [ ! -d "$DIR" ]; then
  printf '%starget dir not found: %s%s\n' "$RED" "$DIR" "$NC" >&2; exit 2
fi

printf 'replicate verify — %s\n\n' "$DIR"

checked_anything=0

# --- 1. cog.yaml: build: + predict: keys (hard) -------------------------------
COG="$DIR/cog.yaml"
if [ -f "$COG" ]; then
  checked_anything=1
  missing=""
  grep -Eq '^[[:space:]]*build[[:space:]]*:' "$COG" || missing="build:"
  if ! grep -Eq '^[[:space:]]*predict[[:space:]]*:' "$COG"; then
    missing="${missing:+$missing and }predict:"
  fi
  if [ -n "$missing" ]; then
    fail "cog.yaml is missing required key(s): $missing"
  else
    ok "cog.yaml declares build: and predict:"
  fi
else
  ok "no cog.yaml in $DIR — skipping Cog config checks"
fi

# --- 2. predict.py: Predictor with setup + predict ----------------------------
# Find a predictor module: prefer predict.py, else any *.py with a BasePredictor.
PRED=""
if [ -f "$DIR/predict.py" ]; then
  PRED="$DIR/predict.py"
else
  PRED="$(grep -rlE 'BasePredictor|class[[:space:]]+Predictor' "$DIR" --include='*.py' 2>/dev/null | head -1 || true)"
fi
if [ -n "$PRED" ] && [ -f "$PRED" ]; then
  checked_anything=1
  has_class=0; has_setup=0; has_predict=0
  grep -Eq 'class[[:space:]]+\w+\(.*Predictor.*\)|class[[:space:]]+Predictor' "$PRED" && has_class=1
  grep -Eq '^[[:space:]]*def[[:space:]]+setup[[:space:]]*\(' "$PRED" && has_setup=1
  grep -Eq '^[[:space:]]*def[[:space:]]+predict[[:space:]]*\(' "$PRED" && has_predict=1
  if [ "$has_class" -eq 1 ] && [ "$has_setup" -eq 1 ] && [ "$has_predict" -eq 1 ]; then
    ok "$(basename "$PRED") has a Predictor with setup() and predict()"
  else
    [ "$has_class" -eq 0 ]   && warn "$(basename "$PRED"): no Predictor class found"
    [ "$has_setup" -eq 0 ]   && warn "$(basename "$PRED"): no setup() — load weights once here, not per request"
    [ "$has_predict" -eq 0 ] && warn "$(basename "$PRED"): no predict() method found"
  fi
fi

# --- 3. unpinned replicate dependency -----------------------------------------
DEPFILES="$(grep -rlE '(^|[^a-zA-Z_-])replicate([^a-zA-Z_-]|$)' \
  "$DIR" --include='requirements*.txt' --include='pyproject.toml' 2>/dev/null || true)"
if [ -n "$DEPFILES" ]; then
  checked_anything=1
  flagged=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # a line declaring replicate as a dep but with no version constraint
    if grep -Eq '^[[:space:]"'"'"']*replicate[[:space:]"'"'"',]*$' "$f"; then
      warn "$(basename "$f") declares 'replicate' unpinned — pin 'replicate>=1,<2' (2.0 is alpha)"
      flagged=1
    fi
  done <<EOF
$DEPFILES
EOF
  [ "$flagged" -eq 0 ] && ok "replicate dependency is pinned or constrained"
fi

# --- 4. FileOutput written as a string ----------------------------------------
PYFILES="$(find "$DIR" -name '*.py' 2>/dev/null || true)"
if [ -n "$PYFILES" ]; then
  MISUSE="$(grep -rEn "open\([^)]*['\"]w['\"][^)]*\)\.write\([a-zA-Z_]" "$DIR" --include='*.py' 2>/dev/null \
    | grep -vE '\.read\(\)|\.url' || true)"
  if [ -n "$MISUSE" ]; then
    checked_anything=1
    while IFS= read -r m; do
      [ -n "$m" ] && warn "possible FileOutput-as-string: ${m} — use .read() for bytes or .url for the link"
    done <<EOF
$MISUSE
EOF
  fi
fi

# --- summary ------------------------------------------------------------------
printf '\n'
if [ "$checked_anything" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
  ok "nothing to check in $DIR"
  exit 0
fi
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
