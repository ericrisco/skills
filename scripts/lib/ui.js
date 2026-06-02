import { createInterface } from 'node:readline/promises';
import { emitKeypressEvents } from 'node:readline';
import { stdin, stdout } from 'node:process';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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
  return /^(s|si|sí|y|yes|ok|sure|yeah)/i.test(s.trim());
}

// ---------------------------------------------------------------------------
// Interactive arrow-key / space TUI (zero dependencies).
// Falls back to a typed-number prompt when there is no interactive TTY
// (CI, pipes, dumb terminals) so scripts and tests never hang.
// ---------------------------------------------------------------------------

function interactive() {
  return Boolean(stdin.isTTY && stdout.isTTY);
}

const C = {
  dim: (s) => `\x1b[2m${s}\x1b[22m`,
  bold: (s) => `\x1b[1m${s}\x1b[22m`,
  cyan: (s) => `\x1b[36m${s}\x1b[39m`,
  green: (s) => `\x1b[32m${s}\x1b[39m`,
};

const ART = [
  ' ██████╗ ███████╗ ██████╗',
  ' ██╔══██╗██╔════╝██╔════╝',
  ' ██████╔╝███████╗██║     ',
  ' ██╔══██╗╚════██║██║     ',
  ' ██║  ██║███████║╚██████╗',
  ' ╚═╝  ╚═╝╚══════╝ ╚═════╝',
];

// Vertical truecolor gradient (sky → violet), phase-shiftable for the wave.
function gradientLine(text, row, phase) {
  const a = [56, 189, 248]; const b = [167, 139, 250];
  const t = ((row + phase) % ART.length) / (ART.length - 1);
  const r = Math.round(a[0] + (b[0] - a[0]) * t);
  const g = Math.round(a[1] + (b[1] - a[1]) * t);
  const bl = Math.round(a[2] + (b[2] - a[2]) * t);
  return `\x1b[38;2;${r};${g};${bl}m${text}\x1b[39m`;
}

// Animated ASCII wordmark — the "wooow". Static plain text when not a TTY.
export async function banner() {
  if (!stdout.isTTY) {
    say('');
    for (const l of ART) say(l);
    say('  231 skills · one CLI · zero bloat');
    return;
  }
  stdout.write('\x1b[?25l'); // hide cursor
  say('');
  // 1) reveal top-down
  for (let i = 0; i < ART.length; i++) {
    say(gradientLine(ART[i], i, 0));
    await sleep(55);
  }
  // 2) flowing color wave through the wordmark
  for (let phase = 1; phase <= ART.length; phase++) {
    stdout.write(`\x1b[${ART.length}A`);
    stdout.write(ART.map((l, i) => `\x1b[2K${gradientLine(l, i, phase)}`).join('\n') + '\n');
    await sleep(60);
  }
  say(C.dim('  231 skills · one CLI · zero bloat'));
  stdout.write('\x1b[?25h'); // show cursor
}

// Repaint a fixed block of lines in place (cursor ends just below the block).
function makePainter() {
  let height = 0;
  return (lines) => {
    if (height) stdout.write(`\x1b[${height}A`);
    stdout.write(lines.map((l) => `\x1b[2K${l}`).join('\n') + '\n');
    height = lines.length;
  };
}

function captureKeys(onKey) {
  emitKeypressEvents(stdin);
  if (stdin.isTTY) stdin.setRawMode(true);
  stdin.resume();
  const handler = (str, key) => onKey(str, key || {});
  stdin.on('keypress', handler);
  return () => {
    stdin.off('keypress', handler);
    if (stdin.isTTY) stdin.setRawMode(false);
    stdin.pause();
  };
}

// Single choice: ↑↓ to move, Enter to pick. options: [{ key, label }].
function tuiSelect(question, options) {
  return new Promise((resolve) => {
    let i = 0;
    const paint = makePainter();
    const render = () => paint([
      C.bold(question),
      C.dim('  ↑↓ move · enter select'),
      ...options.map((o, idx) =>
        idx === i ? `${C.cyan('❯')} ${C.cyan(o.label)}` : `  ${o.label}`),
    ]);
    render();
    const stop = captureKeys((str, key) => {
      if (key.name === 'up' || key.name === 'k') { i = (i - 1 + options.length) % options.length; render(); }
      else if (key.name === 'down' || key.name === 'j') { i = (i + 1) % options.length; render(); }
      else if (key.name === 'return') { stop(); resolve(options[i].key); }
      else if (key.name === 'escape' || (key.ctrl && key.name === 'c')) { stop(); stdout.write('\n'); process.exit(130); }
    });
  });
}

