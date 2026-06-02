#!/usr/bin/env node
import { loadManifest, skillsForProfile } from './lib/manifest.js';
import { detectTarget } from '../targets/index.js';
import { detectRepo } from './detect-repo.js';
import { rank } from './consult.js';
import { expandRecommends, toOutcomes, hasOutcome } from './lib/recommend.js';
import { applyInstall, listInstalled, uninstall } from './install-apply.js';
import { doctor } from './doctor.js';
import { ask, say, yes } from './lib/ui.js';
import { refreshRegistry, registryStatus } from './lib/registry.js';

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

async function wizard() {
  say('Hola 👋 ¿Qué quieres hacer?');
  const goal = await ask('> ');
  const ids = await recommendIds(goal, { labeledOnly: true });
  if (!ids.length) {
    say('No estoy seguro de qué necesitas. Prueba a describir tu proyecto con más detalle.');
    return;
  }
  say('\nHe preparado esto para ti:');
  for (const o of toOutcomes(ids)) say(`   • ${o.label}`);
  const ok = yes(await ask('\n¿Lo monto? (sí / no) > '));
  if (!ok) {
    say('Sin problema. Cuando quieras: npx rsc');
    return;
  }
  const target = detectTarget();
  await applyInstall({ skillIds: [...new Set(['suggest', ...ids])], target });
  say('\n✅ Listo. Abre tu editor y empieza a pedir cosas en tu idioma.');
  say('   💡 Para añadir más cuando lo necesites, vuelve a escribir: npx rsc');
}

async function main() {
  const target = flag('target') || detectTarget();
  switch (cmd) {
    case undefined:
      return wizard();
    case 'add':
      await applyInstall({ skillIds: [...new Set(['suggest', ...argv.slice(1)])], target });
      return void say(`✅ Instalado: ${argv.slice(1).join(', ')}`);
    case 'install': {
      const profile = flag('profile') || 'minimal';
      const without = argv.filter((a, i) => argv[i - 1] === '--without');
      let ids = skillsForProfile(loadManifest(), profile);
      ids = [...new Set(['suggest', ...ids])].filter((id) => !without.includes(id));
      await applyInstall({ skillIds: ids, target });
      return void say(`✅ Perfil '${profile}' instalado en ${target} (${ids.length} skills)`);
    }
    case 'consult': {
      const ids = await recommendIds(argv.slice(1).join(' '));
      if (!ids.length) return void say('(sin recomendaciones)');
      for (const o of toOutcomes(ids)) say(`${o.id}\t${o.label}`);
      return;
    }
    case 'list':
      return void say(listInstalled({ target }).join('\n') || '(nada instalado)');
    case 'doctor':
      return void say(JSON.stringify(doctor({ target }), null, 2));
    case 'registry': {
      const sub = argv[1];
      if (sub === 'refresh') {
        const registry = refreshRegistry({ target });
        say(`✅ Registry actualizado: .rsc/skill-registry.md (${registry.counts.skills} skills)`);
        return;
      }
      if (sub === 'status') {
        say(JSON.stringify(registryStatus(), null, 2));
        return;
      }
      say('Usa: npx rsc registry refresh | registry status');
      return;
    }
    case 'uninstall': {
      const dry = argv.includes('--dry-run');
      const ids = argv.slice(1).filter((a) => !a.startsWith('--'));
      const removed = await uninstall({ skillIds: ids, target, dryRun: dry });
      return void say((dry ? 'Se borraría:\n' : 'Borrado:\n') + (removed.join('\n') || '(nada)'));
    }
    default:
      say(`rsc: comando desconocido '${cmd}'.`);
      say('Usa: npx rsc | add <id...> | install --profile <p> | consult "<texto>" | list | registry refresh | doctor | uninstall <id>');
  }
}

main().catch((e) => {
  console.error('rsc error:', e.message);
  process.exit(1);
});
