#!/usr/bin/env bash
# verify.sh — static, read-only checks for an llm-pipeline artifact (gateway/router
# config or typed-chain code). No live API calls. Offline and deterministic.
#
# Usage: verify.sh [PATH]   (PATH = file or dir; defaults to current directory)
# Exits 0 when every applicable check passes (including an empty/clean target),
# non-zero when any check FAILs. Checks that do not apply to the artifacts present
# are SKIPped, never failed.

set -u

TARGET="${1:-.}"

if [[ ! -e "$TARGET" ]]; then
  echo "verify.sh: path not found: $TARGET" >&2
  exit 2
fi

fail_count=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; fail_count=$((fail_count + 1)); }
skip() { printf 'SKIP  %s\n' "$1"; }

# Collect candidate source and config files (read-only). Portable to bash 3.2
# (macOS default) — no mapfile, newline-delimited via a temp array build.
CODE_FILES=(); YAML_FILES=(); JSON_FILES=()
while IFS= read -r f; do [[ -n "$f" ]] && CODE_FILES+=("$f"); done < <(find "$TARGET" -type f \( -name '*.py' -o -name '*.ts' -o -name '*.js' \) 2>/dev/null)
while IFS= read -r f; do [[ -n "$f" ]] && YAML_FILES+=("$f"); done < <(find "$TARGET" -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null)
while IFS= read -r f; do [[ -n "$f" ]] && JSON_FILES+=("$f"); done < <(find "$TARGET" -type f -name '*.json' 2>/dev/null)
ALL_FILES=("${CODE_FILES[@]+"${CODE_FILES[@]}"}" "${YAML_FILES[@]+"${YAML_FILES[@]}"}" "${JSON_FILES[@]+"${JSON_FILES[@]}"}")

