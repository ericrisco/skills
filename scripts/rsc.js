#!/usr/bin/env node
import { loadManifest, skillsForProfile } from './lib/manifest.js';
import { detectTarget } from '../targets/index.js';
import { detectRepo } from './detect-repo.js';
import { rank } from './consult.js';
import { expandRecommends, toOutcomes, hasOutcome } from './lib/recommend.js';
import { applyInstall, listInstalled, uninstall } from './install-apply.js';
import { doctor } from './doctor.js';
import { ask, say, yes, select, pickFrom, banner } from './lib/ui.js';
import { refreshRegistry, registryStatus } from './lib/registry.js';
import { DOMAINS } from './lib/domains.js';

const argv = process.argv.slice(2);
const cmd = argv[0];

function flag(name) {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 ? (argv[i + 1] || true) : undefined;
}

async function recommendIds(query, { labeledOnly = false } = {}) {
  const m = loadManifest();
  const repo = detectRepo();
  const ranked = query ? (await rank(m, query)).map((r) => r.id) : [];
  let base = [...new Set(query ? [...ranked, ...repo] : repo)].filter((id) => id !== 'suggest');
  if (labeledOnly) base = base.filter(hasOutcome);
  base = base.slice(0, 4);
  let out = expandRecommends(m, base).filter((id) => id !== 'suggest');
  if (labeledOnly) out = out.filter(hasOutcome);
  return out.slice(0, 6);
}

// Pick skills by browsing the domains, accumulating across rounds.
async function manualSelect() {
  const chosen = new Set();
  for (;;) {
    const opts = DOMAINS.map((d, i) => ({ key: String(i), label: `${d.title} (${d.ids.length})` }));
    opts.push({ key: 'done', label: chosen.size ? `✅ Finish & install (${chosen.size} chosen)` : 'Finish without choosing anything' });
    const k = await select('\nWhich area do you want to install skills from?', opts);
    if (k === 'done' || k === null) break;
    const d = DOMAINS[parseInt(k, 10)];
    (await pickFrom(`${d.title}:`, d.ids)).forEach((id) => chosen.add(id));
    say(`   → ${chosen.size} skills chosen so far.`);
  }
  return [...chosen];
}

// Describe-your-project flow: rsc reads repo + words and proposes skills.
async function describeFlow() {
  const goal = await ask('\nTell me in one sentence what you want to build or run:\n> ');
  const ids = await recommendIds(goal, { labeledOnly: true });
  if (!ids.length) {
    say("I'm not sure. Try describing it in more detail, or pick by hand (option 3).");
    return [];
  }
  say('\nI recommend installing:');
  for (const o of toOutcomes(ids)) say(`   • ${o.label}`);
  return ids;
}

// After installing, remind the user how to actually start — per IDE — and that
// rsc keeps recommending skills as they work. The harness/SDD *init* runs INSIDE
// the assistant (with the user present), never blindly from this CLI.
function printNextSteps(target, ids) {
  const hasHarness = ids.includes('harness');
  const hasSdd = ids.includes('sdd') || ids.includes('sdd-init');
  const openLine = {
    claude: 'Open **Claude Code** in this project folder.',
    cursor: 'Open **Cursor** in this project folder.',
    codex: 'Open **Codex CLI** (it reads AGENTS.md) in this project folder.',
    gemini: 'Open **Gemini CLI** in this project folder.',
  }[target] || 'Open your assistant in this project folder.';

  say('\n────────────────────────────────────────────────────────');
  say('👉 When you start working (these steps happen in your assistant, not here):');
  let n = 1;
  say(`   ${n++}. ${openLine}`);
  if (hasHarness) {
    say(`   ${n++}. Set up the second brain — tell it:`);
    say('        "set up the harness for this project"');
    say('      → creates 01-TOOLS/ (connections) + 02-DOCS/ (wiki) + CLAUDE.md/AGENTS.md.');
  }
  if (hasSdd) {
    say(`   ${n++}. For a new feature, tell it:`);
    say('        "sdd-init"   then   "I want <your idea>"');
    say('      → walks you specify → plan → tasks → implement → verify → ship.');
  }
  say(`   ${n++}. From there, work in your own words. orient + suggest stay always-on:`);
  say('      they keep you oriented after each step and propose the missing skill (you confirm, it installs).');
  say('\n   Add something by hand anytime:    npx @ericrisco/rsc add <skill>');
  say('   Browse the catalog / get picks:   npx @ericrisco/rsc consult "whatever you need"');
  say('────────────────────────────────────────────────────────');
}

