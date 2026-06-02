# Evals — youtube-thumbnails

These cases are LLM-graded against the rubric in `cases.yaml`, run through the
repo's standard eval runner. `should_trigger` and `should_not_trigger` check
routing — does the skill fire on real thumbnail/A-B work and stay quiet when the
request belongs to a sibling (packaging, strategy, ideation, the API, ab-testing,
or brand-identity)? `capability` checks the end-to-end behavior on the PC-build
scenario: one-axis variants, the hard image constraints, correct Test & Compare
setup (watch-time-share, not CTR), and a logged wiki row with the next-concept
rule. No live YouTube account or Data API access is needed — grading is on the
agent's plan and outputs, not on real uploads.
