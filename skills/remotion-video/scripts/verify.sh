#!/usr/bin/env bash
# verify.sh — check that a Remotion project is well-formed and (optionally) renders.
#
# Usage:
#   bash scripts/verify.sh <project-dir>            # read-only: static + `remotion compositions`
#   bash scripts/verify.sh <project-dir> --render   # also do a short region test render + ffprobe
#   bash scripts/verify.sh                          # no target -> nothing to check, exit 0
#
# Default mode is READ-ONLY: it never renders, installs, or writes. A render produces
# a file and burns CPU, so the actual test render is gated behind --render (opt-in).
#
# What it checks, in the spec's order:
#   1. If Node + a Remotion project are present: `npx remotion compositions` succeeds
#      and lists at least one composition id (read-only).
#   2. With --render AND ffmpeg present: render a short region (frames 0-15) of the
#      first composition to a temp MP4, assert it is non-empty, and `ffprobe` confirms
#      a video stream with width/height. The temp file is removed.
#   3. Static fallback (no node, or no project, or --render not given): assert at least
#      one composition .tsx exists and a render script/command references a real
#      composition id + an output path.
#
# Exits 0 on a clean project AND on an empty/clean target (no false failure):
#   - no argument            -> "nothing to check", exit 0
#   - dir with no .tsx files -> nothing to verify, exit 0
# Exits non-zero only when a real, present project breaks a rule.
#
# Portability: stock macOS bash 3.2. set -u on; set -e off (each check owns its exit).

set -u

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; RESET="$(tput sgr0)"
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

fail() { printf '%s\n' "${RED}FAIL: $1${RESET}"; failures=$((failures + 1)); }
warn() { printf '%s\n' "${YELLOW}WARN: $1${RESET}"; }
ok()   { printf '%s\n' "${GREEN}OK: $1${RESET}"; }

# --- args ------------------------------------------------------------------
target=""
do_render=0
for arg in "$@"; do
  case "$arg" in
    --render) do_render=1 ;;
    *) [ -z "$target" ] && target="$arg" || warn "ignoring extra argument '$arg'" ;;
  esac
done

if [ -z "$target" ]; then
  printf '%s\n' "${YELLOW}Nothing to check (no project dir given). Pass a Remotion project directory.${RESET}"
  exit 0
fi

if [ ! -d "$target" ]; then
  printf '%s\n' "${YELLOW}'$target' is not a directory. Pass a Remotion project directory. Nothing to check.${RESET}"
  exit 0
fi

failures=0

# --- find composition .tsx files (look in target and target/src) -----------
tsx_files=""
for d in "$target" "$target/src"; do
  [ -d "$d" ] || continue
  for f in "$d"/*.tsx "$d"/**/*.tsx; do
    [ -e "$f" ] && tsx_files="${tsx_files}${tsx_files:+
}$f"
  done
done
# de-dup is unnecessary; just detect presence
has_tsx=0
[ -n "$tsx_files" ] && has_tsx=1

if [ "$has_tsx" -eq 0 ]; then
  printf '%s\n' "${YELLOW}No .tsx files under '$target' (or '$target/src'). Not a Remotion project — nothing to verify.${RESET}"
  exit 0
fi

printf '\n%s\n' "Checking Remotion project: $target"

# --- extract a composition id from <Composition id="..."> -------------------
comp_id="$(grep -rhoE 'id[[:space:]]*=[[:space:]]*"[^"]+"' $tsx_files 2>/dev/null \
  | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"

# =============================================================================
# Mode 1: dynamic check via the Remotion CLI (read-only)
# =============================================================================
ran_dynamic=0
if command -v node >/dev/null 2>&1 && command -v npx >/dev/null 2>&1 \
   && [ -f "$target/package.json" ]; then
  printf '%s\n' "node + package.json present — listing compositions (read-only)..."
  comps="$(cd "$target" && npx --no-install remotion compositions 2>/dev/null)"
  if [ -n "$comps" ]; then
    ran_dynamic=1
    ok "remotion compositions succeeded"
    listed_id="$(printf '%s\n' "$comps" | grep -vE '^(Composition|----|$)' | awk '{print $1}' | grep -v '^$' | head -1)"
    [ -z "$listed_id" ] && listed_id="$(printf '%s\n' "$comps" | awk 'NR==2{print $1}')"
    if [ -n "$listed_id" ]; then
      ok "found composition id: $listed_id"
      [ -z "$comp_id" ] && comp_id="$listed_id"
    else
      fail "remotion compositions listed no usable composition id"
    fi

    # --- Mode 2: optional region test render (opt-in, writes a temp file) ---
    if [ "$do_render" -eq 1 ] && [ -n "$comp_id" ]; then
      if command -v ffprobe >/dev/null 2>&1; then
        tmp_out="$(mktemp -t remotion-verify-XXXXXX).mp4"
        printf '%s\n' "Rendering region test (frames 0-15) of '$comp_id' -> $tmp_out ..."
        if (cd "$target" && npx --no-install remotion render "$comp_id" "$tmp_out" --frames=0-15 >/dev/null 2>&1) && [ -s "$tmp_out" ]; then
          dims="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$tmp_out" 2>/dev/null)"
          if [ -n "$dims" ]; then
            ok "render produced a non-empty MP4 with a video stream ($dims)"
          else
            fail "render produced a file but ffprobe found no video stream"
          fi
        else
          fail "region test render failed or produced an empty file"
        fi
        rm -f "$tmp_out"
      else
        warn "--render requested but ffprobe not found; skipping the render check."
      fi
    elif [ "$do_render" -eq 0 ]; then
      printf '%s\n' "(read-only mode: pass --render to also do a region test render + ffprobe)"
    fi
  else
    warn "remotion CLI not runnable here (deps not installed?) — falling back to static checks."
  fi
fi

# =============================================================================
# Mode 3: static fallback (no node/CLI run, or CLI unavailable)
# =============================================================================
if [ "$ran_dynamic" -eq 0 ]; then
  printf '%s\n' "Static checks (no runnable Remotion CLI):"
  if [ -n "$comp_id" ]; then
    ok "found a <Composition> with id: $comp_id"
  else
    fail "no <Composition id=\"...\"> found in any .tsx — a Remotion project needs at least one composition."
  fi
fi

# --- render command references a real id + an output path (both modes) ------
render_cmd="$(grep -rhoE 'remotion render[^\"'\''<]*' $tsx_files "$target"/*.json "$target"/*.ts "$target"/*.md "$target"/scripts/* 2>/dev/null | head -1)"
if [ -n "$render_cmd" ]; then
  if printf '%s' "$render_cmd" | grep -qE 'remotion render[[:space:]]+[A-Za-z0-9_-]+'; then
    ok "a render command references a composition id"
  else
    warn "found 'remotion render' but no explicit composition id after it (a picker will prompt)."
  fi
  if printf '%s' "$render_cmd" | grep -qiE '\.(mp4|mov|webm|gif)'; then
    ok "the render command names an output path"
  else
    warn "render command has no explicit output file (.mp4/.mov/.webm/.gif)."
  fi
else
  warn "no 'remotion render' command found in the project files (scripts/, package.json, *.md)."
fi

printf '\n'
if [ "$failures" -gt 0 ]; then
  printf '%s\n' "${RED}$failures check(s) failed.${RESET}"
  exit 1
fi
printf '%s\n' "${GREEN}All checks passed.${RESET}"
exit 0
