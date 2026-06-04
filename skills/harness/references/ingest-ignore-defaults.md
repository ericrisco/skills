# Ignore defaults — what the Auto-Ingest Sweep must never scan

The Auto-Ingest Sweep discovers un-ingested documents across the whole workspace.
`02-DOCS/.rscignore` scopes that scan so it never grabs code, build output, tooling,
the wiki's own internals, or non-document files. This is the single guardrail that
keeps "automatic, workspace-wide" from turning into "tragar lo que no toca".

`02-DOCS/.rscignore` is **tracked** (not gitignored): the team shares the same scan
boundary. Users append their own patterns freely.

## Default `02-DOCS/.rscignore`

```gitignore
# 02-DOCS/.rscignore — paths the Auto-Ingest Sweep must NEVER scan as a knowledge source.
# Tracked (the team shares it). Append your own patterns below.
node_modules/
.git/
.next/
dist/
build/
.venv/
__pycache__/
.dart_tool/
.pytest_cache/
.ruff_cache/
01-TOOLS/
02-DOCS/inbox/_processed/
02-DOCS/raw/
02-DOCS/wiki/
.DS_Store
# Only document-like files are candidates anyway — pdf, docx, doc, md, txt, csv,
# tsv, json, html, rtf, and doc-like images (png/jpg of scans). Everything else
# (code, archives, binaries, lockfiles) is ignored even outside these paths.
```

## App source dirs are ignored at scan time

Beyond the file above, the sweep adds every detected **app source directory** to the
effective ignore set: any directory carrying a manifest (`package.json`,
`pyproject.toml`, `pubspec.yaml`, `go.mod`, `Cargo.toml`) and its tree. Source code is
never a knowledge source — `02-DOCS/wiki/` is where understanding about the code lives,
written deliberately, not scraped from the repo.

## Why `02-DOCS/raw/` and `02-DOCS/wiki/` are ignored

They are *outputs* of ingestion, not inputs. Scanning them would re-ingest the wiki
into itself. `inbox/` is the only `02-DOCS/` subtree the sweep reads as a source
(plus discovered external folders).
