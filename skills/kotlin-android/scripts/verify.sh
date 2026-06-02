#!/usr/bin/env bash
# verify.sh — static, SDK-free lint for native Android (Kotlin + Gradle).
#
# Greps the target dir for stale/banned Android patterns and missing modern ones.
# No Android SDK, no Gradle, no network required — runs in CI or a bare checkout.
#
#   bash scripts/verify.sh [DIR]   # DIR defaults to the current directory
#
# FAIL (exit 1): a banned pattern is present.
# WARN (exit 0): a modern pattern looks missing — review, don't necessarily block.
# An empty or clean target exits 0 with "all checks passed".
#
# Portable to stock macOS bash 3.2 (no mapfile, no associative arrays).
set -eu

DIR="${1:-.}"

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
RESET=$'\033[0m'

fails=0
warns=0
fail() { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$1"; fails=$((fails + 1)); }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$RESET" "$1"; warns=$((warns + 1)); }

if [ ! -d "$DIR" ]; then
  warn "target '$DIR' is not a directory — nothing to check"
  exit 0
fi

# Collect target files. Exclude build output and this skill's own references.
kt_files=$(find "$DIR" -type f -name '*.kt' \
  -not -path '*/build/*' -not -path '*/.gradle/*' 2>/dev/null || true)
gradle_files=$(find "$DIR" -type f -name '*.gradle.kts' \
  -not -path '*/build/*' 2>/dev/null || true)
xml_layouts=$(find "$DIR" -type f -path '*/res/layout/*.xml' \
  -not -path '*/build/*' 2>/dev/null || true)

if [ -z "$kt_files" ] && [ -z "$gradle_files" ] && [ -z "$xml_layouts" ]; then
  printf '%sno Kotlin/Gradle/layout files under %s — nothing to check.%s\n' "$GREEN" "$DIR" "$RESET"
  exit 0
fi

# grep helper: returns 0 (and prints) when PATTERN is found in $kt_files.
kt_grep() { [ -n "$kt_files" ] && printf '%s\n' "$kt_files" | xargs grep -nE "$1" 2>/dev/null; }
gradle_grep() { [ -n "$gradle_files" ] && printf '%s\n' "$gradle_files" | xargs grep -nE "$1" 2>/dev/null; }

# ---- FAIL checks: banned patterns -----------------------------------------
[ -n "$xml_layouts" ] && fail "XML layout files under res/layout — use Jetpack Compose:
$(printf '%s\n' "$xml_layouts" | sed 's/^/    /')"

hit=$(kt_grep '\bfindViewById\b') && [ -n "$hit" ] && \
  fail "findViewById (no Compose):"$'\n'"$(printf '%s' "$hit" | sed 's/^/    /')"

hit=$(kt_grep '\bAsyncTask\b') && [ -n "$hit" ] && \
  fail "AsyncTask (removed API) — use coroutines:"$'\n'"$(printf '%s' "$hit" | sed 's/^/    /')"

hit=$(kt_grep 'GlobalScope\.(launch|async)') && [ -n "$hit" ] && \
  fail "GlobalScope coroutine (leaks) — use viewModelScope/a scoped CoroutineScope:"$'\n'"$(printf '%s' "$hit" | sed 's/^/    /')"

hit=$(kt_grep 'import +androidx\.lifecycle\.LiveData') && [ -n "$hit" ] && \
  fail "LiveData import — use StateFlow + collectAsStateWithLifecycle():"$'\n'"$(printf '%s' "$hit" | sed 's/^/    /')"

hit=$(gradle_grep '\bkapt\b') && [ -n "$hit" ] && \
  fail "kapt in Gradle (legacy/slow) — use KSP for Room/Hilt:"$'\n'"$(printf '%s' "$hit" | sed 's/^/    /')"

# Public mutable state surface: a 'val' exposing MutableStateFlow/mutableStateOf
# without a 'private' modifier is a leaked source of truth.
hit=$(kt_grep '^[[:space:]]*(public[[:space:]]+)?val[[:space:]].*(MutableStateFlow|mutableStateOf)\(') \
  && [ -n "$hit" ] && \
  fail "public val exposing MutableStateFlow/mutableStateOf — keep mutable private, expose StateFlow via asStateFlow():"$'\n'"$(printf '%s' "$hit" | sed 's/^/    /')"

# ---- WARN checks: missing modern patterns ----------------------------------
# collectAsState( without the Lifecycle variant in the same set of files.
if [ -n "$kt_files" ]; then
  plain=$(printf '%s\n' "$kt_files" | xargs grep -lE 'collectAsState\(' 2>/dev/null || true)
  lifecycle=$(printf '%s\n' "$kt_files" | xargs grep -lE 'collectAsStateWithLifecycle\(' 2>/dev/null || true)
  # Files that use collectAsState but never the lifecycle variant.
  for f in $plain; do
    case " $lifecycle " in
      *" $f "*) : ;;
      *) warn "collectAsState() without collectAsStateWithLifecycle() in: $f" ;;
    esac
  done
fi

hit=$(gradle_grep 'composeOptions[[:space:]]*\{') && [ -n "$hit" ] && \
  warn "legacy composeOptions block — use the Kotlin Compose plugin (org.jetbrains.kotlin.plugin.compose):"$'\n'"$(printf '%s' "$hit" | sed 's/^/    /')"

if [ -n "$gradle_files" ]; then
  if ! printf '%s\n' "$gradle_files" | xargs grep -qE 'compose-bom|platform\(.*compose' 2>/dev/null; then
    warn "no compose-bom platform() pin found in Gradle — pin Compose artifacts via the BOM."
  fi
fi

# ---- summary ---------------------------------------------------------------
printf -- '----\n'
if [ "$fails" -gt 0 ]; then
  printf '%s%d failure(s)%s, %d warning(s).\n' "$RED" "$fails" "$RESET" "$warns"
  exit 1
fi
if [ "$warns" -gt 0 ]; then
  printf '%s%d warning(s)%s, no failures.%s\n' "$YELLOW" "$warns" "$RESET" "$RESET"
  exit 0
fi
printf '%sall checks passed.%s\n' "$GREEN" "$RESET"
exit 0
