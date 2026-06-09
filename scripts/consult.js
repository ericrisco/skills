import initSqlJs from 'sql.js';

// Stopwords (es + en + common EU words) — these match everywhere via LIKE and drown the signal.
const STOP = new Set([
  'una', 'un', 'unos', 'unas', 'con', 'de', 'del', 'la', 'el', 'los', 'las', 'para',
  'que', 'porque', 'en', 'mi', 'mis', 'me', 'quiero', 'tener', 'hacer', 'al', 'lo',
  'su', 'sus', 'este', 'esta', 'esto', 'como', 'mas', 'más', 'algo', 'cosa', 'cosas',
  'vull', 'vols', 'amb', 'segons', 'usuari', 'usuaris', 'aquesta', 'aquest',
  'aixo', 'això', 'per', 'els', 'les', 'dels', 'segun', 'según', 'usuario',
  'usuarios', 'tarea', 'tareas',
  'the', 'and', 'or', 'to', 'of', 'in', 'for', 'with', 'my', 'want', 'build', 'it',
  'need', 'have', 'make', 'create', 'add', 'new',
  'le', 'des', 'du', 'pour', 'cette', 'cet', 'ce', 'mon', 'ma', 'mes',
  'il', 'gli', 'questo', 'questa', 'mio', 'mia',
  'o', 'a', 'os', 'as', 'essa', 'esse', 'minha', 'meu',
  'der', 'die', 'das', 'den', 'dem', 'des', 'fur', 'fuer', 'für', 'diese', 'dieser',
  'dit', 'deze', 'het', 'een', 'voor', 'mijn',
]);

