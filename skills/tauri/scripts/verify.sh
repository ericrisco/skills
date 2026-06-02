#!/usr/bin/env bash
# verify.sh — read-only static lint for a Tauri v2 project (src-tauri/ tree).
#
# Mirrors the SKILL.md anti-patterns so the advice is checkable. It scans the
# target for the failure modes people actually ship. It is a LINT — no build,
# no network, no Cargo, deterministic, CI-safe. Read-only: never writes anything.
#
# Severity model (per the spec — heuristic + advisory):
#   WARN  — likely-wrong, advisory. Does NOT fail the run.
#   FAIL  — a hard structural break (v1 allowlist in a v2 config). Fails the run.
#
# Checks:
#   1. FAIL  legacy v1 `"allowlist"` key in tauri.conf.json (v2 uses capabilities).
#   2. WARN  src-tauri/ present but no capabilities/*.json — default-deny means zero IPC,
#            usually a mistake unless the app makes no Rust calls.
#   3. WARN  a capability lists no permissions (empty/absent "permissions").
#   4. WARN  a command in generate_handler![...] has no matching #[tauri::command] fn.
#   5. WARN  a fallible-looking command (read/write/fetch/load/save/delete/open) whose
#            signature returns no `Result` — likely should return Result<T, E>.
#   6. WARN  no CSP set anywhere in tauri.conf.json (app.security.csp).
#
# Exits 0 on a clean OR empty target, and on WARN-only. Exits 1 only on a FAIL.
# Usage: verify.sh [TARGET_DIR]   (default ".")

set -uo pipefail

TARGET="${1:-.}"
fail=0
warned=0

warn() { printf 'WARN [%s] %s — %s\n' "$1" "$2" "$3" >&2; warned=1; }
hard() { printf 'FAIL [%s] %s — %s\n' "$1" "$2" "$3" >&2; fail=1; }
note() { printf '%s\n' "$1"; }

if [ ! -e "$TARGET" ]; then
  note "verify: target does not exist: $TARGET — nothing to check."
  exit 0
fi

# Locate the src-tauri dir (the target may be it, contain it, or be a single file).
srctauri=""
if [ -d "$TARGET/src-tauri" ]; then
  srctauri="$TARGET/src-tauri"
elif [ -d "$TARGET" ] && [ "$(basename "$TARGET")" = "src-tauri" ]; then
  srctauri="$TARGET"
else
  found=$(find "$TARGET" -type d -name src-tauri -not -path '*/.git/*' 2>/dev/null | head -n1)
  [ -n "$found" ] && srctauri="$found"
fi

# --- tauri.conf.json checks (run wherever a conf is found) ---------------------
conf_files=()
while IFS= read -r f; do conf_files+=("$f"); done < <(
  find "$TARGET" -type f -name 'tauri.conf.json' -not -path '*/.git/*' 2>/dev/null
)

if [ "${#conf_files[@]}" -eq 0 ] && [ -z "$srctauri" ]; then
  note "verify: no Tauri project found under $TARGET (no src-tauri/, no tauri.conf.json) — nothing to check."
  exit 0
fi

for conf in "${conf_files[@]}"; do
  content=$(tr -d '\r' < "$conf")

  # Rule 1 (FAIL): v1 allowlist key.
  if printf '%s' "$content" | grep -Eq '"allowlist"[[:space:]]*:'; then
    ln=$(grep -nE '"allowlist"[[:space:]]*:' "$conf" | head -n1 | cut -d: -f1)
    hard "v1-allowlist" "$conf:${ln:-?}" 'v1 "allowlist" key in a v2 config — replace with capabilities/*.json'
  fi

  # Rule 6 (WARN): no CSP.
  if ! printf '%s' "$content" | grep -Eq '"csp"[[:space:]]*:'; then
    warn "no-csp" "$conf" 'no app.security.csp set — the WebView runs any loaded script; set a CSP for prod'
  fi
done

