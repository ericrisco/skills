#!/usr/bin/env bash
set -euo pipefail

# sync-bundles.sh — materialize each bundle plugin as REAL COPIES of the
# canonical skills/ (replacing symlinks), so plugins are self-contained for
# tarball / zip / Windows distribution.
#
# skills/ is the single source of truth. After editing any skill, re-run this
# to refresh the plugin copies.
#
# Idempotent: each target is removed (rm -rf) then re-copied (cp -R).
# bash 3.2-safe: no mapfile, no associative arrays, no unguarded ${arr[@]}.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
SKILLS_DIR="$REPO_ROOT/skills"
PLUGINS_DIR="$REPO_ROOT/plugins"

# Bundle map: one line per bundle, "bundle skill1 skill2 ...".
# Parsed with a case dispatch to stay bash 3.2 / set -u safe.
BUNDLES="rsc-core rsc-backend rsc-frontend rsc-content rsc-agents rsc-ops rsc-sdd"

skills_for_bundle() {
  case "$1" in
    rsc-core)     echo "init harness author-skill" ;;
    rsc-backend)  echo "fastapi go postgresdb" ;;
    rsc-frontend) echo "nextjs flutter design" ;;
    rsc-content)  echo "marketing presentations course-storytelling" ;;
    rsc-agents)   echo "building-agents" ;;
    rsc-ops)      echo "secure-coding deployment" ;;
    rsc-sdd)      echo "sdd constitution specify clarify plan tasks analyze implement verify review ship debug worktrees parallel" ;;
    *)            echo "" ;;
  esac
}

copied=0
echo "sync-bundles: canonical source = $SKILLS_DIR"
echo

for bundle in $BUNDLES; do
  skills=$(skills_for_bundle "$bundle")
  bundle_skills_dir="$PLUGINS_DIR/$bundle/skills"
  mkdir -p "$bundle_skills_dir"

  echo "[$bundle]"
  for skill in $skills; do
    src="$SKILLS_DIR/$skill"
    target="$bundle_skills_dir/$skill"

    if [ ! -d "$src" ]; then
      echo "  ERROR: canonical skill not found: $src" >&2
      exit 1
    fi

    # Remove whatever is there (symlink or real dir), then copy fresh.
    rm -rf "$target"
    cp -R "$src" "$target"
    copied=$((copied + 1))
    echo "  copied skills/$skill -> plugins/$bundle/skills/$skill"
  done
  echo
done

echo "sync-bundles: materialized $copied skill copy/copies across bundles."