if [[ ${#ALL_FILES[@]} -eq 0 ]]; then
  echo "verify.sh: no .py/.ts/.js/.yaml/.yml/.json files under $TARGET — nothing to check."
  exit 0
fi

# grep helper across a file list; prints "file:line:match" lines, empty if none.
grep_files() { # $1 = pattern, rest = files
  local pat="$1"; shift
  [[ $# -eq 0 ]] && return 0
  grep -HInE "$pat" "$@" 2>/dev/null   # -H so the filename prefix is always present
}

# --- Check 1: no hardcoded provider keys (always applicable) ---------------
KEY_HITS="$(grep_files '(sk-[A-Za-z0-9_-]{16,}|sk-ant-[A-Za-z0-9_-]{16,})' "${ALL_FILES[@]}")"
if [[ -n "$KEY_HITS" ]]; then
  fail "no hardcoded API keys (found literal key(s); use env vars)"
  echo "$KEY_HITS" | sed 's/^/      /'
else
  pass "no hardcoded API keys"
fi

# --- Check 2: every completion/chat call site sets a timeout ---------------
# A "call site" line invokes completion(/chat.completions.create/responses.create.
CALL_PAT='(\.completion\(|chat\.completions\.create\(|responses\.(create|parse)\()'
CALL_HITS="$(grep_files "$CALL_PAT" "${CODE_FILES[@]+"${CODE_FILES[@]}"}")"
if [[ -z "$CALL_HITS" ]]; then
  skip "timeout on every call (no LLM call sites found)"
else
  # A call line is OK if it (or a nearby Router/client default) sets timeout.
  # Heuristic, read-only: flag call lines on which 'timeout' does not appear AND
  # whose file has no router/client-level timeout default.
  unbounded=""
  while IFS= read -r line; do
    file="${line%%:*}"
    if echo "$line" | grep -qE 'timeout'; then continue; fi
    # allow a router/client default timeout in the same file
    if grep -qE 'timeout[[:space:]]*[:=]' "$file" 2>/dev/null; then continue; fi
    unbounded+="$line"$'\n'
  done <<< "$CALL_HITS"
  if [[ -n "${unbounded//[$'\n']/}" ]]; then
    fail "timeout on every call (call site(s) with no timeout)"
    printf '%s' "$unbounded" | sed '/^$/d;s/^/      /'
  else
    pass "timeout on every call"
  fi
fi

# --- Check 3: retries are bounded (no while True retry loops) --------------
LOOP_HITS="$(grep_files 'while[[:space:]]+True' "${CODE_FILES[@]+"${CODE_FILES[@]}"}")"
# only treat as a retry loop if a retry/except keyword is nearby in the file
retry_loops=""
if [[ -n "$LOOP_HITS" ]]; then
  while IFS= read -r line; do
    file="${line%%:*}"
    if grep -qiE '(retry|num_retries|except|completion\(|create\()' "$file" 2>/dev/null; then
      retry_loops+="$line"$'\n'
    fi
  done <<< "$LOOP_HITS"
fi
if [[ -n "${retry_loops//[$'\n']/}" ]]; then
  fail "retries bounded (unbounded 'while True' retry loop)"
  printf '%s' "$retry_loops" | sed '/^$/d;s/^/      /'
else
  pass "retries bounded"
fi

# --- Check 4: a fallback is configured when a router/model_list exists -----
HAS_ROUTER="$(grep_files '(Router\(|model_list|model_name)' "${ALL_FILES[@]}")"
if [[ -z "$HAS_ROUTER" ]]; then
  skip "fallback configured (no router/model_list present)"
else
  HAS_FALLBACK="$(grep_files '(fallbacks|content_policy_fallbacks|context_window_fallbacks|default_fallbacks)' "${ALL_FILES[@]}")"
  if [[ -n "$HAS_FALLBACK" ]]; then
    pass "fallback configured"
  else
    fail "fallback configured (router/model_list present but no fallback list)"
  fi
fi

# --- Check 5: config files parse and list >=2 model entries ----------------
check_config_models() { # $1 = file
  local f="$1" count=""
  case "$f" in
    *.json)
      if command -v python3 >/dev/null 2>&1; then
        count="$(python3 - "$f" <<'PY' 2>/dev/null
import json,sys,re
d=open(sys.argv[1]).read()
try: obj=json.loads(d)
except Exception: print("PARSEFAIL"); sys.exit(0)
s=json.dumps(obj)
print(len(re.findall(r'"model_name"|"model"\s*:', s)))
PY
)"
      fi ;;
    *.yaml|*.yml)
      if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
        count="$(python3 - "$f" <<'PY' 2>/dev/null
import yaml,sys,re
try: obj=yaml.safe_load(open(sys.argv[1]).read())
except Exception: print("PARSEFAIL"); sys.exit(0)
print(len(re.findall(r'model_name|(^|\s)model\s*:', str(obj))))
PY
)"
      else
        # no yaml lib: fall back to counting model_name occurrences textually
        count="$(grep -cE 'model_name' "$f" 2>/dev/null || echo 0)"
      fi ;;
  esac
  echo "${count:-}"
}

CONFIG_FILES=("${YAML_FILES[@]+"${YAML_FILES[@]}"}" "${JSON_FILES[@]+"${JSON_FILES[@]}"}")
relevant_config=0
for f in "${CONFIG_FILES[@]+"${CONFIG_FILES[@]}"}"; do
  [[ -z "$f" ]] && continue
  if grep -qE '(model_list|model_name|litellm|router_settings)' "$f" 2>/dev/null; then
    relevant_config=1
    res="$(check_config_models "$f")"
    if [[ "$res" == "PARSEFAIL" ]]; then
      fail "config parses ($f does not parse)"
    elif [[ "$res" =~ ^[0-9]+$ ]] && [[ "$res" -ge 2 ]]; then
      pass "config parses with >=2 model entries ($f)"
    else
      fail "config has >=2 model entries ($f has ${res:-0}; need a fallback target)"
    fi
  fi
done
[[ $relevant_config -eq 0 ]] && skip "config parses with >=2 models (no router config file present)"

echo "---"
if [[ $fail_count -eq 0 ]]; then
  echo "verify.sh: all applicable checks passed."
  exit 0
else
  echo "verify.sh: $fail_count check(s) FAILED."
  exit 1
fi
