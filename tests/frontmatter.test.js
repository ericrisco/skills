import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseFrontmatter } from '../scripts/lib/frontmatter.js';

test('parses name, description, tags, recommends', () => {
  const md = `---\nname: fastapi\ndescription: "Build APIs"\ntags: [python, api]\nrecommends: [postgresdb]\n---\n# body`;
  const fm = parseFrontmatter(md);
  assert.equal(fm.name, 'fastapi');
  assert.equal(fm.description, 'Build APIs');
  assert.deepEqual(fm.tags, ['python', 'api']);
  assert.deepEqual(fm.recommends, ['postgresdb']);
});

test('missing frontmatter throws', () => {
  assert.throws(() => parseFrontmatter('# no frontmatter'));
});
