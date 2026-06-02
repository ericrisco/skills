#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# NAME
#   verify.sh — hetzner cloud-init / SSH-hardening static lint
#
# USAGE
#   ./verify.sh [path/to/cloud-init.yaml]
#   With no argument it scans the current directory for cloud-init*.yaml|yml.
#   Run it BEFORE you create a server, against the user-data file you will pass
#   to `hcloud server create --user-data-from-file`.
#
# WHAT IT CHECKS (pure static text, NO network, NO writes)
#   FAIL  root SSH not disabled   (need PermitRootLogin no OR disable_root: true)
#   FAIL  password auth not off   (need PasswordAuthentication no OR ssh_pwauth: false)
#   FAIL  no SSH key present       (need ssh_authorized_keys / ssh-ed25519 / ssh-rsa)
#   WARN  no firewall step         (ufw / nftables / hcloud firewall referenced)
#   WARN  fail2ban absent
#
# GUARANTEES
#   - Read-only and idempotent: never writes, never calls the network.
#   - Exits 0 on an empty/clean target (no files found = nothing to fail).
#   - Portable to stock macOS bash 3.2 (no mapfile, no associative arrays).
#
# EXIT CODES
#   0  No FAILs (warnings are fine; no files found is fine).
#   1  At least one FAIL in at least one scanned file.
# ============================================================================

if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
  RED="" ; YEL="" ; GRN="" ; RST=""
else
  RED=$'\033[31m' ; YEL=$'\033[33m' ; GRN=$'\033[32m' ; RST=$'\033[0m'
fi

fail()  { printf '%s  FAIL%s %s\n' "$RED" "$RST" "$1" ; }
warn()  { printf '%s  WARN%s %s\n' "$YEL" "$RST" "$1" ; }
okmsg() { printf '%s  ok%s   %s\n' "$GRN" "$RST" "$1" ; }

# --- collect target files ---
TARGETS=""
if [ "$#" -gt 0 ]; then
  for f in "$@"; do
    if [ -f "$f" ]; then
      TARGETS="$TARGETS $f"
    else
      warn "argument is not a file, skipping: $f"
    fi
  done
else
  for f in cloud-init*.yaml cloud-init*.yml cloud-config*.yaml cloud-config*.yml; do
    [ -f "$f" ] && TARGETS="$TARGETS $f"
  done
fi

# Trim whitespace.
TARGETS="$(printf '%s' "$TARGETS" | sed 's/^ *//')"

if [ -z "$TARGETS" ]; then
  echo "hetzner verify: no cloud-init file found to lint — nothing to check."
  echo "Pass a path explicitly: ./verify.sh path/to/cloud-init.yaml"
  exit 0
fi

overall_fail=0

for file in $TARGETS; do
  echo "── linting: $file"
  file_fail=0

  # FAIL: root SSH must be disabled
  if grep -Eqi 'permitrootlogin[[:space:]]+no' "$file" || grep -Eqi 'disable_root:[[:space:]]*true' "$file"; then
    okmsg "root SSH disabled"
  else
    fail "root SSH not disabled — add 'PermitRootLogin no' or 'disable_root: true'"
    file_fail=1
  fi

  # FAIL: password auth must be off
  if grep -Eqi 'passwordauthentication[[:space:]]+no' "$file" || grep -Eqi 'ssh_pwauth:[[:space:]]*(false|no|0)' "$file"; then
    okmsg "password auth off"
  else
    fail "password auth not disabled — add 'PasswordAuthentication no' or 'ssh_pwauth: false'"
    file_fail=1
  fi

  # FAIL: an SSH key must be present
  if grep -Eqi 'ssh_authorized_keys|ssh-ed25519|ssh-rsa|ecdsa-sha2' "$file"; then
    okmsg "ssh key present"
  else
    fail "no SSH public key found — add it under ssh_authorized_keys"
    file_fail=1
  fi

  # WARN: a firewall step should be referenced
  if grep -Eqi 'ufw|nftables|iptables|hcloud firewall' "$file"; then
    okmsg "firewall step referenced"
  else
    warn "no firewall step (ufw/nftables/hcloud firewall) — host has no defense-in-depth layer"
  fi

  # WARN: fail2ban
  if grep -Eqi 'fail2ban' "$file"; then
    okmsg "fail2ban present"
  else
    warn "fail2ban not installed — the one exposed SSH port has no brute-force throttle"
  fi

  if [ "$file_fail" -ne 0 ]; then
    overall_fail=1
  fi
  echo ""
done

if [ "$overall_fail" -ne 0 ]; then
  echo "${RED}hetzner verify: FAIL${RST} — resolve the failures above before creating the box."
  exit 1
fi

echo "${GRN}hetzner verify: pass${RST} — hardening must-haves present."
exit 0
