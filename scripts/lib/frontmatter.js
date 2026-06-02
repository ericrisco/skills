export function parseFrontmatter(src) {
  const m = src.match(/^---\n([\s\S]*?)\n---/);
  if (!m) throw new Error('no frontmatter block');
  const out = {};
  const lines = m[1].split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (!kv) continue;
    const [, key, rawValue] = kv;
    const value = rawValue.trim();
    if (value === '') {
      const items = [];
      let j = i + 1;
      for (; j < lines.length; j++) {
        const item = lines[j].match(/^\s+-\s*(.*)$/);
        if (!item) break;
        items.push(unquote(item[1].trim()));
      }
      if (items.length) {
        out[key] = items;
        i = j - 1;
      } else {
        out[key] = '';
      }
      continue;
    }
    out[key] = parseValue(value);
  }
  return out;
}

function parseValue(v) {
  if (v.startsWith('[') && v.endsWith(']')) {
    const inner = v.slice(1, -1).trim();
    if (!inner) return [];
    return inner.split(',').map((s) => unquote(s.trim()));
  }
  return unquote(v);
}

function unquote(s) {
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    return s.slice(1, -1);
  }
  return s;
}
