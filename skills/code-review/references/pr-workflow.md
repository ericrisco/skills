# PR review workflow — `gh` mechanics

Tooling depth for fetching a diff and posting review feedback end to end. Nothing here is posted or applied unless the user passed `--comment` or `--fix`. The body's pass order and confidence floor still govern *what* you report; this file is only *how*.

## Fetch the diff

```bash
# By PR number in the current repo
gh pr diff 1432
gh pr view 1432 --json title,body,files,additions,deletions,baseRefName,headRefName

# A PR in another repo (e.g. an OSS contribution you're reviewing)
gh pr diff 1432 --repo owner/name

# Fork PRs: the head branch lives on the contributor's fork. `gh pr diff`
# resolves it for you — no manual remote add needed. To check out locally:
gh pr checkout 1432

# A local branch with no PR yet
git diff main...HEAD          # everything since the branch diverged
git diff --stat main...HEAD   # blast radius first
```

Read the whole touched file, not just the hunk. `gh pr diff` shows only changed lines; open the file when a hunk's correctness depends on surrounding code.

## Post the verdict (summary review)

```bash
gh pr review 1432 --request-changes -b "CHANGES REQUESTED — 1 blocker, 2 should-fix. See inline."
gh pr review 1432 --approve        -b "APPROVE — correctness, contracts and security boundary clean."
gh pr review 1432 --comment        -b "APPROVE WITH NITS — non-blocking; see inline nits."
```

Pick exactly one of `--approve` / `--request-changes` / `--comment` to match the body's verdict. Note: you cannot `--approve` your own PR; on your own branch use `--comment`.

## Post inline line-anchored comments

Inline (line-anchored) comments beat PR-level prose for actionable feedback — they land on the exact line. The GitHub REST API takes one comment per call:

```bash
gh api repos/{owner}/{repo}/pulls/1432/comments \
  -f body='[should-fix] re-implements `cart.compute_subtotal()` and drops per-item discounts. Call the helper instead.' \
  -f commit_id="$(gh pr view 1432 --json headRefOid -q .headRefOid)" \
  -f path='api/orders.py' \
  -F line=88 \
  -f side='RIGHT'
```

- `path` is the file path as it appears in the diff.
- `line` is the line number in the file at `commit_id`.
- `side`: `RIGHT` for the new version (additions/context), `LEFT` for the old.
- Multi-line span: add `-F start_line=85 -f start_side='RIGHT'`.

To batch several inline comments into one pending review with a single verdict, use `POST /pulls/{n}/reviews` with a `comments[]` array and an `event` of `REQUEST_CHANGES` / `APPROVE` / `COMMENT` — see the GitHub "Create a review for a pull request" API. Otherwise individual `pulls/{n}/comments` calls post immediately and unbatched.

## Large-diff strategy

When the diff is too big to hold in one pass:

1. `git diff --stat` (or the `files` array from `gh pr view`) to rank files by churn.
2. Review by file or by commit (`gh pr diff` per commit SHA), hot paths first — auth, money, data migrations, anything user-input-facing.
3. Generated/vendored files (lockfiles, snapshots, `dist/`) get a structural skim for surprises, not a line-by-line read.
4. Carry findings across files: a contract change in one file is only a finding if a caller in another file breaks — confirm the caller.

## Read-only default

The review itself touches nothing. Posting (`--comment`) and editing (`--fix`) are explicit opt-ins. With `--fix`, branch first if you are on the default branch, apply only the agreed findings, and commit/push only when the user asks. Git authorship is Eric — no Claude co-author or generated footer on any commit or PR body.
