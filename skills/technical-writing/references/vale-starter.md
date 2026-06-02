# Vale starter — lint prose in CI

Vale (vale.sh) is the de-facto open-source prose linter. It reads a config at
the repo root, applies styles, and exits non-zero on violations so it can gate
a PR. Used in production by GitLab, Datadog, and ING (accessed 2026-06-02).
Use these files to add a blocking prose check to a docs-as-code repo.

## `.vale.ini` (repo root)

```ini
StylesPath = .github/vale/styles
MinAlertLevel = error

# Lint Markdown and reStructuredText prose.
[*.{md,rst}]
BasedOnStyles = Acme
```

## Custom style: banned terms

Create `.github/vale/styles/Acme/Weasel.yml`:

```yaml
extends: existence
message: "Avoid '%s' — it lies about difficulty and adds no information."
level: error
ignorecase: true
tokens:
  - simply
  - just
  - easy
  - easily
  - effortless(ly)?
  - seamless(ly)?
  - blazing[- ]fast
  - supercharge
```

And `.github/vale/styles/Acme/Substitutions.yml` for preferred terms:

```yaml
extends: substitution
message: "Use '%s' instead of '%s'."
level: error
ignorecase: true
swap:
  in order to: to
  leverage: use
  utilize: use
  log in: sign in
  login: sign in
```

## GitHub Actions: blocking check

Create `.github/workflows/vale.yml`. It fails the PR when prose violates the
style, so docs cannot merge with banned terms.

```yaml
name: vale
on:
  pull_request:
    paths:
      - "**/*.md"
      - "**/*.rst"
jobs:
  prose:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: errata-ai/vale-action@reviewdog
        with:
          fail_on_error: true
          filter_mode: nofilter
```

`fail_on_error: true` makes the job exit non-zero on any error-level alert, so
it blocks the merge. `filter_mode: nofilter` lints the whole changed file, not
only added lines.

## Also check links and samples

Prose lint is half the job. Add to CI (writethedocs.org/guide/tools/testing):

- **Link check** — e.g. `lychee` over the docs tree, fail on dead links.
- **Sample execution** — extract fenced code and run it, or keep samples in a
  tested examples dir and embed them, so a broken command fails the build.

The local equivalent of this gate is `scripts/verify.sh`, which greps the same
banlist without needing Vale installed.
