#!/usr/bin/env bash
set -euo pipefail

# verify.sh — agent-eval skill gate. Run from your PROJECT root.
#
# What it does (read-only, idempotent, NEVER calls an LLM or network):
#   1. Discovers *.jsonl golden sets (skips vendor dirs); checks every line parses
#      and carries the required keys id, input, expected. Hard fail on a bad line.
#   2. If an eval-report.json exists, validates its shape (a "passed" boolean and a
#      "metrics" object). Hard fail only on malformed JSON / missing shape.
#   3. Optional lint, advisory only: ruff + mypy on example Python, markdownlint on docs.
#
# Exit non-zero ONLY on a malformed JSONL line, a missing required key, or a malformed
# eval-report.json. Every optional lint and every missing tool is a yellow WARN/skip.
# An empty or clean target exits 0. Stock macOS bash 3.2 (no mapfile / associative arrays).

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
EXIT=0
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
note() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; EXIT=1; }

ROOT="$(pwd)"

# Need a JSON-aware tool for the structural checks. Prefer python3, fall back to jq.
JSON_TOOL=""
if command -v python3 >/dev/null 2>&1; then JSON_TOOL="python3"
elif command -v jq >/dev/null 2>&1; then JSON_TOOL="jq"; fi

# --- 1. golden-set JSONL validation -----------------------------------------
JSONL_FILES=()
while IFS= read -r -d '' f; do
  JSONL_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' \
       -o -path '*/.venv/*' -o -path '*/dist/*' \) -prune -o \
    -type f -name '*.jsonl' -print0 2>/dev/null
)

if [ "${#JSONL_FILES[@]}" -eq 0 ]; then
  skip "no *.jsonl golden sets found under $ROOT — nothing to validate"
elif [ -z "$JSON_TOOL" ]; then
  skip "neither python3 nor jq found — cannot validate JSONL, skipping"
else
  for f in "${JSONL_FILES[@]}"; do
    if [ "$JSON_TOOL" = "python3" ]; then
      msg="$(python3 - "$f" <<'PY'
import json, sys
path = sys.argv[1]
req = {"id", "input", "expected"}
bad = []
with open(path, encoding="utf-8") as fh:
    for n, line in enumerate(fh, 1):
        s = line.strip()
        if not s:
            continue
        try:
            obj = json.loads(s)
        except ValueError as e:
            bad.append(f"line {n}: invalid JSON ({e})"); continue
        if not isinstance(obj, dict):
            bad.append(f"line {n}: not a JSON object"); continue
        missing = req - obj.keys()
        if missing:
            bad.append(f"line {n}: missing keys {sorted(missing)}")
print("\n".join(bad), end="")
PY
)" || msg="parser crashed on $f"
      if [ -n "$msg" ]; then
        err "$f:"; printf '  %s\n' "$msg"
      else
        ok "$f valid (id/input/expected present on every line)"
      fi
    else
      # jq path: each line must be an object with the three keys.
      if jq -e 'has("id") and has("input") and has("expected")' "$f" >/dev/null 2>&1; then
        ok "$f valid (jq: required keys present)"
      else
        err "$f: a line is not an object or is missing id/input/expected (jq)"
      fi
    fi
  done
fi

# --- 2. eval-report.json shape ------------------------------------------------
REPORTS=()
while IFS= read -r -d '' f; do
  REPORTS+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/.venv/*' \) -prune -o \
    -type f -name 'eval-report.json' -print0 2>/dev/null
)

if [ "${#REPORTS[@]}" -eq 0 ]; then
  skip "no eval-report.json found — gate output not validated"
elif [ -z "$JSON_TOOL" ]; then
  skip "no python3/jq — cannot validate eval-report.json shape"
else
  for f in "${REPORTS[@]}"; do
    if [ "$JSON_TOOL" = "python3" ]; then
      if python3 - "$f" <<'PY'
import json, sys
try:
    r = json.load(open(sys.argv[1], encoding="utf-8"))
except ValueError as e:
    print(e); sys.exit(1)
ok = isinstance(r, dict) and isinstance(r.get("passed"), bool) \
     and isinstance(r.get("metrics"), dict)
sys.exit(0 if ok else 1)
PY
      then ok "$f shape ok (passed: bool, metrics: object)"
      else err "$f: malformed or missing 'passed'(bool)/'metrics'(object)"; fi
    else
      if jq -e 'type=="object" and (.passed|type=="boolean") and (.metrics|type=="object")' "$f" >/dev/null 2>&1; then
        ok "$f shape ok (jq)"
      else err "$f: malformed or missing passed/metrics (jq)"; fi
    fi
  done
fi

# --- 3. optional lint (advisory only) ----------------------------------------
PY_FILES=()
while IFS= read -r -d '' f; do
  PY_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/.venv/*' \) -prune -o \
    -type f -name '*.py' -print0 2>/dev/null
)

if [ "${#PY_FILES[@]}" -gt 0 ]; then
  if command -v ruff >/dev/null 2>&1; then
    if ruff check "${PY_FILES[@]}" >/dev/null 2>&1; then ok "ruff clean"; else note "ruff reported lint findings (advisory)"; fi
  else skip "ruff not installed — skipping Python lint"; fi
  if command -v mypy >/dev/null 2>&1; then
    mypy "${PY_FILES[@]}" >/dev/null 2>&1 && ok "mypy clean" || note "mypy reported type findings (advisory)"
  else skip "mypy not installed — skipping type check"; fi
else
  skip "no *.py files — skipping ruff/mypy"
fi

MD_FILES=()
while IFS= read -r -d '' f; do
  MD_FILES+=("$f")
done < <(
  find "$ROOT" \
    \( -path '*/node_modules/*' -o -path '*/.git/*' \) -prune -o \
    -type f -name '*.md' -print0 2>/dev/null
)
if [ "${#MD_FILES[@]}" -gt 0 ] && command -v markdownlint >/dev/null 2>&1; then
  markdownlint "${MD_FILES[@]}" >/dev/null 2>&1 && ok "markdownlint clean" || note "markdownlint findings (advisory)"
else
  skip "markdownlint not installed or no docs — skipping doc lint"
fi

printf '\n'
if [ "$EXIT" -eq 0 ]; then ok "verify.sh passed"; else err "verify.sh found failures"; fi
exit "$EXIT"
