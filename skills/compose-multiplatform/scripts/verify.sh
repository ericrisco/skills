#!/usr/bin/env bash
# verify.sh — static, read-only checks for a Compose Multiplatform / KMP project.
# No Gradle/Xcode run required. Exits 0 on a clean OR empty target (no false failure).
#
# Usage: verify.sh [PROJECT_DIR]   (default: current directory)
#
# Hard failures (exit 1): missing commonMain when KMP is present, orphaned `expect`
# (no matching `actual`), platform import leaking into commonMain.
# Warnings (still exit 0): Kotlin < 2.1.0, missing Compose plugin.

set -uo pipefail

ROOT="${1:-.}"
FAIL=0
WARN=0

note()  { printf '  %s\n' "$1"; }
ok()    { printf 'PASS  %s\n' "$1"; }
bad()   { printf 'FAIL  %s\n' "$1"; FAIL=1; }
warn()  { printf 'WARN  %s\n' "$1"; WARN=1; }

if [ ! -d "$ROOT" ]; then
  echo "verify.sh: '$ROOT' is not a directory" >&2
  exit 2
fi

# Locate commonMain source dirs (KMP marker). Ignore build output dirs.
# Portable to bash 3.2 (macOS) — no mapfile.
COMMON_DIRS=()
while IFS= read -r d; do
  [ -n "$d" ] && COMMON_DIRS+=("$d")
done < <(find "$ROOT" -type d -name commonMain \
  -not -path '*/build/*' -not -path '*/.gradle/*' 2>/dev/null)

# Detect whether this looks like a KMP/CMP project at all.
HAS_KMP=0
if [ "${#COMMON_DIRS[@]}" -gt 0 ]; then HAS_KMP=1; fi
if grep -rqsl 'org.jetbrains.kotlin.multiplatform\|org.jetbrains.compose' \
     "$ROOT" --include='*.kts' --include='*.toml' 2>/dev/null; then HAS_KMP=1; fi

if [ "$HAS_KMP" -eq 0 ]; then
  echo "verify.sh: no KMP/CMP project detected under '$ROOT' — nothing to check."
  exit 0
fi

# 1) commonMain must exist.
if [ "${#COMMON_DIRS[@]}" -eq 0 ]; then
  bad "no commonMain source set found (a shared module is the core of CMP)"
else
  ok "commonMain present (${#COMMON_DIRS[@]} found)"
fi

# 2) Every `expect` in commonMain needs a matching `actual` somewhere.
#    Match on the declared symbol name to catch orphans cheaply.
ORPHANS=0
for cm in ${COMMON_DIRS[@]+"${COMMON_DIRS[@]}"}; do
  # collect expect declarations: fun/class/val/var/object/interface
  while IFS= read -r decl; do
    [ -z "$decl" ] && continue
    name="$decl"
    if grep -rqs "actual[[:space:]].*\b${name}\b" "$ROOT" \
         --include='*.kt' 2>/dev/null \
         | grep -qv "commonMain" 2>/dev/null; then
      :
    elif grep -rs "actual[[:space:]]" "$ROOT" --include='*.kt' 2>/dev/null \
           | grep -q "\b${name}\b"; then
      :
    else
      bad "orphaned expect '${name}' has no matching actual in any platform source set"
      ORPHANS=$((ORPHANS+1))
    fi
  done < <(grep -rhsoE '^[[:space:]]*expect[[:space:]]+(fun|class|val|var|object|interface)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
             "$cm" --include='*.kt' 2>/dev/null \
             | sed -E 's/.*(fun|class|val|var|object|interface)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/')
done
[ "$ORPHANS" -eq 0 ] && ok "no orphaned expect declarations"

# 3) Compose plugin + Kotlin version.
if grep -rqs 'org.jetbrains.compose' "$ROOT" \
     --include='*.kts' --include='*.toml' 2>/dev/null; then
  ok "Compose Multiplatform plugin (org.jetbrains.compose) present"
else
  warn "Compose Multiplatform plugin (org.jetbrains.compose) not found"
fi

KVER=$(grep -rhsoE 'kotlin[^=]*=[[:space:]]*"?([0-9]+\.[0-9]+\.[0-9]+)' \
         "$ROOT" --include='*.toml' --include='*.kts' 2>/dev/null \
         | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1)
if [ -n "$KVER" ]; then
  MAJ=${KVER%%.*}; REST=${KVER#*.}; MIN=${REST%%.*}
  if [ "$MAJ" -gt 2 ] || { [ "$MAJ" -eq 2 ] && [ "$MIN" -ge 1 ]; }; then
    ok "Kotlin $KVER (>= 2.1.0 K2 floor)"
  else
    warn "Kotlin $KVER is below 2.1.0 — CMP 1.8+ requires K2 (Kotlin 2.1.0+); bump to 2.2.x"
  fi
else
  warn "could not detect a Kotlin version in version catalog / build scripts"
fi

# 4) No platform-only imports leaking into commonMain.
FORBIDDEN='^import[[:space:]]+(android\.|androidx\.activity|platform\.UIKit|platform\.Foundation|java\.awt|javax\.swing|org\.w3c\.dom)'
LEAKS=0
for cm in ${COMMON_DIRS[@]+"${COMMON_DIRS[@]}"}; do
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    bad "platform import in commonMain: $line"
    LEAKS=$((LEAKS+1))
  done < <(grep -rhsnE "$FORBIDDEN" "$cm" --include='*.kt' 2>/dev/null)
done
[ "$LEAKS" -eq 0 ] && ok "commonMain free of platform-only imports"

echo "----"
if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
if [ "$WARN" -ne 0 ]; then
  echo "RESULT: PASS (with warnings)"
else
  echo "RESULT: PASS"
fi
echo "(Optional: if ./gradlew exists, ':shared:compileKotlinMetadata' compiles the common metadata.)"
exit 0