// Spanish / colloquial terms → catalog tags. Lets non-programmers describe
// outcomes in their words and still hit the right (English-tagged) skill.
const SYNONYMS = {
  web: ['web', 'frontend', 'nextjs'], pagina: ['web', 'nextjs'], 'página': ['web', 'nextjs'],
  website: ['web', 'nextjs'], site: ['web', 'nextjs'], landing: ['landing', 'web', 'nextjs'],
  tienda: ['web', 'frontend'], ecommerce: ['web'], pagos: ['security', 'auth'], pago: ['security'],
  datos: ['database', 'sql'], base: ['database'], guardar: ['database'], almacenar: ['database'],
  publicar: ['deploy', 'docker'], publicarla: ['deploy'], publicarlo: ['deploy'], online: ['deploy'],
  desplegar: ['deploy'], deploy: ['deploy'], servidor: ['backend', 'deploy'],
  montar: ['bootstrap', 'start', 'setup', 'new'], monta: ['bootstrap', 'start', 'setup', 'new'],
  montando: ['bootstrap', 'start', 'setup', 'new'], arrancar: ['bootstrap', 'start', 'setup', 'new'],
  arranca: ['bootstrap', 'start', 'setup', 'new'], empezar: ['bootstrap', 'start', 'setup', 'new'],
  empieza: ['bootstrap', 'start', 'setup', 'new'], iniciar: ['bootstrap', 'start', 'setup', 'new'],
  inicia: ['bootstrap', 'start', 'setup', 'new'], start: ['bootstrap', 'start', 'setup', 'new'],
  bootstrap: ['bootstrap', 'start', 'setup', 'new'], setup: ['bootstrap', 'start', 'setup', 'new'],
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

const SKILL_ROUTING_TERMS = ['suggest', 'detect', 'install', 'meta'];

const SKILL_NOUNS = new Set([
  'skill', 'skills', 'habilidad', 'habilidades', 'habilitat', 'habilitats',
  'competencia', 'competencias', 'competence', 'competences', 'competenza',
  'competenze', 'habilidade', 'habilidades', 'fertigkeit', 'fertigkeiten',
  'vaardigheid', 'vaardigheden',
]);

const SKILL_ROUTING_VERBS = new Set([
  'recommend', 'recommended', 'recommending', 'recommendation', 'recommendations',
  'suggest', 'suggests', 'suggesting', 'advise', 'choose', 'select', 'find',
  'detect', 'detects', 'detecting', 'route', 'routing', 'match', 'matching',
  'install', 'installs', 'installing', 'add', 'use',
  'recomendar', 'recomienda', 'recomiendas', 'recomiendame', 'recomendacion',
  'recomendaciones', 'sugerir', 'sugiere', 'aconseja', 'elegir', 'elige',
  'detectar', 'detecta', 'instalar', 'instala', 'usar',
  'recomanar', 'recomana', 'recomanes', 'recomanen', 'recomanacio',
  'recomanacions', 'suggerir', 'tria', 'trobar', 'detecti', 'installar',
  'instal', 'afegir',
  'recommande', 'recommander', 'recommandation', 'conseiller', 'choisir',
  'trouver', 'detecter', 'installer', 'ajouter', 'utiliser',
  'consiglia', 'consigliare', 'raccomanda', 'scegliere', 'trovare', 'rilevare',
  'installare', 'aggiungi', 'usare',
  'recomenda', 'recomendacao', 'recomendacoes', 'sugerir', 'escolher',
  'encontrar', 'detectar', 'instalar', 'adicionar', 'usar',
  'empfiehl', 'empfehlen', 'empfehlung', 'waehlen', 'wahlen', 'finden',
  'erkennen', 'installiere', 'installieren', 'verwenden',
  'aanbevelen', 'aanbeveling', 'kiezen', 'vinden', 'detecteren',
  'installeer', 'installeren', 'gebruiken',
]);

const MIN_USEFUL_SCORE = 2;
const LOW_SIGNAL_TAG_TERMS = new Set(['web', 'frontend']);

function fold(term) {
  return term.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function expandedTerms(query) {
  const raw = query.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, ' ').split(/\s+/)
    .filter((t) => t.length > 1);
  const tokens = [];
  for (const t of raw) {
    tokens.push(t);
    const folded = fold(t);
    if (folded !== t) tokens.push(folded);
  }

  const set = new Set();
  const hasSkillNoun = tokens.some((t) => SKILL_NOUNS.has(t));
  const hasSkillRoutingVerb = tokens.some((t) => SKILL_ROUTING_VERBS.has(t));

  for (const t of tokens) {
    if (STOP.has(t)) continue;
    set.add(t);
    for (const syn of SYNONYMS[t] || []) set.add(syn);
  }
  if (hasSkillNoun && hasSkillRoutingVerb) {
    for (const term of SKILL_ROUTING_TERMS) set.add(term);
  }
  return [...set];
}

export async function rank(manifest, query) {
  const terms = expandedTerms(query);
  if (!terms.length) return [];
  const scored = scoreRows(manifest.skills, terms);
  if (!scored.length || Math.max(...scored.map((r) => r.score)) < MIN_USEFUL_SCORE) return [];
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
    if (!res.length) return [];
    const ids = new Set(res[0].values.map(([id]) => id));
    return scored.filter((r) => ids.has(r.id)).sort(byScore);
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
    if (!res.length) return [];
    const ids = new Set(res[0].values.map(([id]) => id));
    return scored.filter((r) => ids.has(r.id)).sort(byScore);
  }
}

function scoreRows(skills, terms) {
  return skills.map((skill) => {
    const id = skill.id.toLowerCase();
    const tags = (skill.tags || []).map((t) => t.toLowerCase());
    const description = ` ${skill.description.toLowerCase()} `;
    let score = 0;
    for (const term of terms) {
      if (id === term) score += 20;
      else if (!LOW_SIGNAL_TAG_TERMS.has(term) && id.includes(term)) score += 8;
      if (tags.includes(term)) score += LOW_SIGNAL_TAG_TERMS.has(term) ? 3 : 10;
      if (description.includes(` ${term} `)) score += 1;
    }
    return { id: skill.id, score };
  }).filter((r) => r.score > 0);
}

function byScore(a, b) {
  return b.score - a.score || a.id.localeCompare(b.id);
}
