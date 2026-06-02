import initSqlJs from 'sql.js';

function termsOf(query) {
  return query.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, ' ').split(/\s+/).filter((t) => t.length > 1);
}

export async function rank(manifest, query) {
  const terms = termsOf(query);
  if (!terms.length) return [];
  const SQL = await initSqlJs();
  const db = new SQL.Database();

  const rows = manifest.skills.map((sk) => [
    sk.id,
    `${sk.id} ${sk.description} ${(sk.tags || []).join(' ')}`.toLowerCase(),
  ]);

  // Prefer FTS5 for fidelity with ECC; fall back to scored LIKE if the
  // sql.js wasm build was compiled without the FTS5 module.
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
    const score = terms.map(() => '(doc LIKE ?)').join(' + ');
    const params = terms.map((t) => `%${t}%`);
    const res = db.exec(
      `SELECT id, (${score}) AS score FROM s WHERE score > 0 ORDER BY score DESC, id`,
      params,
    );
    db.close();
    return res.length ? res[0].values.map(([id]) => ({ id })) : [];
  }
}