async function wizard() {
  const m = loadManifest();
  banner();
  say('  the skill catalog for your assistant (Claude Code · Cursor · Codex · Gemini)\n');
  const choice = await select('What do you want to do?', [
    { key: 'base', label: 'Base install — the essentials (orient + suggest + harness + init)' },
    { key: 'sdd', label: 'Base + Spec-Driven Development — the specify → plan → implement → ship flow' },
    { key: 'manual', label: 'Pick skills by hand, by area' },
    { key: 'describe', label: 'Describe my project and let rsc choose' },
  ]);

  let ids = [];
  if (choice === 'base') ids = skillsForProfile(m, 'minimal');
  else if (choice === 'sdd') ids = skillsForProfile(m, 'core');
  else if (choice === 'manual') ids = await manualSelect();
  else if (choice === 'describe') ids = await describeFlow();
  else { say("Didn't catch that. Run again: npx @ericrisco/rsc"); return; }

  // The floor is always installed: the compass + the detector.
  ids = [...new Set(['orient', 'suggest', ...ids])];
  if (ids.length <= 2 && choice !== 'base') {
    say('\nNo skills were chosen. Anytime: npx @ericrisco/rsc');
    return;
  }

  const target = detectTarget();
  say(`\nI'll install ${ids.length} skills into ${target}:`);
  say('   ' + ids.join(', '));
  if (!yes(await ask('\nInstall it? (yes / no) > '))) {
    say('No problem. Anytime: npx @ericrisco/rsc');
    return;
  }
  await applyInstall({ skillIds: ids, target });
  say(`\n✅ Installed ${ids.length} skills into ${target}.`);
  printNextSteps(target, ids);
}

async function main() {
  const target = flag('target') || detectTarget();
  switch (cmd) {
    case undefined:
      return wizard();
    case 'add':
      await applyInstall({ skillIds: [...new Set(['orient', 'suggest', ...argv.slice(1)])], target });
      return void say(`✅ Installed: ${argv.slice(1).join(', ')}`);
    case 'install': {
      const profile = flag('profile') || 'minimal';
      const without = argv.filter((a, i) => argv[i - 1] === '--without');
      let ids = skillsForProfile(loadManifest(), profile);
      ids = [...new Set(['orient', 'suggest', ...ids])].filter((id) => !without.includes(id));
      await applyInstall({ skillIds: ids, target });
      return void say(`✅ Profile '${profile}' installed into ${target} (${ids.length} skills)`);
    }
    case 'consult': {
      const ids = await recommendIds(argv.slice(1).join(' '));
      if (!ids.length) return void say('(no recommendations)');
      for (const o of toOutcomes(ids)) say(`${o.id}\t${o.label}`);
      return;
    }
    case 'list':
      return void say(listInstalled({ target }).join('\n') || '(nothing installed)');
    case 'doctor':
      return void say(JSON.stringify(doctor({ target }), null, 2));
    case 'registry': {
      const sub = argv[1];
      if (sub === 'refresh') {
        const registry = refreshRegistry({ target });
        say(`✅ Registry updated: .rsc/skill-registry.md (${registry.counts.skills} skills)`);
        return;
      }
      if (sub === 'status') {
        say(JSON.stringify(registryStatus(), null, 2));
        return;
      }
      say('Use: npx @ericrisco/rsc registry refresh | registry status');
      return;
    }
    case 'uninstall': {
      const dry = argv.includes('--dry-run');
      const ids = argv.slice(1).filter((a) => !a.startsWith('--'));
      const removed = await uninstall({ skillIds: ids, target, dryRun: dry });
      return void say((dry ? 'Would remove:\n' : 'Removed:\n') + (removed.join('\n') || '(nothing)'));
    }
    default:
      say(`rsc: unknown command '${cmd}'.`);
      say('Use: npx @ericrisco/rsc | add <id...> | install --profile <p> | consult "<text>" | list | registry refresh | doctor | uninstall <id>');
  }
}

main().catch((e) => {
  console.error('rsc error:', e.message);
  process.exit(1);
});
