---
name: code-review
description: "Use when you have a concrete diff, branch, or GitHub PR to judge on its own merits and there is no rsc-SDD spec/plan/constitution chain to key off — the standalone, spec-less giving pass behind the executable /code-review. Triggers: 'review this PR before I merge', 'revisa este diff', 'revísame el PR', 'què està malament en aquest canvi', 'tear apart the contractor's branch', 'is this PR safe to merge', 'is this dependency bump safe', '/code-review --comment 1432', 'high-signal review of this change'. Scales coverage by effort (low/medium = fewer high-confidence findings; high/max = broader, may surface uncertain ones labelled [question]); read-only by default, posts comments only with --comment and edits only with --fix. NOT the SDD review gate keyed to 02-DOCS/wiki/sdd/ that also processes incoming comments and pushes back (that is review)."
tags: [code-review, pr-review, quality, correctness]
recommends: [review, secure-coding, verify]
origin: risco
---

# Code review — standalone, spec-less diff judgment

You are reviewing a concrete change — a `git diff`, a branch, a GitHub PR, a pasted patch — on its own merits. No rsc-SDD spec/plan/constitution chain is required and you should not pretend one exists. This is the doctrine behind the executable `/code-review` slash command: same evidence bar, written as a discipline you run by hand.

> **The one-line disambiguator:** `review` needs `02-DOCS/wiki/sdd/` (spec + plan + constitution) and owns the *receiving* loop. `code-review` needs only the diff. If the user is mid-SDD and wants to process incoming comments, route to `../review/SKILL.md`. If they hand you a naked diff or an inbound third-party PR, this skill.

**The north star is signal-to-noise.** Report only findings you would stake your name on. A clean diff is `APPROVE`, not a manufactured nit. High-false-positive review gets tuned out by humans in about two weeks; the bar to aim for is the logic-error review where under 1% of findings come back marked wrong. Padding does not make you look thorough — it trains the reader to ignore you.

## Get the change and its intent first

Three inputs, in this order: **the diff**, **its stated purpose**, and **the touched surface** (the files around the hunks, not just the hunks).

```bash
# A GitHub PR
gh pr diff 1432
gh pr view 1432 --json title,body,files,additions,deletions

# A local branch against the trunk
git diff main...HEAD
git diff --stat main...HEAD   # see blast radius before reading

# A pasted patch — read it as given
```

A review with no notion of intent is a review of vibes. If no purpose is stated, **infer it from the diff and say what you assumed** ("Assuming this is meant to add idempotency to the webhook handler…") so the reader can correct a wrong premise. Then read the *whole* changed file, not just the green/red lines — the structural failure of standalone review is judging a hunk without its context and shipping generic pattern-matched suggestions.

## The pass order

Run these in order. Passes 1–5 are correctness/safety and are blocking-eligible; pass 6 is cleanup and is usually `[should-fix]` or `[nit]`. **A clean pass is a reportable result** ("contracts: nothing changed shape, no finding"), not a pass you silently skip.

| # | Pass | The question | Typical defects |
|---|------|--------------|-----------------|
| 1 | Intent fidelity | Does it do what it claims? | Wrong behaviour, missing case from the stated goal, scope creep |
| 2 | Correctness & boundaries | Right on the edges? | Off-by-one, null/empty/unicode, overflow, timezone, concurrency, swallowed errors |
| 3 | Contracts & data | Do callers/data still hold? | Broken API shape, migration without backfill, nullable made non-null, enum drift |
| 4 | Security boundary | Untrusted input → dangerous sink? | Unsanitized input to query/shell/template, authz gap, secret in code/log |
| 5 | Tests as evidence | Do the tests prove the change? | Tests assert nothing, test the mock, miss the new branch, were deleted to go green |
| 6 | Reuse / simplification / efficiency | Could existing code do this? | Reimplemented helper, copy-paste divergence, N+1, needless allocation in a hot loop |

Pass 4 is a **boundary** pass — trace untrusted input to its sink and flag the reachable ones. For a real STRIDE/OWASP threat model with exploitability ranking and vulnerable→fixed diffs, hand off to `../secure-coding/SKILL.md`.

## Confidence floor and the false-positive skip-list

**The 80% rule:** if you are not at least ~80% sure a finding is real, you have two moves — trace the code until you *are* sure, or downgrade it to `[question]`. Never ship a guess dressed as a defect.

Skip these common false positives outright (or demote to `[question]`/`[nit]`):

- **Guarded upstream** — the "missing" check happens in the caller you can see; trace before you flag.
- **Framework-enforced** — the framework already does it (e.g. an ORM that parameterizes, a router that validates).
- **Behind an off-everywhere flag** — real but unreachable in any deployed config → `[nit]`, not blocking.
- **Test-only / generated code held to the prod bar** — don't demand prod-grade error handling in a fixture or a generated client.
- **Style the linter owns** — quotes, import order, line length. If a tool enforces it, don't spend a finding on it.

**No severity inflation.** Rank by `blast radius × reachability`, not by how clever the catch was. A typo in a log string is a nit even if it took effort to spot.

## Severity and finding format

