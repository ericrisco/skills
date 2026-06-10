#!/usr/bin/env node
// rsc UserPromptSubmit payload (claude). Re-injects the SDD new-feature gate as the
// MOST-RECENT instruction on every user turn. The SessionStart hook already injects the
// full gate (the `suggest` body) once per session, but in a long session — or one with
// many installed skills whose descriptions crowd the context — that single injection can
// lose salience and a strongly-matched stack/builder skill can pull the model straight to
// code. This keeps the precedence rule in front of the model every turn, so the gate is
// independent of skill count and session length. Stdout is added to context for
// UserPromptSubmit, so a plain print is enough (no JSON needed).
//
// Invoked as `node userprompt-gate.mjs <projectRoot>` (not bash) so it runs on Windows too.
//   argv[2] = absolute project root
// Fail-open (never blocks a turn). Opt out per project with .rsc/.no-feature-gate.
import { existsSync } from 'node:fs';
import { join } from 'node:path';

const root = process.argv[2] || process.cwd();

// Opt-out: a project that does not want the always-on gate drops this marker file.
if (existsSync(join(root, '.rsc', '.no-feature-gate'))) process.exit(0);

process.stdout.write(`===== rsc SDD new-feature gate (highest precedence) =====
Before acting on this turn: if the user wants to BUILD, ADD, or CHANGE a feature — in
ANY language, judged by intent, not by keywords — you MUST route it through SDD via
\`specify\` FIRST. No feature code is written by ANY skill (stack skills included —
nextjs/react/fastapi/flutter/go/postgresdb/building-agents/design — and any builder skill
such as chatbot/course-builder/marketing) until a spec AND a plan exist and the user has
approved them. No skill outranks this gate.
- Unclear / in-between? -> \`specify\` (the safe default; a skipped spec is where drift hides).
- One-line / low-risk change, or a bug fix restoring intended behaviour? -> skip the chain,
  do it, and say so out loud.
Full gate + decision table live in the always-on \`suggest\` body; method in \`sdd\`.
=========================================================
`);
