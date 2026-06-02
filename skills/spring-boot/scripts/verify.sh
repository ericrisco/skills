#!/usr/bin/env bash
#
# verify.sh — static reviewer for legacy / wrong-generation Spring Boot idioms.
#
# Usage:
#   ./scripts/verify.sh [TARGET_PATH]     # defaults to "."
#
# Greps the project's Spring sources (*.java, application*.yml|yaml|properties) for idioms
# that are removed or discouraged on the Boot 4 / Framework 7 / Security 7 / Jakarta 11
# generation, and prints each hit with the modern replacement. Read-only: it never edits a
# file. On a clean tree — or a tree with no Spring sources at all — it prints nothing
# actionable and exits 0 (no false failure). It exits 1 only when at least one finding is
# present, so it can double as a non-blocking CI lint signal.
#
# Compatible with stock macOS bash 3.2: no mapfile, no associative arrays, no process
# substitution that trips `set -u`.

set -euo pipefail

TARGET="${1:-.}"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi

if [ ! -e "$TARGET" ]; then
  printf '%serror:%s target path %s does not exist.\n' "$RED" "$RESET" "$TARGET" >&2
  exit 2
fi

findings=0

# Run a grep over Java sources; print findings with a fix hint. Never fails the script by
# itself (grep's no-match exit 1 is swallowed); increments the global findings counter.
scan_java() {
  pattern="$1"; label="$2"; fix="$3"
  hits="$(grep -REn --include='*.java' -- "$pattern" "$TARGET" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    findings=1
    printf '%s[finding]%s %s -> %s\n' "$YELLOW" "$RESET" "$label" "$fix"
    printf '%s\n' "$hits" | sed 's/^/    /'
  fi
}

scan_config() {
  pattern="$1"; label="$2"; fix="$3"
  hits="$(grep -REn --include='application*.yml' --include='application*.yaml' \
            --include='application*.properties' -- "$pattern" "$TARGET" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    findings=1
    printf '%s[finding]%s %s -> %s\n' "$YELLOW" "$RESET" "$label" "$fix"
    printf '%s\n' "$hits" | sed 's/^/    /'
  fi
}

# --- removed / wrong-generation idioms ---
scan_java 'WebSecurityConfigurerAdapter'        'WebSecurityConfigurerAdapter (removed in Security 6/7)' 'a SecurityFilterChain bean + lambda DSL'
scan_java '@(MockBean|SpyBean)\b'               '@MockBean / @SpyBean (removed in Boot 4)'               '@MockitoBean / @MockitoSpyBean'
scan_java '\.(authorizeRequests|antMatchers|mvcMatchers)\s*\(' 'authorizeRequests / antMatchers / mvcMatchers (gone in Security 6/7)' 'authorizeHttpRequests + requestMatchers'
scan_java 'import[[:space:]]+javax\.persistence' 'javax.persistence import (Jakarta EE 11 baseline)'      'jakarta.persistence.*'
scan_java 'import[[:space:]]+javax\.validation'  'javax.validation import (Jakarta EE 11 baseline)'       'jakarta.validation.*'

# --- discouraged patterns (heuristic) ---
# Field @Autowired: an @Autowired line whose payload is not a method/constructor (no '(').
field_autowired="$(grep -REn --include='*.java' -- '@Autowired' "$TARGET" 2>/dev/null \
  | grep -Ev '\(' || true)"
if [ -n "$field_autowired" ]; then
  findings=1
  printf '%s[finding]%s field/setter @Autowired (heuristic) -> %s\n' "$YELLOW" "$RESET" 'constructor injection, final fields'
  printf '%s\n' "$field_autowired" | sed 's/^/    /'
fi

# @Transactional inside a @RestController source file (tx belongs on the service).
tx_in_controller=""
ctrl_files="$(grep -REl --include='*.java' -- '@RestController' "$TARGET" 2>/dev/null || true)"
if [ -n "$ctrl_files" ]; then
  # bash 3.2-safe iteration over newline-separated file list
  OLDIFS="$IFS"; IFS='
'
  for f in $ctrl_files; do
    hit="$(grep -En -- '@Transactional' "$f" 2>/dev/null || true)"
    if [ -n "$hit" ]; then
      tx_in_controller="${tx_in_controller}${f}:\n${hit}\n"
    fi
  done
  IFS="$OLDIFS"
fi
if [ -n "$tx_in_controller" ]; then
  findings=1
  printf '%s[finding]%s @Transactional in a @RestController file -> %s\n' "$YELLOW" "$RESET" 'move @Transactional to the service method'
  printf '%b' "$tx_in_controller" | sed 's/^/    /'
fi

# csrf().disable() with no rationale comment on the same line.
csrf_hits="$(grep -REn --include='*.java' -- 'csrf\s*\(\s*\)\s*\.\s*disable|csrf\(.*disable' "$TARGET" 2>/dev/null || true)"
if [ -n "$csrf_hits" ]; then
  csrf_unexplained="$(printf '%s\n' "$csrf_hits" | grep -Ev '//' || true)"
  if [ -n "$csrf_unexplained" ]; then
    findings=1
    printf '%s[finding]%s csrf().disable() with no rationale comment -> %s\n' "$YELLOW" "$RESET" 'disable only for stateless token APIs; add a // comment saying why'
    printf '%s\n' "$csrf_unexplained" | sed 's/^/    /'
  fi
fi

scan_config 'ddl-auto:[[:space:]]*(update|create-drop)' 'hibernate ddl-auto=update/create-drop in config' 'use validate + Flyway/Liquibase migrations'

if [ "$findings" -eq 0 ]; then
  printf '%s[ ok ]%s no legacy Spring idioms found in %s\n' "$GREEN" "$RESET" "$TARGET"
  exit 0
fi

printf '%s[note]%s findings above are advisory; review and migrate to the Boot 4 idioms.\n' "$RED" "$RESET"
exit 1
