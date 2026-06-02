#!/usr/bin/env bash
#
# verify.sh - local quality gate for a Java project (compile + test).
#
# Usage:
#   cd <your-project-root>   # the directory containing pom.xml or build.gradle(.kts)
#   ./verify.sh
#
# Detects Maven vs Gradle, prefers the project wrapper (./mvnw / ./gradlew), and runs the
# build's compile + test + verify (`mvn -q verify` or `gradle check`).
# Missing build tools are skipped with a yellow warning (not a failure); a real
# compile/test failure exits non-zero. Read-only: never mutates your source.
#
# Portability: runs on stock macOS bash 3.2 (no mapfile, no associative arrays,
# no unguarded array expansions under `set -u`).

set -euo pipefail

# Colors only when stdout is a TTY (keeps logs/CI output clean).
if [ -t 1 ]; then
  YELLOW=$'\033[33m'; RED=$'\033[31m'; GREEN=$'\033[32m'; RESET=$'\033[0m'
else
  YELLOW=''; RED=''; GREEN=''; RESET=''
fi

failed=0

have()  { command -v "$1" >/dev/null 2>&1; }
warn()  { printf '%s[skip]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail()  { printf '%s[fail]%s %s\n' "$RED" "$RESET" "$*"; failed=1; }
ok()    { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
info()  { printf -- '----- %s\n' "$*"; }

# Detect the build system. Neither present is a usage error, not a check failure.
build="none"
if [ -f pom.xml ]; then
  build="maven"
elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  build="gradle"
fi

if [ "$build" = "none" ]; then
  printf '%serror:%s no pom.xml or build.gradle(.kts) in %s - cd into your project root first.\n' \
    "$RED" "$RESET" "$(pwd)" >&2
  exit 2
fi

# Optional JDK version hint: warn (do not fail) if the major version is below 21.
info "java -version"
if have java; then
  # `java -version` writes to stderr; first line e.g. 'openjdk version "25.0.1" ...'
  ver_line="$(java -version 2>&1 | head -n1 || true)"
  major="$(printf '%s' "$ver_line" | sed -n 's/.*version "\([0-9]*\).*/\1/p')"
  if [ -n "$major" ] && [ "$major" -lt 21 ] 2>/dev/null; then
    warn "JDK major $major detected; this skill targets 21+ (Java 25 LTS). $ver_line"
  else
    ok "$ver_line"
  fi
else
  warn "java not found on PATH (is a JDK installed?)"
fi

case "$build" in
  maven)
    info "Maven verify (compile + test + verify)"
    mvn_cmd=""
    if [ -x ./mvnw ]; then
      mvn_cmd="./mvnw"
    elif have mvn; then
      mvn_cmd="mvn"
    fi
    if [ -z "$mvn_cmd" ]; then
      warn "no ./mvnw and no mvn on PATH; cannot build (https://maven.apache.org)"
    else
      if "$mvn_cmd" -q -DskipTests=false verify; then
        ok "maven verify passed ($mvn_cmd)"
      else
        fail "maven verify failed ($mvn_cmd)"
      fi
    fi
    ;;
  gradle)
    info "Gradle check (compile + test)"
    gradle_cmd=""
    if [ -x ./gradlew ]; then
      gradle_cmd="./gradlew"
    elif have gradle; then
      gradle_cmd="gradle"
    fi
    if [ -z "$gradle_cmd" ]; then
      warn "no ./gradlew and no gradle on PATH; cannot build (https://gradle.org/install/)"
    else
      if "$gradle_cmd" check; then
        ok "gradle check passed ($gradle_cmd)"
      else
        fail "gradle check failed ($gradle_cmd)"
      fi
    fi
    ;;
esac

echo
if [ "$failed" -ne 0 ]; then
  printf '%sFAIL:%s one or more checks failed.\n' "$RED" "$RESET"
  exit 1
fi
printf '%sPASS:%s all checks passed.\n' "$GREEN" "$RESET"
