#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NAME
#   verify.sh — secure-coding application-security gate
#
# USAGE
#   ./verify.sh
#   Run from the ROOT of YOUR project (the repo you are shipping), NOT from
#   the skills repository. It auto-detects your stack from the manifests it
#   finds (pyproject.toml / requirements*.txt / package.json / go.mod /
#   pubspec.yaml) and runs the matching auditors.
#
# WHAT IT DOES
#   1. Secret scan      — gitleaks over the working tree (and git history).
#   2. SAST             — semgrep ERROR rules (and informational WARNINGs).
#   3. Dependency CVEs  — per-stack: pip-audit/uv, osv-scanner/npm/pnpm/yarn,
#                         govulncheck, dart pub outdated (informational).
#   Each tool is DETECTED first; if it is missing the step is SKIPPED with a
#   yellow warning (never a failure). The script exits non-zero ONLY on real
#   high/critical findings.
#
# GUARANTEES
#   - Idempotent and read-only: it never writes to the repo and never auto-fixes.
#   - Network access only where a tool inherently needs it (CVE feeds).
#   - semgrep --config=auto (which fetches remote rules) is OPT-IN via the
#     SECURE_CODING_SEMGREP_AUTO=1 env var; without it, semgrep runs only when
#     a local config is present.
#
# ENV TOGGLES
#   SECURE_CODING_SEMGREP_AUTO=1  Enable semgrep's network-fetched "auto" rules.
#   NO_COLOR=1                    Disable ANSI color output.
#
# EXIT CODES
#   0  No high/critical findings (skips and informational warnings are fine).
#   1  At least one real high/critical finding — resolve before merge.
# ============================================================================

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
[[ -n "${NO_COLOR:-}" ]] && { RED=""; YEL=""; GRN=""; RST=""; }

