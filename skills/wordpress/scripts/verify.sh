#!/usr/bin/env bash
#
# verify.sh — static, read-only scan of a WordPress theme/plugin/config tree for
# the anti-patterns this skill warns about. Emits PASS/FAIL lines.
#
# Usage:   scripts/verify.sh [TARGET_DIR]   (default: current directory)
# Exit:    0 if clean OR target has no PHP to scan; 1 if any FAIL.
#
# Read-only: never writes, never modifies. Safe to run in CI.

set -u

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "verify.sh: target '$TARGET' is not a directory" >&2
  exit 2
fi

# Collect PHP files, ignoring dependency/build/VCS dirs.
PHP_FILES="$(find "$TARGET" -type f -name '*.php' \
  -not -path '*/vendor/*' \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/build/*' 2>/dev/null)"

if [ -z "$PHP_FILES" ]; then
  echo "PASS  no PHP files found under '$TARGET' — nothing to scan"
  exit 0
fi

fails=0

# report CHECK_NAME PATTERN_DESC HITS  — runs in the parent shell (no pipe/subshell)
# so the failure counter survives.
report() {
  local name="$1" desc="$2" hits="$3"
  if [ -n "$hits" ]; then
    echo "FAIL  $name — $desc"
    echo "$hits" | sed 's/^/        /'
    fails=$((fails + 1))
  else
    echo "PASS  $name"
  fi
}

# grep helper across collected PHP files; prints file:line, never errors out.
scan() {
  echo "$PHP_FILES" | tr '\n' '\0' | xargs -0 grep -nE "$1" 2>/dev/null
}

# 1. Hardcoded DB credentials with a real (non-empty, non-placeholder) value.
report "no-hardcoded-db-creds" "DB_* defined with a literal value in committed PHP" \
  "$(scan "define\(\s*['\"]DB_(PASSWORD|USER|NAME|HOST)['\"]\s*,\s*['\"][^'\"]+['\"]" \
     | grep -viE "database_name_here|username_here|password_here|put your")"

# 2. Salt/auth keys committed with a literal (not the sample placeholder).
report "no-committed-salts" "AUTH/NONCE key or salt with a literal value" \
  "$(scan "define\(\s*['\"](AUTH|SECURE_AUTH|LOGGED_IN|NONCE)_(KEY|SALT)['\"]\s*,\s*['\"][^'\"]+['\"]" \
     | grep -viE "put your unique phrase here")"

# 3. Obfuscation / dynamic-exec smells.
report "no-eval-obfuscation" "eval()/base64_decode()/gzinflate()/str_rot13()" \
  "$(scan "\b(eval|base64_decode|gzinflate|str_rot13)\s*\(")"

# 4. query_posts() instead of WP_Query.
report "no-query-posts" "query_posts() — use WP_Query or pre_get_posts" \
  "$(scan "\bquery_posts\s*\(")"

# 5. Raw \$wpdb query/get_results with interpolated vars (no prepare on the line).
report "wpdb-prepared" "\$wpdb call with interpolated variable and no prepare()" \
  "$(scan "\\\$wpdb->(query|get_results|get_var|get_row|get_col)\s*\(\s*[\"'][^\"']*\\\$" \
     | grep -v "prepare")"

# 6. Hardcoded script/style tags in templates (must enqueue).
report "no-hardcoded-assets" "<script src>/<link stylesheet> in PHP — enqueue instead" \
  "$(scan "<(script[^>]*\bsrc=|link[^>]*\brel=[\"']?stylesheet)")"

# 7. DISALLOW_FILE_EDIT present when a wp-config.php is in scope.
WPCONFIG="$(echo "$PHP_FILES" | grep -E '/wp-config\.php$' || true)"
if [ -n "$WPCONFIG" ]; then
  if echo "$WPCONFIG" | tr '\n' '\0' | xargs -0 grep -qE "define\(\s*['\"]DISALLOW_FILE_EDIT['\"]\s*,\s*true" 2>/dev/null; then
    echo "PASS  disallow-file-edit"
  else
    echo "FAIL  disallow-file-edit — wp-config.php present without define('DISALLOW_FILE_EDIT', true)"
    fails=$((fails + 1))
  fi
fi

echo "---"
if [ "$fails" -gt 0 ]; then
  echo "$fails check(s) FAILED"
  exit 1
fi
echo "all checks PASSED"
exit 0
