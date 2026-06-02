# Lesson routing catalogue

The body table covers routine cases. This is the exhaustive catalogue: every
lesson archetype, its canonical durable home, the exact path, and the hand-off
recipe (who edits, what the verify is). Read it when the home or the hand-off
is unobvious.

## Archetype → home → hand-off

### About the user
- **Looks like:** "I prefer X", "I always want Y", "stop asking me Z", a working
  style you inferred from repeated corrections.
- **Home:** `02-DOCS/wiki/harness/user-profile.md` (the living portrait).
- **Who writes:** this skill, directly.
- **Verify:** the next pass reads the profile and the behaviour changes. Confirm
  the line is in the profile, not just the chat.

### A rule we keep breaking (workspace-wide)
- **Looks like:** "never commit to main", "always use absolute paths", "don't
  touch `.env`".
- **Home:** a rule under the relevant heading in the root `CLAUDE.md`.
- **Who writes:** this skill (CLAUDE.md is harness-owned plain text, not skill
  craft).
- **Verify:** the rule is phrased as an imperative the agent can act on, and a
  later pass that reads `CLAUDE.md` would catch the regression.

### A rule that belongs to one skill
- **Looks like:** "the deploy skill should always run a smoke check first".
- **Home:** the owning skill's `SKILL.md` body (a rule line) and, if it bans a
  pattern, a `should_not_trigger` or a `verify.sh` check.
- **Who writes:** **`author-skill`** — you decide the rule belongs there and
  hand over the edit. Do not edit the body yourself.
- **Verify:** the rule appears in the body *and* an eval/check exists that fails
  on the old behaviour.

### A pattern to ban (code/config/copy)
- **Looks like:** "never use `cd` in compound bash commands", "no `console.log`
  in committed code", "ban the phrase 'leverage synergies'".
- **Home:** a banlist/grep check in the owning skill's `scripts/verify.sh`.
- **Who writes:** `author-skill`.
- **Verify:** `verify.sh` exits non-zero on a file containing the banned
  pattern, and exits 0 on a clean target.

### A missed-trigger insight
- **Looks like:** "the skill fired on a prompt it should have routed elsewhere",
  "it failed to fire on this obvious phrasing".
- **Home:** a `should_not_trigger` (with `route_to`) or `should_trigger` case in
  the skill's `evals/cases.yaml`.
- **Who writes:** `author-skill`.
- **Verify:** the new case encodes the exact prompt that misfired.

### A surprising fact / how a provider behaves
- **Looks like:** "Stripe webhooks retry with exponential backoff for 3 days",
  "this API rate-limits per-IP not per-key".
- **Home:** a wiki article via the harness ingest protocol, linked from the
  `## Knowledge map`.
- **Who writes:** `harness`.
- **Verify:** the article exists and the Knowledge map links it, so the next
  skill working in that area reads it.

### A forward choice that surfaced mid-retro
- **Looks like:** the retro reveals you now need to *choose* something going
  forward (architecture, vendor, approach).
- **Home:** `02-DOCS/wiki/harness/decisions.md` as a decision record.
- **Who writes:** `decision-records`. Punt cleanly — do not log a choice as a
  lesson.

### A one-off, low-stakes note
- **Looks like:** a small observation with no recurrence risk and no class to
  kill.
- **Home:** an append to `02-DOCS/wiki/harness/decisions.md`, or a topic note in
  the wiki.
- **Who writes:** this skill.
- **Verify:** lightweight — the note is durable and dated. If the same note
  recurs, escalate it via the 2+-recurrences rule to a guardrail.

## Worked example — the recurring `cd` mistake

Trigger: "You keep running `cd somedir && cmd` in bash and it triggers a
permission prompt every time. I've corrected this three times."

1. **Harvest** — the lesson: compound `cd` in bash breaks the sandbox; use
   absolute paths instead.
2. **Root-cause, blameless** — *system* gap: no workspace rule forbids `cd` in
   compound commands. Not "the agent is sloppy".
3. **Route** — three sightings ⇒ structural fix, not a note. Two homes:
   - a rule in root `CLAUDE.md`: "Never `cd` in a compound bash command; use
     absolute paths." → written by this skill.
   - optionally, a grep check in the owning tooling skill's `verify.sh` that
     flags `cd .* &&` in committed scripts. → handed to `author-skill`.
4. **Write** — land both, in the lesson entry format, with the durable home and
   the "fires next time" line filled.
5. **Verify it fires** — the `CLAUDE.md` rule is read on the next pass; the
   `verify.sh` grep fails on a script containing `cd foo && bar` and passes on a
   clean one. Now it is captured.

Lesson entry that results:

```md
## 2026-06-02 — No `cd` in compound bash commands
- **Situation:** writing or running bash that changes directory then runs a command
- **We believed:** `cd dir && cmd` is harmless shorthand
- **Actually:** it trips the sandbox permission prompt every time; absolute paths don't
- **Durable home:** root `CLAUDE.md` rule + grep check in the tooling skill's verify.sh
- **Fires next time via:** CLAUDE.md rule read each pass; verify.sh fails on `cd .* &&`
```