FAILED=0
warn()    { printf '%s[skip]%s %s\n' "$YEL" "$RST" "$*" >&2; }
ok()      { printf '%s[ok]%s %s\n'   "$GRN" "$RST" "$*"; }
bad()     { printf '%s[FAIL]%s %s\n' "$RED" "$RST" "$*" >&2; FAILED=1; }
info()    { printf '%s[info]%s %s\n' "$YEL" "$RST" "$*"; }
have()    { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n=== %s ===\n' "$*"; }

# need <tool> <install-hint> : guard a tool block. Returns 0 if present,
# else prints a skip warning and returns 1 so the caller can skip the block.
need() {
  if have "$1"; then
    return 0
  fi
  warn "$1 not installed (install: $2)"
  return 1
}

# ----------------------------------------------------------------------------
# 1. Secrets — gitleaks
# ----------------------------------------------------------------------------
section "Secrets (gitleaks)"
if need gitleaks "brew install gitleaks / https://github.com/gitleaks/gitleaks"; then
  # `gitleaks detect` scans the working tree; inside a git repo it also walks
  # commit history. --redact keeps secret values out of this terminal output.
  if gitleaks detect --no-banner --redact --exit-code 1; then
    ok "no secrets detected"
  else
    bad "gitleaks found secrets — rotate the exposed credential, THEN scrub history"
  fi
fi

# ----------------------------------------------------------------------------
# 2. SAST — semgrep
# ----------------------------------------------------------------------------
section "SAST (semgrep)"
if need semgrep "pipx install semgrep / brew install semgrep"; then
  CFG=""
  if   [[ -f .semgrep.yml  ]]; then CFG="--config .semgrep.yml"
  elif [[ -f .semgrep.yaml ]]; then CFG="--config .semgrep.yaml"
  elif [[ -f semgrep.yml   ]]; then CFG="--config semgrep.yml"
  elif [[ -d .semgrep      ]]; then CFG="--config .semgrep"
  elif [[ "${SECURE_CODING_SEMGREP_AUTO:-}" == "1" ]]; then CFG="--config=auto"
  fi

  if [[ -z "$CFG" ]]; then
    warn "no semgrep config found and SECURE_CODING_SEMGREP_AUTO unset; skipping SAST"
  else
    # ERROR-severity findings gate the build.
    if semgrep $CFG --error --severity ERROR --quiet; then
      ok "no semgrep ERROR findings"
    else
      bad "semgrep reported ERROR-severity findings"
    fi
    # WARNING-severity findings are informational only and must never abort
    # the script (set -e) nor flip FAILED.
    semgrep $CFG --severity WARNING --quiet || warn "semgrep WARNING findings present (informational)"
  fi
fi

# ----------------------------------------------------------------------------
# 3. Per-stack dependency audit — detect by manifest, run ALL that match
# ----------------------------------------------------------------------------
section "Dependency audit"

# --- Python ---------------------------------------------------------------
if [[ -f pyproject.toml ]] || ls requirements*.txt >/dev/null 2>&1; then
  if have uv; then
    if uv pip audit; then ok "python deps: no known vulns (uv pip audit)"
    else bad "python deps: vulnerabilities reported by uv pip audit"; fi
  elif need pip-audit "pipx install pip-audit"; then
    if pip-audit; then ok "python deps: no known vulns (pip-audit)"
    else bad "python deps: vulnerabilities reported by pip-audit"; fi
  fi
fi

# --- Node / TypeScript ----------------------------------------------------
if [[ -f package.json ]]; then
  if have osv-scanner; then
    LOCK=""
    if   [[ -f pnpm-lock.yaml     ]]; then LOCK="pnpm-lock.yaml"
    elif [[ -f package-lock.json  ]]; then LOCK="package-lock.json"
    elif [[ -f yarn.lock          ]]; then LOCK="yarn.lock"
    fi
    if [[ -n "$LOCK" ]]; then
      if osv-scanner --lockfile="$LOCK"; then ok "node deps: no known vulns (osv-scanner $LOCK)"
      else bad "node deps: vulnerabilities reported by osv-scanner"; fi
    else
      if osv-scanner --recursive .; then ok "node deps: no known vulns (osv-scanner recursive)"
      else bad "node deps: vulnerabilities reported by osv-scanner"; fi
    fi
  elif [[ -f pnpm-lock.yaml ]] && have pnpm; then
    if pnpm audit --prod --audit-level high; then ok "node deps: no high+ vulns (pnpm audit)"
    else bad "node deps: high+ vulnerabilities reported by pnpm audit"; fi
  elif [[ -f yarn.lock ]] && have yarn; then
    # Yarn Berry (>=2) ships `yarn npm audit`; classic yarn lacks a severity
    # gate, so skip+warn rather than fail noisily.
    if yarn npm audit --severity high >/dev/null 2>&1; then
      if yarn npm audit --severity high; then ok "node deps: no high+ vulns (yarn npm audit)"
      else bad "node deps: high+ vulnerabilities reported by yarn npm audit"; fi
    else
      warn "yarn classic has no severity-gated audit; install osv-scanner instead"
    fi
  elif need npm "https://nodejs.org/"; then
    if npm audit --omit=dev --audit-level=high; then ok "node deps: no high+ vulns (npm audit)"
    else bad "node deps: high+ vulnerabilities reported by npm audit"; fi
  fi
fi

# --- Go -------------------------------------------------------------------
if [[ -f go.mod ]]; then
  if need govulncheck "go install golang.org/x/vuln/cmd/govulncheck@latest"; then
    # govulncheck reports only vulns your code actually CALLS (reachability).
    if govulncheck ./...; then ok "go deps: no reachable vulns (govulncheck)"
    else bad "go deps: reachable vulnerabilities reported by govulncheck"; fi
  fi
fi

# --- Dart / Flutter -------------------------------------------------------
if [[ -f pubspec.yaml ]]; then
  # pub.dev has no CVE feed; `dart pub outdated` only flags stale versions.
  # This step is INFORMATIONAL and never sets FAILED.
  if need dart "https://dart.dev/get-dart"; then
    dart pub outdated --mode=null-safety || true
    info "dart deps: review outdated packages above (no CVE feed; advisory only)"
  fi
fi

# ----------------------------------------------------------------------------
# 4. Summary
# ----------------------------------------------------------------------------
section "Summary"
if [[ "$FAILED" -eq 0 ]]; then
  ok "no high/critical findings"
else
  printf '%shigh/critical findings present — resolve before merge%s\n' "$RED" "$RST" >&2
fi
exit "$FAILED"
