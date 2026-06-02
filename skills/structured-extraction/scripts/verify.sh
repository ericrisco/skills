#!/usr/bin/env bash
set -euo pipefail

# verify.sh — structured-extraction skill check. Run from anywhere. Read-only, no network, no SDK calls.
#
# This skill ships code-shaped guidance, so its rigor is a checkable artifact: a STATIC lint of the
# skill's OWN markdown examples. It asserts the guidance is internally consistent — it never runs any
# model or SDK.
#
# Checks:
#   1. SKILL.md exists and frontmatter has name/description/tags/recommends/origin; description is one line.
#   2. references/providers.md exists and is non-empty.
#   3. Every fenced code block in SKILL.md + references carries a language tag.
#   4. At least one example sets additionalProperties: false.
#   5. Optional fields are shown as a nullable union (["...","null"]) somewhere — not the omit-from-required trap.
#   6. The deprecated Anthropic output_format / structured-outputs-2025-11-13 header is NOT used as a
#      primary (Good) example — it may only appear flagged as deprecated.
#   7. No raw json.loads(/JSON.parse( on model output presented as the recommended path (the Good fences
#      must use native decoding; a raw-parse line is only allowed in a Bad/anti-pattern context).
#
# Exit: 0 when every present artifact passes (and 0 if SKILL.md is simply absent — empty target, no false
# failure). Non-zero only on a real inconsistency in a file that exists.

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; NC=$'\033[0m'
skip() { printf '%s[skip]%s %s\n' "$YELLOW" "$NC" "$*"; }
ok()   { printf '%s[ok]%s %s\n'   "$GREEN"  "$NC" "$*"; }
err()  { printf '%s[fail]%s %s\n' "$RED"    "$NC" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SKILL="$SKILL_DIR/SKILL.md"
REF="$SKILL_DIR/references/providers.md"
fail=0

# ---- empty target: nothing to check, do not fake a failure ----
if [ ! -f "$SKILL" ]; then
  skip "no SKILL.md at $SKILL — nothing to lint"; exit 0
fi
ok "SKILL.md present"

# ---- frontmatter keys ----
for key in "name:" "description:" "tags:" "recommends:" "origin:"; do
  if grep -q "^${key}" "$SKILL"; then
    ok "frontmatter has ${key%:}"
  else
    err "frontmatter missing ${key%:}"; fail=1
  fi
done

desc_lines="$(grep -c '^description:' "$SKILL" || true)"
if [ "$desc_lines" = "1" ]; then
  ok "description is a single key line"
else
  err "expected exactly one 'description:' line, found $desc_lines"; fail=1
fi

# ---- references present ----
if [ -s "$REF" ]; then
  ok "references/providers.md present and non-empty"
else
  err "references/providers.md missing or empty"; fail=1
fi

# Files to lint (only those that exist).
FILES=("$SKILL")
[ -f "$REF" ] && FILES+=("$REF")

# ---- every code fence is language-tagged ----
# A fence opener is a line starting with ``` ; count those with no language word after the backticks.
# Closers are paired, so we look at odd-indexed openers only via awk toggling.
for f in "${FILES[@]}"; do
  bad_fence="$(awk '
    /^```/ {
      infence = !infence
      if (infence) {            # this is an opener
        lang = substr($0, 4)
        gsub(/[ \t\r]/, "", lang)
        if (lang == "") c++
      }
      next
    }
    END { print c+0 }
  ' "$f")"
  if [ "$bad_fence" = "0" ]; then
    ok "$(basename "$f"): all code fences language-tagged"
  else
    err "$(basename "$f"): $bad_fence untagged code fence(s)"; fail=1
  fi
done

# ---- at least one additionalProperties: false example ----
if grep -Eq '"additionalProperties":[[:space:]]*[fF]alse|additionalProperties.*[fF]alse' "$SKILL" "$REF" 2>/dev/null; then
  ok "additionalProperties:false shown in an example"
else
  err "no example sets additionalProperties:false"; fail=1
fi

# ---- nullable union shown (optional-as-null, not omit-from-required) ----
if grep -Eq '"null"' "$SKILL" "$REF" 2>/dev/null; then
  ok "nullable union (\"...\",\"null\") shown for optional fields"
else
  err "no nullable-union example for optional fields"; fail=1
fi

# ---- deprecated Anthropic surface must not be a primary example ----
# Allowed ONLY on a line that also flags it as deprecated.
dep_bad=0
while IFS= read -r line; do
  case "$line" in
    *output_format*|*structured-outputs-2025-11-13*)
      case "$line" in
        *[Dd]eprecat*) : ;;                 # fine: flagged as deprecated
        *output_config*) : ;;               # fine: contrasting against the current param name
        *) dep_bad=1 ;;
      esac ;;
  esac
done < "$SKILL"
if [ "$dep_bad" = "0" ]; then
  ok "deprecated Anthropic output_format/header not used as a primary example"
else
  err "deprecated output_format / structured-outputs-2025-11-13 used without a deprecation flag"; fail=1
fi

# ---- raw parse on model output only allowed inside an explicitly-Bad context ----
# Walk SKILL.md tracking the nearest preceding 'Bad' marker per fenced block.
raw_bad=0
ctx_bad=0
infence=0
while IFS= read -r line; do
  case "$line" in
    '**Bad'*|'# Bad'*|'## Bad'*|*'Bad —'*|*'Bad -'*) ctx_bad=1 ;;
    '**Good'*|*'Good —'*|*'Good -'*) ctx_bad=0 ;;
  esac
  case "$line" in
    '```'*) infence=$((1-infence)); continue ;;
  esac
  if [ "$infence" = "1" ]; then
    case "$line" in
      *json.loads\(*|*JSON.parse\(*)
        # guaranteed-valid string is fine (parsing a decoder output is OK if it's the Good native path);
        # we only flag a raw parse that is NOT in a Bad block AND has no 'guaranteed'/'now' reassurance.
        case "$line" in
          *guaranteed*|*now\ guaranteed*) : ;;
          *)
            if [ "$ctx_bad" = "0" ]; then raw_bad=1; fi ;;
        esac ;;
    esac
  fi
done < "$SKILL"
if [ "$raw_bad" = "0" ]; then
  ok "no raw json.loads/JSON.parse on model output outside a Bad/anti-pattern context"
else
  err "raw json.loads(/JSON.parse( on model output presented as a recommended path"; fail=1
fi

if [ "$fail" -ne 0 ]; then
  err "static lint failed"; exit 1
fi
ok "all static checks passed"
exit 0
