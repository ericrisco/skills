# Evals — medium-writing

`cases.yaml` holds the trigger and capability cases for this skill. There is no automated runner here and no `verify.sh`: the output is prose (a Medium draft), not a checkable artifact, so rigor lives in the capability eval rather than a script.

To run by hand, feed each `should_trigger` prompt to the agent and confirm it engages `medium-writing`; feed each `should_not_trigger` prompt and confirm it routes to the named sibling (`medium-publishing`, `medium-strategy`, `article-writing`, `brand-voice`) instead. For the `capability` case, give the agent the scenario draft and grade the result against every line in `must_include` — most load-bearing are the no-clickbait-gap between title and first screen, the explicit KICKER/TITLE/SUBTITLE labels, and an honest sensational-vs-strong Boost verdict.
