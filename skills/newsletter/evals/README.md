# Evals — newsletter

These cases are read by the repo's skill-eval harness. `should_trigger` and
`should_not_trigger` check routing precision: each prompt is matched against this
skill's description versus its siblings (the `route_to` ids — `marketing`,
`email-deliverability`, `landing-copy`, `retention` — must win their cases). The
`capability` case is scored by a judge against its `must_include` rubric: it
checks that a generated first issue actually produces a truncation-fit subject +
extending preview, single-CTA emails, an in-sequence referral ask, a
click/CTOR-based success metric with an MPP caveat, a present unsubscribe line,
and that it defers DNS/auth to `email-deliverability`. Run them through the
repo's eval runner; no live ESP, sending, or network access is required.
