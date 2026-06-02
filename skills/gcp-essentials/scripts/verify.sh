#!/usr/bin/env bash
# verify.sh — offline static linter for GCP gcloud command blocks.
#
# Flags known-unsafe patterns in files that contain `gcloud` commands:
#   - service-account JSON key creation
#   - roles/owner or roles/editor bound to a serviceAccount member
#   - bucket create missing --uniform-bucket-level-access or --public-access-prevention
#   - Cloud SQL create using public IP (--assign-ip / no --no-assign-ip)
#   - Cloud Run deploy/replace missing --service-account
#
# No network, no gcloud, read-only. Prints PASS/FAIL per check.
# Exit 0 when the target is empty/clean, nonzero when any FAIL is found.
#
# Usage:
#   bash verify.sh <file-or-dir> [<file-or-dir> ...]
#   bash verify.sh                # defaults to the skill dir (SKILL.md + references/)

set -uo pipefail

# ---- collect target files -------------------------------------------------
declare -a TARGETS=()
if [[ $# -eq 0 ]]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  TARGETS=("$here")
else
  TARGETS=("$@")
fi

declare -a FILES=()
for t in "${TARGETS[@]}"; do
  if [[ -d "$t" ]]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(
      find "$t" -type f \( -name '*.sh' -o -name '*.md' -o -name '*.bash' -o -name '*.txt' \) 2>/dev/null
    )
  elif [[ -f "$t" ]]; then
    FILES+=("$t")
  else
    echo "WARN  no such file or directory: $t" >&2
  fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "PASS  no target files to lint (clean)"
  exit 0
fi

fails=0

# report FAIL <check> <file> <lineno> <line>
report() {
  printf 'FAIL  %-22s %s:%s: %s\n' "$1" "$2" "$3" "$4"
  fails=$((fails + 1))
}

for f in "${FILES[@]}"; do
  lineno=0
  # Track context for multi-line `gcloud` commands joined by trailing backslash.
  buf=""
  buf_start=0
  flush_buf() {
    [[ -z "$buf" ]] && return
    local cmd="$buf"
    # --- Cloud Run deploy/replace must carry --service-account ---
    if echo "$cmd" | grep -Eq 'gcloud[[:space:]]+run[[:space:]]+(deploy|services[[:space:]]+replace)'; then
      if ! echo "$cmd" | grep -q -- '--service-account'; then
        report "run-no-service-account" "$f" "$buf_start" "gcloud run deploy/replace without --service-account"
      fi
    fi
    # --- bucket create must carry UBLA and PAP ---
    if echo "$cmd" | grep -Eq 'gcloud[[:space:]]+storage[[:space:]]+buckets[[:space:]]+create'; then
      if ! echo "$cmd" | grep -q -- '--uniform-bucket-level-access'; then
        report "bucket-no-ubla" "$f" "$buf_start" "bucket create missing --uniform-bucket-level-access"
      fi
      if ! echo "$cmd" | grep -q -- '--public-access-prevention'; then
        report "bucket-no-pap" "$f" "$buf_start" "bucket create missing --public-access-prevention"
      fi
    fi
    # --- Cloud SQL create must not use public IP ---
    if echo "$cmd" | grep -Eq 'gcloud[[:space:]]+sql[[:space:]]+instances[[:space:]]+create'; then
      if echo "$cmd" | grep -Eq -- '--assign-ip([^a-z]|$)'; then
        report "sql-public-ip" "$f" "$buf_start" "Cloud SQL create uses --assign-ip (public IP)"
      elif ! echo "$cmd" | grep -q -- '--no-assign-ip'; then
        report "sql-no-private" "$f" "$buf_start" "Cloud SQL create missing --no-assign-ip (defaults to public IP)"
      fi
    fi
    buf=""
  }

  # For Markdown files, only lint inside fenced code blocks (```bash / ```sh /
  # ```). Prose and anti-pattern table cells (which quote unsafe commands on
  # purpose) must not trip the linter. Non-.md files are treated as all-code.
  in_code=true
  is_md=false
  case "$f" in
    *.md) is_md=true; in_code=false ;;
  esac

  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))

    # Toggle fenced-code state for Markdown.
    if $is_md && [[ "$line" =~ ^[[:space:]]*\`\`\` ]]; then
      if $in_code; then in_code=false; else in_code=true; fi
      flush_buf
      continue
    fi
    if ! $in_code; then
      continue
    fi

    # Skip prose/comment-only lines for keyword checks but still scan for the
    # hard banned single-line patterns below.
    stripped="${line#"${line%%[![:space:]]*}"}"   # ltrim
    is_comment=false
    [[ "$stripped" == \#* ]] && is_comment=true

    # ---- single-line hard bans (checked on every non-comment line) ----
    if ! $is_comment; then
      # JSON key creation — never.
      if echo "$line" | grep -Eq 'gcloud[[:space:]]+iam[[:space:]]+service-accounts[[:space:]]+keys[[:space:]]+create'; then
        report "sa-json-key-create" "$f" "$lineno" "$stripped"
      fi
      # primitive owner/editor bound to a service account.
      if echo "$line" | grep -Eq -- '--role=("?)roles/(owner|editor)\b' \
         && echo "$line" | grep -q 'serviceAccount:'; then
        report "primitive-role-on-sa" "$f" "$lineno" "$stripped"
      fi
      # primitive owner/editor in a member+role grant spanning the same command
      # (covers the common case where role is on the same line).
    fi

    # ---- accumulate multi-line gcloud commands (backslash continuation) ----
    if $is_comment; then
      flush_buf
      continue
    fi
    if [[ -n "$buf" ]]; then
      buf="$buf $stripped"
    elif echo "$stripped" | grep -Eq '^gcloud([[:space:]]|$)'; then
      buf="$stripped"
      buf_start=$lineno
    fi
    # End of a command when the line does not end in a backslash.
    if [[ -n "$buf" && "${line%\\}" == "$line" ]]; then
      flush_buf
    fi
  done < "$f"
  flush_buf
done

echo "----"
if [[ $fails -eq 0 ]]; then
  echo "PASS  ${#FILES[@]} file(s) linted, no unsafe gcloud patterns found"
  exit 0
else
  echo "FAIL  $fails unsafe pattern(s) found across ${#FILES[@]} file(s)"
  exit 1
fi
