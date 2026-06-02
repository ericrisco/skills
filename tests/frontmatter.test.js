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

test('parses yaml multiline arrays used by skills', () => {
  const md = `---\nname: client-onboarding\ndescription: "Build onboarding plans"\ntags:\n  - onboarding\n  - activation\nrecommends:\n  - customer-support\n  - proposals\nprofiles: []\n---\n# body`;
  const fm = parseFrontmatter(md);
  assert.deepEqual(fm.tags, ['onboarding', 'activation']);
  assert.deepEqual(fm.recommends, ['customer-support', 'proposals']);
  assert.deepEqual(fm.profiles, []);
});

test('missing frontmatter throws', () => {
  assert.throws(() => parseFrontmatter('# no frontmatter'));
});
