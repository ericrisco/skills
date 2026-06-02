# Evals — retention

These cases check three things, and can be run by the skill-eval harness or read
manually. First, that the description **triggers** on the six retention phrasings
in `should_trigger` (including the non-obvious annual→monthly-downgrade prompt and
the Catalan/Spanish ones). Second, that it stays **silent** on the four near-misses
in `should_not_trigger`, each of which should route to the named real sibling
(`customer-support`, `client-onboarding`, `unit-economics`, `pricing`). Third, that
a model following `SKILL.md` hits the `capability` rubric on the GRR-78% scenario —
flagging the GRR alarm, building a weighted health score, replacing the flat
discount with a branched save table, adding a value-first win-back, and keeping
cancel one-click reachable. No network, fixtures, or credentials are needed; this
is a process skill with no checkable artifact, so there is no `verify.sh`.