# --- capabilities checks -------------------------------------------------------
if [ -n "$srctauri" ]; then
  capdir="$srctauri/capabilities"
  cap_files=()
  if [ -d "$capdir" ]; then
    while IFS= read -r f; do cap_files+=("$f"); done < <(
      find "$capdir" -type f -name '*.json' 2>/dev/null
    )
  fi

  # Rule 2 (WARN): src-tauri present but no capability files.
  if [ "${#cap_files[@]}" -eq 0 ]; then
    warn "no-capabilities" "$srctauri" 'no capabilities/*.json — default-deny means zero IPC access; add a scoped capability'
  fi

  # Rule 3 (WARN): a capability with no permissions.
  for cap in ${cap_files[@]+"${cap_files[@]}"}; do
    capc=$(tr -d '\r' < "$cap")
    if ! printf '%s' "$capc" | grep -Eq '"permissions"[[:space:]]*:[[:space:]]*\['; then
      warn "cap-no-perms" "$cap" 'capability has no "permissions" array — it grants nothing (or is malformed)'
    elif printf '%s' "$capc" | grep -Eq '"permissions"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]'; then
      warn "cap-no-perms" "$cap" 'capability "permissions" is empty — grants nothing'
    fi
  done
fi

# --- command checks (Rust) -----------------------------------------------------
if [ -n "$srctauri" ]; then
  rs_files=()
  while IFS= read -r f; do rs_files+=("$f"); done < <(
    find "$srctauri" -type f -name '*.rs' -not -path '*/target/*' 2>/dev/null
  )

  # Gather the set of #[tauri::command] fn names and their (multi-line) signatures.
  declared_names=""
  for rs in ${rs_files[@]+"${rs_files[@]}"}; do
    # Find lines with the command attribute, then the fn name on a following line.
    # awk: when we see the attribute, capture the next fn <name>.
    while IFS= read -r name; do
      [ -n "$name" ] && declared_names="$declared_names $name"
    done < <(awk '
      /#\[tauri::command/ { armed=1; next }
      armed && /fn[ \t]+[A-Za-z_][A-Za-z0-9_]*/ {
        match($0, /fn[ \t]+[A-Za-z_][A-Za-z0-9_]*/)
        s=substr($0, RSTART, RLENGTH); sub(/fn[ \t]+/, "", s); print s; armed=0
      }
      armed && NF==0 { next }
    ' "$rs")
  done

  # Rule 4 (WARN): names inside generate_handler![...] with no declared command.
  for rs in ${rs_files[@]+"${rs_files[@]}"}; do
    # Extract the comma list between generate_handler![ and the closing ].
    handler=$(tr -d '\r' < "$rs" | tr '\n' ' ' | grep -oE 'generate_handler!\[[^]]*\]' || true)
    [ -z "$handler" ] && continue
    inner=$(printf '%s' "$handler" | sed -E 's/.*generate_handler!\[//; s/\].*//')
    # Split on commas, strip module paths (mod::cmd -> cmd) and whitespace.
    IFS=',' read -ra regs <<< "$inner"
    for r in "${regs[@]}"; do
      r=$(printf '%s' "$r" | tr -d ' \t')
      r="${r##*::}"
      [ -z "$r" ] && continue
      case " $declared_names " in
        *" $r "*) : ;;
        *) warn "unregistered-cmd" "$rs" "generate_handler! lists '$r' but no #[tauri::command] fn '$r' was found" ;;
      esac
    done
  done

  # Rule 5 (WARN): fallible-looking command without Result in its signature.
  for rs in ${rs_files[@]+"${rs_files[@]}"}; do
    while IFS= read -r nm; do
      [ -n "$nm" ] && warn "no-result" "$rs" "command '$nm' looks fallible but returns no Result<T, E> — Err should become a rejected JS promise"
    done < <(awk '
      /#\[tauri::command/ { armed=1; sig=""; next }
      armed {
        sig = sig " " $0
        if (sig ~ /\{/ || sig ~ /;/) {
          # signature complete (body brace or decl end)
          if (match(sig, /fn[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            nm=substr(sig, RSTART, RLENGTH); sub(/fn[ \t]+/, "", nm)
            if (nm ~ /^(read|write|fetch|load|save|delete|open|get|put|post)_/ && sig !~ /Result[ \t]*</) {
              print nm
            }
          }
          armed=0
        }
      }
    ' "$rs")
  done
fi

if [ "$fail" -ne 0 ]; then
  note "verify: Tauri lint FAILED — fix the structural issue(s) above."
  exit 1
fi
if [ "$warned" -ne 0 ]; then
  note "verify: Tauri lint passed with advisory warnings (review above; not fatal)."
  exit 0
fi
note "verify: Tauri project passes the static lint."
exit 0
