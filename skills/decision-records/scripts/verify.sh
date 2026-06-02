#!/usr/bin/env bash
# verify.sh — lint Architecture Decision Records (ADRs).
# Read-only, no network. Usage: verify.sh <path-to-adr.md | decisions-dir>
# Checks per ADR: recognized status, a date, required sections, >=2 options,
# and a valid filename. Exits non-zero on the first failing ADR with a
# specific message. Exits 0 on a clean target and on an empty/absent dir.

set -u

STATUS_RE='[Ss]tatus[^A-Za-z]*(proposed|accepted|rejected|deprecated|superseded)'
DATE_RE='[0-9]{4}-[0-9]{2}-[0-9]{2}'

fail() { echo "FAIL: $1" >&2; exit 1; }

# Lint a single ADR file. Echoes nothing on success.
lint_adr() {
  local f="$1"
  local base; base="$(basename "$f")"

  # Filename: numeric-prefix NNNN-*.md, OR any *.md with a non-empty H1 title.
  if ! printf '%s' "$base" | grep -Eq '^[0-9]{4}-.+\.md$'; then
    if ! grep -Eq '^#[[:space:]]+[^[:space:]]' "$f"; then
      fail "$f: filename is not NNNN-title.md and the file has no non-empty '# Title' heading"
    fi
  fi

  grep -Eiq "$STATUS_RE" "$f" \
    || fail "$f: no recognized Status (expected one of proposed|accepted|rejected|deprecated|superseded)"

  grep -Eq "$DATE_RE" "$f" \
    || fail "$f: no date found (expected a YYYY-MM-DD date)"

  grep -Eiq '^#+[[:space:]]+Context' "$f" \
    || fail "$f: missing a 'Context' section"

  grep -Eiq '^#+[[:space:]]+(Considered )?Options' "$f" \
    || fail "$f: missing a 'Considered Options' section"

  grep -Eiq '^#+[[:space:]]+Decision( Outcome)?' "$f" \
    || fail "$f: missing a 'Decision' / 'Decision Outcome' section"

  grep -Eiq '^#+[[:space:]]+Consequences' "$f" \
    || fail "$f: missing a 'Consequences' section"

  # Count option bullets inside the Considered Options section.
  local opts
  opts="$(awk '
    /^#+[[:space:]]+(Considered )?Options/ { inopt=1; next }
    /^#+[[:space:]]/ { if (inopt) inopt=0 }
    inopt && /^[[:space:]]*[-*][[:space:]]+[^[:space:]]/ { n++ }
    END { print n+0 }
  ' "$f")"
  if [ "$opts" -lt 2 ]; then
    fail "$f: lists $opts option bullet(s) under Considered Options; need >=2 real options"
  fi
}

main() {
  if [ "$#" -lt 1 ]; then
    echo "usage: verify.sh <path-to-adr.md | decisions-dir>" >&2
    exit 2
  fi

  local target="$1"

  if [ -f "$target" ]; then
    lint_adr "$target"
    echo "OK: $target"
    exit 0
  fi

  if [ -d "$target" ]; then
    local count=0 index="" f base
    # Locate an index file, if any, for orphan warnings.
    for cand in "$target/README.md" "$target/0000-index.md" "$target/index.md"; do
      [ -f "$cand" ] && index="$cand" && break
    done

    while IFS= read -r f; do
      base="$(basename "$f")"
      # Skip the index itself.
      [ -n "$index" ] && [ "$f" = "$index" ] && continue
      case "$base" in README.md|index.md|0000-index.md) continue ;; esac
      count=$((count + 1))
      lint_adr "$f"
      # Orphan warning: numeric ADR id not referenced in the index.
      if [ -n "$index" ] && printf '%s' "$base" | grep -Eq '^[0-9]{4}-'; then
        local id="${base%%-*}"
        grep -Fq "$id" "$index" \
          || echo "WARN: $f (ADR $id) is not referenced in $index" >&2
      fi
    done < <(find "$target" -maxdepth 1 -type f -name '*.md' | sort)

    if [ "$count" -eq 0 ]; then
      echo "OK: no ADRs found under $target (nothing to check)"
    else
      echo "OK: $count ADR(s) under $target passed"
    fi
    exit 0
  fi

  fail "target not found: $target"
}

main "$@"
