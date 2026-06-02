#!/usr/bin/env bash
# verify.sh — advisory copy/practice banlist for Swift / SwiftUI files.
#
# Pure text checks: no Xcode, no network, no toolchain. Greps emitted .swift
# (and Package.swift) for stale or footgun patterns and prints file:line on hits.
#
# Read-only. Exits 0 when the target is empty/clean (no false failure), 1 on a hit.
# Greenfield-oriented and ADVISORY: legacy codebases may legitimately match —
# review hits, do not treat them as hard errors when working in existing code.
#
# Usage:
#   scripts/verify.sh [PATH ...]
# Defaults to scanning the current directory if no path is given.

set -euo pipefail

# --- collect targets -------------------------------------------------------
targets=("$@")
if [ "${#targets[@]}" -eq 0 ]; then
  targets=(".")
fi

tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT
for t in "${targets[@]}"; do
  if [ -d "$t" ]; then
    find "$t" -type f -name '*.swift' 2>/dev/null >> "$tmp_list"
  elif [ -f "$t" ] && [ "${t%.swift}" != "$t" ]; then
    printf '%s\n' "$t" >> "$tmp_list"
  fi
done

files=()
while IFS= read -r f; do
  [ -n "$f" ] && files+=("$f")
done < <(sort -u "$tmp_list")

# Empty/clean target -> succeed quietly. No false failure.
if [ "${#files[@]}" -eq 0 ]; then
  echo "verify.sh: no .swift files to scan — clean."
  exit 0
fi

hits=0

# report PATTERN MESSAGE  (egrep across files, prints file:line)
report() {
  local pattern="$1" message="$2"
  local out
  out="$(grep -REnH "$pattern" "${files[@]}" 2>/dev/null || true)"
  if [ -n "$out" ]; then
    echo "FAIL: $message"
    printf '%s\n' "$out" | sed 's/^/  /'
    hits=$((hits + 1))
  fi
}

# --- global banlist --------------------------------------------------------
report ': *ObservableObject\b' "ObservableObject in new code — use @Observable (Observation)."
report '@Published\b'          "@Published in new code — @Observable tracks properties automatically."
report 'NavigationView\s*[({]'  "NavigationView is deprecated — use NavigationStack + navigationDestination."
report '@nonisolated\(unsafe\)' "@nonisolated(unsafe) silences isolation instead of fixing it — make the type Sendable or main-isolated."

# --- per-file contextual checks -------------------------------------------
for f in "${files[@]}"; do
  # DispatchQueue.main.async inside a file that declares an @Observable model
  if grep -q '@Observable' "$f" && grep -nE 'DispatchQueue\.main\.async' "$f" >/dev/null 2>&1; then
    echo "FAIL: DispatchQueue.main.async inside an @Observable model — annotate the model @MainActor: $f"
    grep -nE 'DispatchQueue\.main\.async' "$f" | sed 's/^/  /'
    hits=$((hits + 1))
  fi

  # XCTAssert* in a file that also uses Swift Testing (@Test)
  if grep -q '@Test' "$f" && grep -nE 'XCTAssert' "$f" >/dev/null 2>&1; then
    echo "FAIL: XCTAssert in a Swift Testing file — use #expect / #require: $f"
    grep -nE 'XCTAssert' "$f" | sed 's/^/  /'
    hits=$((hits + 1))
  fi

  # Task.detached without an adjacent justification comment (warn)
  if grep -nE 'Task\.detached\s*[({]' "$f" >/dev/null 2>&1; then
    while IFS=: read -r ln _; do
      prev=$((ln - 1))
      if [ "$prev" -ge 1 ] && sed -n "${prev}p" "$f" | grep -qE '//.*(justif|reason|why|intentional|detach)'; then
        continue
      fi
      echo "WARN: Task.detached without a justification comment (rarely correct — Task {} inherits actor + priority): $f:$ln"
    done < <(grep -nE 'Task\.detached\s*[({]' "$f")
  fi
done

if [ "$hits" -gt 0 ]; then
  echo "verify.sh: $hits banlist hit(s). Advisory — review before treating as failures."
  exit 1
fi

echo "verify.sh: clean."
exit 0
