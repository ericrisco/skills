import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';

export async function ask(question) {
  const rl = createInterface({ input: stdin, output: stdout });
  const a = await rl.question(question);
  rl.close();
  return a.trim();
}

export function say(...lines) {
  console.log(...lines);
}

export function yes(s) {
  return /^(s|si|sí|y|yes|ok|vale|dale)/i.test(s.trim());
}

// Numbered single-choice menu. options: [{ key, label }]. Accepts the number or
// the key typed verbatim. Returns the chosen key, or null if unrecognized.
export async function select(question, options) {
  say(question);
  options.forEach((o, i) => say(`  ${i + 1}) ${o.label}`));
  const a = (await ask('> ')).toLowerCase();
  const n = parseInt(a, 10);
  if (n >= 1 && n <= options.length) return options[n - 1].key;
  const byKey = options.find((o) => o.key.toLowerCase() === a);
  return byKey ? byKey.key : null;
}

// Numbered multi-select. items: array of strings. Accepts comma-separated
// numbers (e.g. "1,3,4"), "todo"/"all", or empty for none. Returns the subset.
export async function pickFrom(title, items) {
  say(`\n${title}`);
  items.forEach((id, i) => say(`  ${String(i + 1).padStart(2)}) ${id}`));
  say('   Comma-separated numbers (e.g. 1,3,4), "all", or Enter for none.');
  const a = (await ask('> ')).trim();
  if (!a) return [];
  if (/^(todo|todas|all)$/i.test(a)) return [...items];
  const picked = a
    .split(',')
    .map((s) => parseInt(s.trim(), 10))
    .filter((x) => x >= 1 && x <= items.length)
    .map((x) => items[x - 1]);
  return [...new Set(picked)];
}