// Multi-select: ↑↓ move, space toggle, a = all, enter confirm. Viewport scrolls.
function tuiChecklist(title, items) {
  return new Promise((resolve) => {
    const VISIBLE = Math.min(items.length, 12);
    const sel = new Set();
    let cur = 0; let top = 0;
    const paint = makePainter();
    const render = () => {
      if (cur < top) top = cur;
      if (cur >= top + VISIBLE) top = cur - VISIBLE + 1;
      const rows = [];
      for (let r = top; r < top + VISIBLE; r++) {
        const it = items[r];
        const box = sel.has(r) ? C.green('◉') : '◯';
        const line = `${box} ${it.label}`;
        rows.push(r === cur ? `${C.cyan('❯')} ${C.cyan(line)}` : `  ${line}`);
      }
      const more = items.length > VISIBLE ? C.dim(`  (${cur + 1}/${items.length})`) : '';
      paint([
        C.bold(title),
        C.dim('  ↑↓ move · space toggle · a all · enter confirm') + more,
        ...rows,
      ]);
    };
    render();
    const stop = captureKeys((str, key) => {
      if (key.name === 'up' || key.name === 'k') { cur = (cur - 1 + items.length) % items.length; render(); }
      else if (key.name === 'down' || key.name === 'j') { cur = (cur + 1) % items.length; render(); }
      else if (key.name === 'space') { sel.has(cur) ? sel.delete(cur) : sel.add(cur); render(); }
      else if (str === 'a') { if (sel.size === items.length) sel.clear(); else items.forEach((_, idx) => sel.add(idx)); render(); }
      else if (key.name === 'return') { stop(); resolve([...sel].sort((x, y) => x - y).map((idx) => items[idx].id)); }
      else if (key.name === 'escape' || (key.ctrl && key.name === 'c')) { stop(); stdout.write('\n'); process.exit(130); }
    });
  });
}

// Public: single-choice menu. options: [{ key, label }]. Returns the chosen key.
export async function select(question, options) {
  if (interactive()) return tuiSelect(question, options);
  // Fallback: typed number.
  say(question);
  options.forEach((o, i) => say(`  ${i + 1}) ${o.label}`));
  const a = (await ask('> ')).toLowerCase();
  const n = parseInt(a, 10);
  if (n >= 1 && n <= options.length) return options[n - 1].key;
  const byKey = options.find((o) => o.key.toLowerCase() === a);
  return byKey ? byKey.key : null;
}

// Public: yes/no confirmation. Arrow TUI when interactive, typed prompt otherwise.
export async function confirm(question) {
  if (interactive()) {
    const k = await tuiSelect(question, [
      { key: 'yes', label: 'Yes, install it' },
      { key: 'no', label: 'No, cancel' },
    ]);
    return k === 'yes';
  }
  return yes(await ask(`${question} (yes / no) > `));
}

// Public: multi-select. items: array of strings or { id, label }. Returns ids.
export async function pickFrom(title, items) {
  const norm = items.map((it) => (typeof it === 'string' ? { id: it, label: it } : it));
  if (interactive()) return tuiChecklist(title, norm);
  // Fallback: comma-separated numbers.
  say(`\n${title}`);
  norm.forEach((it, i) => say(`  ${String(i + 1).padStart(2)}) ${it.label}`));
  say('   Comma-separated numbers (e.g. 1,3,4), "all", or Enter for none.');
  const a = (await ask('> ')).trim();
  if (!a) return [];
  if (/^(all|todo|todas)$/i.test(a)) return norm.map((it) => it.id);
  return [...new Set(
    a.split(',').map((s) => parseInt(s.trim(), 10)).filter((x) => x >= 1 && x <= norm.length).map((x) => norm[x - 1].id),
  )];
}
