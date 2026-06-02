#!/usr/bin/env bash
set -euo pipefail

# verify.sh — reporting pipeline artifact check. Read-only by default.
#
# What it proves about the pipeline this skill emits:
#   1. A Jinja2 template (*.html.j2 / *.j2 / *.jinja) exists and PARSES (and renders against an
#      empty sample context without a syntax error).
#   2. A non-empty report artifact exists (a *.pdf or rendered *.html bigger than a trivial stub).
#   3. A schedule is defined: a crontab-style line in any file, OR a .github/workflows/*.yml that
#      contains a `schedule:` block.
#   4. A delivery step is wired (a script references a send/email/upload/deliver path).
#   Soft-warn (never fail) if no freshness/failure gate is detected.
#
# Targets, in order of precedence:
#   - explicit paths passed as arguments (files or directories), OR
#   - the current working directory.
#
# It NEVER modifies files and makes NO network/SMTP/API calls — delivery and schedule are validated
# by structure, not by sending anything.
#
# Exit code: 0 on pass OR on a clean/empty target (nothing to check is not a failure).
# Non-zero ONLY when a found artifact is genuinely broken (template won't parse, only empty artifacts,
# no schedule definition, or no delivery step) AND the target actually looks like a report pipeline.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }

PY="$(command -v python3 || command -v python || true)"

TARGET="${1:-$PWD}"
if [ ! -e "$TARGET" ]; then
  err "target does not exist: $TARGET"; exit 1
fi
ROOT="$TARGET"; [ -f "$TARGET" ] && ROOT="$(dirname "$TARGET")"

# Collect candidate artifacts.
TEMPLATES=(); PDFS=(); HTMLS=(); WORKFLOWS=(); SCRIPTS=()
if [ -d "$TARGET" ]; then
  while IFS= read -r f; do TEMPLATES+=("$f"); done < <(find "$TARGET" -type f \( -name '*.j2' -o -name '*.jinja' -o -name '*.jinja2' \) 2>/dev/null)
  while IFS= read -r f; do PDFS+=("$f");      done < <(find "$TARGET" -type f -name '*.pdf'  2>/dev/null)
  while IFS= read -r f; do HTMLS+=("$f");     done < <(find "$TARGET" -type f -name '*.html' 2>/dev/null)
  while IFS= read -r f; do WORKFLOWS+=("$f"); done < <(find "$TARGET" -path '*/.github/workflows/*' \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null)
  while IFS= read -r f; do SCRIPTS+=("$f");   done < <(find "$TARGET" -type f \( -name '*.py' -o -name '*.sh' -o -name '*.js' -o -name '*.ts' \) 2>/dev/null)
fi

# If we found nothing that resembles a report pipeline, this is not our target — pass cleanly.
if [ "${#TEMPLATES[@]}" -eq 0 ] && [ "${#PDFS[@]}" -eq 0 ] && [ "${#HTMLS[@]}" -eq 0 ] \
   && [ "${#WORKFLOWS[@]}" -eq 0 ] && [ "${#SCRIPTS[@]}" -eq 0 ]; then
  skip "no report-pipeline artifacts found (template / pdf / html / workflow / script) — nothing to check"
  exit 0
fi

fail=0

# 1. Template parses and renders against an empty context.
if [ "${#TEMPLATES[@]}" -eq 0 ]; then
  warn "no Jinja2 template (*.j2) found — a report pipeline normally renders from a template"
elif [ -z "$PY" ] || ! "$PY" -c "import jinja2" >/dev/null 2>&1; then
  skip "python/jinja2 not available — skipping template render check"
else
  for t in ${TEMPLATES[@]+"${TEMPLATES[@]}"}; do
    if "$PY" - "$t" >/dev/null 2>&1 <<'PYEOF'