- `[blocking]` — wrong/unsafe; merging causes a real defect. Must be fixed.
- `[should-fix]` — a real problem with bounded blast radius; fix it or consciously accept it.
- `[nit]` — minor; the reader may ignore it without consequence.
- `[question]` — you suspect an issue but cannot prove reachability; asking, not asserting.

Every finding carries **where / why / repro / fix**:

```text
[should-fix] api/orders.py:88 — duplicated total logic
  where:  `subtotal = sum(i.price * i.qty for i in items)` re-implements
          `cart.compute_subtotal()` (cart/totals.py:14), which also applies
          per-item discounts this copy silently drops.
  why:    discounted items now bill at full price on this path only;
          the two implementations will drift on the next discount change.
  repro:  order containing any item with `discount_pct > 0` → charged the
          undiscounted amount; covered by no test.
  fix:    call `cart.compute_subtotal(items)` instead of inlining the sum.
```

**Rule: no repro or stated mechanism → it is a `[question]`, not a blocker.** "This could overflow" with no path is a question; "n*1000 with n up to 3M exceeds int32 at orders.py:51" is a finding.

## Verify before you flag

Read the surrounding code, trace the *value*, confirm the path is reachable.

- **Bad:** "Looks like SQL injection." (pattern-match)
- **Good:** "`search()` interpolates `req.query.q` straight into `db.execute(\`… WHERE name='${q}'\`)` at search.ts:22; `q` is unvalidated user input → injection." (traced)

If you cannot trace it to a concrete value and a reachable sink, you do not yet have a finding.

## The verdict

End every review with exactly one, plainly — no mushy middle:

- **APPROVE** — no blockers, no should-fix. Point the user to `../ship/SKILL.md` to merge.
- **APPROVE WITH NITS** — mergeable; nits listed but none gate the merge.
- **CHANGES REQUESTED** — at least one `[blocking]`. List precisely what unblocks it, so the author knows when they are done.

## Effort dial

Mirror the slash command's effort level: **low/medium** → fewer, high-confidence findings (raise the confidence floor, focus on passes 1–4). **high/max** → broader coverage; you may surface uncertain findings, but they must be labelled `[question]`, never inflated into blockers. This is *coverage vs precision* and is distinct from the harness L0..L3 accompaniment dial, which sets how much you narrate, not how rigorous you are.

## Emitting comments and applying fixes

**Read-only by default.** You produce findings + a verdict and stop there. Two opt-in modes:

- `--comment` → post the findings as an inline-anchored review on the PR.
- `--fix` → apply the agreed findings to the working tree.

```bash
# Summary review (the verdict)
gh pr review 1432 --request-changes -b "CHANGES REQUESTED — see inline. Blocker: orders.py:88 …"
gh pr review 1432 --approve -b "APPROVE — correctness and contracts clean."
```

Inline line-anchored comments go through the GitHub REST API — see `references/pr-workflow.md` for the JSON shape, fork-PR handling, and large-diff strategy. If `--fix` puts you on the default branch, **branch first**; commit or push **only when the user asks**; git authorship is **Eric** (no Claude co-author or generated footer).

## Anti-patterns → STOP

| Rationalization | Reality |
|---|---|
| "It compiles and the tests pass, so it's correct." | Tests prove green, not correct. Pass 5 asks whether the tests actually exercise the new branch — green for the wrong reason is a finding. |
| "I'll list everything I'd have done differently." | That is noise. Report defects and reuse wins you can defend; preference is not a finding. |
| "This looks like a bug." | Looks-like is not a finding. Trace the value to a reachable sink, or file it `[question]`. |
| "More findings = more thorough." | False positives get you tuned out in two weeks. Signal-to-noise is the metric; one real blocker beats ten nits. |
| "No PR description, so I'll guess the intent silently." | State the intent you assumed. A wrong silent premise produces a confidently wrong review. |
| "It's just a dependency bump, skim it." | Bumps carry supply-chain and transitive risk and behaviour changes. Check the changelog/lockfile diff, not just the version string. |
| "Apply every nit to be safe." | Each unrequested edit is scope creep and a regression surface. With `--fix`, apply the agreed findings only. |

## See Also

- `../review/SKILL.md` — the rsc-SDD penultimate gate keyed to `02-DOCS/wiki/sdd/`, and the *receiving* loop (process comments, push back with proof).
- `../secure-coding/SKILL.md` — deep STRIDE/OWASP threat model with vulnerable→fixed diffs; the depth pass 4 defers to.
- `../verify/SKILL.md` — run lint/type/test/`verify.sh` and prove green (code-review judges whether green is correct).
- `../debug/SKILL.md` — root-cause one confirmed failure (code-review surveys for latent ones).
- `../analyze/SKILL.md` — consistency across spec/plan/tasks *before* code exists.
- `../ship/SKILL.md` — PR/merge/close after approval; consumes this skill's verdict.
- Stack idiom for the change under review: `../nextjs/SKILL.md`, `../fastapi/SKILL.md`, `../go/SKILL.md`, `../typescript/SKILL.md`, `../python/SKILL.md`.
