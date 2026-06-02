---
description: Two-layer security scan — automated scanners (gitleaks/semgrep/CVE audit) plus the security-reviewer agent's manual pass — aggregated into one ranked, confidence-filtered report.
argument-hint: "[path | blank for changed files]"
---

# /security-scan — scan, then judge

One rule: **machines find the obvious, the agent finds the reachable, you ship one report.** Run the automated gate AND the manual review over the *same* surface, then merge into a single exploitability-ranked verdict. Never paste two disjoint tool dumps — that's noise, not a review.

Posture inherited from `/rsc-ops:secure-coding`: read-only, exploitability over theory, every finding ships a fix. Rank like a bounty triager — reachable + user-controlled + meaningful sink comes first.

## 1. GATHER the surface

`$ARGUMENTS` decides what gets scanned:

- **A path given** (`src/api`, a file, a glob) → that's the surface. Scope the whole review to it.
- **Blank** → the changed files. Resolve them in this order, stop at the first that yields a non-empty set:

```bash
git diff --name-only --diff-filter=ACMR HEAD          # unstaged + uncommitted vs HEAD
git diff --name-only --diff-filter=ACMR --staged       # staged only
git diff --name-only --diff-filter=ACMR main...HEAD    # branch vs main (PR-shaped)
```

Drop deletions, lockfile-only churn, and generated/vendored paths (`node_modules/`, `dist/`, `.next/`, `*.lock`). Keep the list — it's the lens for BOTH layers below. If the set is empty, say "no changed files to scan" and stop; do not scan the whole tree by default.

State the surface back before scanning: *"Scanning N files under <path|diff>."*

## 2. Automated layer — the scanners that already exist

Do **not** reinvent secret/SAST/CVE scanning. The `/rsc-ops:secure-coding` skill ships the gate. Invoke it as the automated pass:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/../rsc-ops/skills/secure-coding/scripts/verify.sh"
```

If that path isn't resolvable (skill installed elsewhere / standalone), locate it: `find ~/.claude -path '*secure-coding/scripts/verify.sh' 2>/dev/null | head -1`. Run it **from the target repo root** — it auto-detects the stack and runs, skipping (never failing) any missing tool:

| Layer | Tool | Gate |
|---|---|---|
| Secrets | `gitleaks` (working tree + history) | any hit = CRITICAL, rotate first |
| SAST | `semgrep` ERROR rules | ERROR gates; WARNING informational |
| Python CVEs | `pip-audit` | reachable high/critical |
| Node CVEs | `osv-scanner` / `npm` / `pnpm` audit | high+ |
| Go CVEs | `govulncheck` | reachable only |

Enable network SAST rules with `SECURE_CODING_SEMGREP_AUTO=1` when no local semgrep config exists. Capture stdout/stderr and the exit code — exit 1 means real high/critical findings the agent must not silently drop. A `[skip]` line is a coverage gap, not a pass: note which tools were missing so the report doesn't over-claim a clean bill.

## 3. Manual layer — DISPATCH the security-reviewer agent

Scanners miss the bugs that matter most: IDOR/broken access control, authz-on-the-wrong-layer, SSRF behind a helper, logic flaws, missing ownership scoping — the lethal-trifecta crossings. Dispatch the **security-reviewer** subagent over the exact same surface:

> Review these files for security vulnerabilities, exploitability first: `<file list from step 1>`.
> Ground yourself in the OWASP-by-stack and trust-boundary model from the secure-coding skill. For every finding return: severity (CRITICAL/HIGH/MEDIUM/LOW), `file:line`, one-line description, a stack-correct **fix** (vulnerable→fixed diff, copy-pasteable), and a **confidence 0–100**. Trace each to a reachable, user-controlled sink — flag IDOR, missing server-side authz, injection, SSRF, secret handling, unsafe deserialization, XSS via `dangerouslySetInnerHTML`. Skip style and theory. Zero findings is a valid, welcome result.

If no `security-reviewer` agent is registered in this environment, fall back to running the `/rsc-ops:secure-coding` skill's review workflow inline over the same file list — the manual layer is non-negotiable, only its executor is swappable.

## 4. AGGREGATE — one ranked report

Merge both layers into a single list. **De-duplicate**: when a scanner and the agent flag the same `file:line`, keep one entry and note both sources — corroboration *raises* confidence, it doesn't double-count. **Confidence-filter at >80%**: drop anything the agent scored ≤80 (a scanner ERROR/secret hit is ≥80 by definition — tools don't speculate). Then sort strictly CRITICAL → HIGH → MEDIUM → LOW; within a severity, higher confidence first.

```
## Security scan — <surface>
Automated: gitleaks ✓  semgrep ✓  <stack> CVEs ✓   (skipped: <none|tools>)
Manual: security-reviewer over N files

### CRITICAL
- [conf 95] app/api/docs/[id]/route.ts:14 — IDOR: doc fetched by id with no ownership scope; any authed user reads any doc.
  fix: scope the query to the session user and 404 on miss —
    `where: { id, ownerId: session.user.id }` … `if (!doc) notFound()`
  source: security-reviewer (corroborated: semgrep nextjs-missing-authz)

### HIGH
- [conf 88] src/fetch.py:42 — SSRF: user URL fetched directly; no scheme/IP allowlist.
  fix: https-only + block private ranges (169.254.169.254, 10/8, 172.16/12, 192.168/16, 127/8, ::1) + pin the dialed IP.
  source: security-reviewer

### MEDIUM / LOW
- … (same shape)

### Verdict
BLOCK — 1 CRITICAL, 1 HIGH must be fixed before merge.   (or: PASS — no findings >80% confidence; <tools skipped>.)
```

Verdict rules:

- **BLOCK** — any CRITICAL or HIGH survives the filter, or `verify.sh` exited non-zero.
- **PASS** — zero findings above the bar **and** the gate exited 0. State plainly: *"No findings above 80% confidence; <skipped tools, if any>."* A clean report is the goal, not a failure to find work.
- Never invent findings to look thorough. Never soften a CRITICAL to pad a "balanced" list.

Then **STOP**. This command is read-only — it reports, it does not patch. Each finding already carries its fix; applying them is a separate, explicit ask (run `/rsc-ops:secure-coding` to fix, or hand the report to the implementer).

## Anti-patterns → STOP

| Rationalization | Reality |
|---|---|
| "I'll just paste the semgrep output." | That's a tool dump, not a review. Aggregate, rank, dedupe, verdict. |
| "Scan the whole repo, the diff is small." | Blank arg = changed files only. Whole-tree scans bury the diff's real risk. |
| "Low-confidence guesses make it look thorough." | >80% or it's noise. A short, true report beats a long, hedged one. |
| "verify.sh skipped semgrep, so SAST passed." | `[skip]` is a coverage gap. Report it; don't claim clean. |
| "Found nothing, something's wrong." | Zero findings on a clean diff is the correct answer. Say PASS. |
| "The agent and gitleaks both flagged it — two findings." | One finding, two sources, higher confidence. Dedupe by `file:line`. |
