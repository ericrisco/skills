#!/usr/bin/env bash
set -euo pipefail

# verify.sh — data-cleaning skill check. Run from anywhere. Read-only by default.
#
# Two layers:
#   STATIC (always): SKILL.md exists, frontmatter has the required keys, description is one
#     physical line, and both references/ files exist and are non-empty.
#   RUNTIME (only if pandas + pandera importable): build a tiny fixture with ONE clearly-good
#     row and ONE clearly-bad row (negative age / unmapped country), run a pandera schema with
#     lazy=True, and assert the good row PASSES while the bad row is FLAGGED — proving the gate
#     is not a no-op. If pandas/pandera are absent, print SKIP and still pass the static checks.
#
# Writes only inside a private mktemp dir, removed on exit. No network.
# Exit: 0 on pass or skip; non-zero ONLY on a real failure (missing artifact, malformed
# frontmatter, or a gate that fails to reject a known-bad row).

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SKILL="$SKILL_DIR/SKILL.md"
fail=0

# ---- STATIC CHECKS (always run) ----
if [ ! -f "$SKILL" ]; then
  err "SKILL.md not found at $SKILL"; exit 1
fi
ok "SKILL.md present"

for key in "name:" "description:" "tags:" "recommends:" "origin:"; do
  if grep -q "^${key}" "$SKILL"; then
    ok "frontmatter has ${key%:}"
  else
    err "frontmatter missing ${key%:}"; fail=1
  fi
done

# description must be exactly one physical line
desc_lines="$(grep -c '^description:' "$SKILL" || true)"
if [ "$desc_lines" = "1" ]; then
  ok "description present as a single key line"
else
  err "expected exactly one 'description:' line, found $desc_lines"; fail=1
fi

for ref in "references/validation-patterns.md" "references/normalization-recipes.md"; do
  if [ -s "$SKILL_DIR/$ref" ]; then
    ok "$ref present and non-empty"
  else
    err "$ref missing or empty"; fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  err "static checks failed"; exit 1
fi

# ---- RUNTIME GATE CHECK (only if deps present) ----
if ! command -v python3 >/dev/null 2>&1; then
  skip "python3 not found — ran static checks only"; exit 0
fi
if ! python3 -c "import pandas, pandera" >/dev/null 2>&1; then
  skip "pandas/pandera not importable — ran static checks only"; exit 0
fi

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t dc_verify)"
trap 'rm -rf "$TMP"' EXIT

python3 - <<'PY'
import sys
import pandas as pd
import pandera.pandas as pa
from pandera.typing import Series

# Fixture: row 1 is clearly GOOD; row 2 is clearly BAD (negative age + unmapped country -> NA).
COUNTRY = {"usa": "US", "u.s.": "US", "united states": "US", "es": "ES"}
raw = pd.DataFrame({
    "customer_id": [1, 2],
    "country":     ["U.S.", "Atlantis"],   # row2 unmapped -> NA -> fails isin
    "age":         [42, -5],               # row2 out of range -> fails ge(0)
})
raw["country"] = raw["country"].str.strip().str.casefold().map(COUNTRY)

class Schema(pa.DataFrameModel):
    customer_id: Series[int]   = pa.Field(ge=1, unique=True)
    country:     Series[str]   = pa.Field(isin=["US", "ES", "FR"])
    age:         Series[float] = pa.Field(ge=0, le=120)
    class Config:
        coerce = True
        strict = True

try:
    Schema.validate(raw, lazy=True)
    print("GATE-NOOP: schema accepted a known-bad row")  # gate did nothing -> failure
    sys.exit(1)
except pa.errors.SchemaErrors as e:
    bad_idx = set(e.failure_cases["index"].dropna().astype(int).unique())
    # The bad row (index 1) must be flagged; the good row (index 0) must NOT be.
    if 1 in bad_idx and 0 not in bad_idx:
        sys.exit(0)
    print(f"GATE-WRONG: flagged indices were {sorted(bad_idx)}; expected {{1}}")
    sys.exit(1)
PY
rc=$?
if [ "$rc" -eq 0 ]; then
  ok "validation gate rejected the bad row and passed the good row (gate is not a no-op)"
  exit 0
else
  err "validation gate did not behave as documented"
  exit 1
fi