import sys, os
from jinja2 import Environment, FileSystemLoader
path = sys.argv[1]
env = Environment(loader=FileSystemLoader(os.path.dirname(path) or "."), autoescape=True)
src = open(path, encoding="utf-8").read()
env.parse(src)  # raises TemplateSyntaxError on a malformed template
# Render with a permissive (non-strict) empty context: proves it is renderable, not just parseable.
env.from_string(src).render()
PYEOF
    then
      ok "template parses + renders: $t"
    else
      err "template will not parse/render: $t"; fail=1
    fi
  done
fi

# 2. A non-empty artifact exists (PDF > 1KB, or HTML > 200 bytes and containing a tag).
artifact_ok=0
for f in ${PDFS[@]+"${PDFS[@]}"}; do
  size=$(wc -c < "$f" 2>/dev/null || echo 0)
  if [ "$size" -gt 1024 ]; then ok "non-empty PDF artifact: $f (${size} bytes)"; artifact_ok=1; fi
done
for f in ${HTMLS[@]+"${HTMLS[@]}"}; do
  size=$(wc -c < "$f" 2>/dev/null || echo 0)
  if [ "$size" -gt 200 ] && grep -q '<' "$f" 2>/dev/null; then
    ok "non-empty HTML artifact: $f (${size} bytes)"; artifact_ok=1
  fi
done
if [ "$artifact_ok" -eq 0 ]; then
  if [ "${#PDFS[@]}" -gt 0 ] || [ "${#HTMLS[@]}" -gt 0 ]; then
    err "found report artifact(s) but all were empty/stub — generation step produced nothing usable"; fail=1
  else
    warn "no rendered .pdf/.html artifact yet — run the generation step, then re-verify"
  fi
fi

# 3. Schedule definition: a workflow with schedule:, OR a crontab-style line somewhere.
schedule_ok=0
for w in ${WORKFLOWS[@]+"${WORKFLOWS[@]}"}; do
  if grep -Eq '^[[:space:]]*schedule:' "$w" 2>/dev/null; then
    ok "GitHub Actions schedule defined: $w"; schedule_ok=1
  fi
done
if [ "$schedule_ok" -eq 0 ]; then
  # crontab-style: 5 fields (or @reboot/@daily etc.) at the start of a line in any file.
  while IFS= read -r hit; do
    [ -n "$hit" ] && { ok "cron schedule line found: ${hit}"; schedule_ok=1; break; }
  done < <(grep -rEl '(^|[[:space:]])(@(reboot|hourly|daily|weekly|monthly|yearly)|([0-9*/,-]+[[:space:]]+){4}[0-9*/,-]+)' \
            "$ROOT" 2>/dev/null | head -n 1)
fi
if [ "$schedule_ok" -eq 0 ]; then
  err "no schedule definition found (no .github/workflows/*.yml with 'schedule:' and no crontab line) — a report must ship on a cadence"
  fail=1
fi

# 4. Delivery step wired: a script references a send/deliver/email/upload path.
delivery_ok=0
if [ "${#SCRIPTS[@]}" -gt 0 ]; then
  if grep -rEliq '(send_?mail|sendmail|\bsend\b|smtp|deliver|email[_-]?connector|upload|drive\.files|messages\.send)' \
       "${SCRIPTS[@]}" 2>/dev/null; then
    ok "delivery step wired (send/deliver/upload reference found)"
    delivery_ok=1
  fi
fi
if [ "$delivery_ok" -eq 0 ]; then
  err "no delivery step wired — the report renders but nothing ships it (send/email/upload)"
  fail=1
fi

# Soft gate: freshness / failure handling (warn only, never fail).
if [ "${#SCRIPTS[@]}" -gt 0 ] && \
   grep -rEliq '(fresh|stale|max_age|updated_at|raise|sys\.exit\(1|alert|on_error|try:)' "${SCRIPTS[@]}" 2>/dev/null; then
  ok "freshness/failure gate detected"
else
  warn "no freshness/failure gate detected — add a stale-source check and fail-loud alert before send"
fi

if [ "$fail" -eq 0 ]; then
  ok "report pipeline checks passed"
  exit 0
fi
exit 1
