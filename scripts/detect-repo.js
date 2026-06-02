import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

export function detectRepo(dir = process.cwd()) {
  const found = new Set();
  const has = (f) => existsSync(join(dir, f));
  const pkg = has('package.json') ? safeJson(join(dir, 'package.json')) : null;
  if (pkg) {
    const deps = { ...pkg.dependencies, ...pkg.devDependencies };
    if (deps.next || deps.react) { found.add('nextjs'); found.add('design'); }
  }
  if (has('pubspec.yaml')) { found.add('flutter'); found.add('design'); }
  if (has('requirements.txt') || has('pyproject.toml')) found.add('fastapi');
  if (has('go.mod')) found.add('go');
  if (has('prisma') || has('migrations') || readdirSafe(dir).some((f) => f.endsWith('.sql'))) found.add('postgresdb');
  if (has('Dockerfile') || has('compose.yaml') || has('.github')) found.add('deployment');
  return [...found];
}

function safeJson(p) {
  try { return JSON.parse(readFileSync(p, 'utf8')); } catch { return {}; }
}

function readdirSafe(d) {
  try { return readdirSync(d); } catch { return []; }
}
