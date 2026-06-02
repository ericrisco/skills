import initSqlJs from 'sql.js';

// Stopwords (es + en) — these match everywhere via LIKE and drown the signal.
const STOP = new Set([
  'una', 'un', 'unos', 'unas', 'con', 'de', 'del', 'la', 'el', 'los', 'las', 'para',
  'que', 'porque', 'en', 'mi', 'mis', 'me', 'quiero', 'tener', 'hacer', 'al', 'lo',
  'su', 'sus', 'este', 'esta', 'esto', 'como', 'mas', 'más', 'algo', 'cosa', 'cosas',
  'the', 'and', 'or', 'to', 'of', 'in', 'for', 'with', 'my', 'want', 'build', 'it',
  'need', 'have', 'make', 'create', 'add', 'new',
]);

// Spanish / colloquial terms → catalog tags. Lets non-programmers describe
// outcomes in their words and still hit the right (English-tagged) skill.
const SYNONYMS = {
  web: ['web', 'frontend'], pagina: ['web'], 'página': ['web'], landing: ['landing', 'web'],
  tienda: ['web', 'frontend'], ecommerce: ['web'], pagos: ['security', 'auth'], pago: ['security'],
  datos: ['database', 'sql'], base: ['database'], guardar: ['database'], almacenar: ['database'],
  publicar: ['deploy', 'docker'], publicarla: ['deploy'], publicarlo: ['deploy'], online: ['deploy'],
  desplegar: ['deploy'], deploy: ['deploy'], servidor: ['backend', 'deploy'],
  empresa: ['company', 'harness'], negocio: ['company', 'harness'], documentar: ['docs', 'wiki', 'harness'],
  documenta: ['docs', 'harness'], documentacion: ['docs', 'harness'], 'documentación': ['docs', 'harness'],
  conectar: ['connect', 'harness'], conecta: ['connect', 'harness'], herramientas: ['tools', 'harness'],
  procesos: ['ops', 'harness'], ops: ['ops', 'harness'], conocimiento: ['knowledge', 'wiki', 'harness'],
  app: ['mobile', 'app'], aplicacion: ['app'], 'aplicación': ['app'], movil: ['mobile'], 'móvil': ['mobile'],
  api: ['api', 'backend'], backend: ['backend'], rest: ['api'],
  seguro: ['security'], seguridad: ['security'], login: ['auth', 'security'], auth: ['auth'],
  agente: ['agents', 'ai'], agentes: ['agents'], ia: ['ai', 'agents'], llm: ['llm', 'agents'],
  presentacion: ['presentations'], 'presentación': ['presentations'], diapositivas: ['slides'],
  curso: ['course', 'teaching'], 'enseñar': ['teaching'], ensenar: ['teaching'],
  marketing: ['marketing'], copy: ['copywriting'], texto: ['copywriting'], textos: ['copywriting'],
};

function expandedTerms(query) {
  const raw = query.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, ' ').split(/\s+/)
    .filter((t) => t.length > 1 && !STOP.has(t));
  const set = new Set();
  for (const t of raw) {
    set.add(t);
    for (const syn of SYNONYMS[t] || []) set.add(syn);
  }
  return [...set];
}

export async function rank(manifest, query) {
  const terms = expandedTerms(query);
  if (!terms.length) return [];
  const SQL = await initSqlJs();
  const db = new SQL.Database();

  const rows = manifest.skills.map((sk) => [
    sk.id,
    ` ${sk.id} ${sk.description} ${(sk.tags || []).join(' ')} `.toLowerCase(),
  ]);

  // Prefer FTS5 for fidelity with ECC; fall back to scored whole-word LIKE if
  // the sql.js wasm build was compiled without the FTS5 module.
  try {
    db.run('CREATE VIRTUAL TABLE s USING fts5(id, doc);');
    const stmt = db.prepare('INSERT INTO s (id, doc) VALUES (?, ?)');
    for (const r of rows) stmt.run(r);
    stmt.free();
    const match = terms.map((t) => `"${t}"*`).join(' OR ');
    const res = db.exec('SELECT id FROM s WHERE s MATCH ? ORDER BY rank', [match]);
    db.close();
    return res.length ? res[0].values.map(([id]) => ({ id })) : [];
  } catch {
    db.run('CREATE TABLE s (id TEXT, doc TEXT);');
    const stmt = db.prepare('INSERT INTO s (id, doc) VALUES (?, ?)');
    for (const r of rows) stmt.run(r);
    stmt.free();
    // Whole-word match: pad doc with spaces and look for "% term %".
    const score = terms.map(() => '(doc LIKE ?)').join(' + ');
    const params = terms.map((t) => `% ${t} %`);
    const res = db.exec(
      `SELECT id, (${score}) AS score FROM s WHERE score > 0 ORDER BY score DESC, id`,
      params,
    );
    db.close();
    return res.length ? res[0].values.map(([id]) => ({ id })) : [];
  }
}
