# skill-harden-rubric — how the fix-loop diagnoses and guards a fix

The `skill-harden` workflow turns a FAILING behavioral score into edits, without gaming the eval.
These are the rules its agents follow.

## Diagnosis (skill-fault vs eval-fault)

Given the failing `mustFix`, both A/B outputs, and the grader's per-item evidence, decide the FAULT:

- **skill** — the treatment output genuinely misses real capability (weak method, missing depth,
  no concrete output). Fix the SKILL.md body and/or references/.
- **eval** — the failure is the eval's, not the skill's. Two known biases:
  1. **Self-describing scenario** — the `scenario` text enumerates its own `must_include`, so a
     bare agent gets the same guidance the skill would give and the lift collapses artificially.
  2. **Phantom-context must_include** — an item demands workspace artifacts the isolated eval
     agent cannot have (e.g. `user-profile.md`, a real sibling skill to delegate to), capping the
     absolute unfairly.

Default to **skill** when unsure: blaming the eval is the easier, less honest path.

## Eval-fix guard (independent judge)

An eval edit ships ONLY if a judge certifies it corrects one of the two biases above and does NOT
lower the bar — i.e. it makes the scenario less self-describing or removes a phantom-context item,
but never deletes a legitimate quality criterion to make a weak skill pass. Rejected → treat as a
skill-fault this round.

## Skill-fix guards (both required)

1. **Diff judge.** Read the SKILL.md/references diff. Does it add genuine capability (method,
   decision rules, concrete guidance) or merely echo the `must_include` wording into the body to
   satisfy the grader? Keyword-stuffing → revert the edit; it is not a fix.
2. **Hold-out.** Re-score on a FRESH scenario from the skill's domain that the fixer never saw.
   A real improvement generalizes; a memorized one does not. The hold-out score must also improve.

## Stopping & honesty

- Max 2 rounds. On give-up, report the honest final score and a recommendation — never a faked pass.
- Persistent lift-fail at a high absolute → recommend deprecate/merge: the skill does not justify
  its own existence.
