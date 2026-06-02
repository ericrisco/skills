# config-and-ci — full Playwright config, multi-role auth, and the CI workflow

Everything the SKILL condenses. Current line is Playwright v1.58.x; install browsers with
`npx playwright install --with-deps`.

## Full annotated playwright.config.ts

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  outputDir: './test-results',
  fullyParallel: true,                 // run files in parallel, tests within a file in parallel
  forbidOnly: !!process.env.CI,        // a stray test.only fails CI rather than silently skipping the rest
  retries: process.env.CI ? 2 : 0,     // CI absorbs infra blips; locally a flake should fail loud
  workers: process.env.CI ? 1 : undefined, // 1 worker/shard in CI when sharding; uncapped locally
  timeout: 30_000,                     // per-test cap
  expect: { timeout: 5_000 },          // per web-first-assertion poll cap

  reporter: process.env.CI
    ? [['blob'], ['github']]           // blob = mergeable across shards; github = inline annotations
    : [['html', { open: 'never' }], ['list']],

  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    trace: 'on-first-retry',           // full DOM/network/console trace the first time a test retries
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    // 1. Auth setup projects — one per role. They run first and write session JSON.
    { name: 'setup-admin',  testMatch: /admin\.setup\.ts/ },
    { name: 'setup-member', testMatch: /member\.setup\.ts/ },

    // 2. Real test projects load the right storageState and depend on their setup.
    {
      name: 'chromium-admin',
      use: { ...devices['Desktop Chrome'], storageState: 'playwright/.auth/admin.json' },
      dependencies: ['setup-admin'],
      testMatch: /.*admin.*\.spec\.ts/,
    },
    {
      name: 'chromium-member',
      use: { ...devices['Desktop Chrome'], storageState: 'playwright/.auth/member.json' },
      dependencies: ['setup-member'],
      testMatch: /.*member.*\.spec\.ts/,
    },
    {
      name: 'webkit-member',
      use: { ...devices['Desktop Safari'], storageState: 'playwright/.auth/member.json' },
      dependencies: ['setup-member'],
      testMatch: /.*member.*\.spec\.ts/,
    },
  ],

  webServer: {
    command: 'npm run start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI, // reuse the dev server locally; always fresh in CI
    timeout: 120_000,
  },
});
```

## Multi-role storageState setup project

One spec per role. Each logs in once and saves the session; the dependent projects above load it.

```ts
// e2e/auth/member.setup.ts
import { test as setup, expect } from '@playwright/test';

const memberFile = 'playwright/.auth/member.json';

setup('authenticate as member', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill(process.env.MEMBER_EMAIL!);
  await page.getByLabel('Password').fill(process.env.MEMBER_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();

  // Wait on a real post-login signal before saving, or you save a half-authenticated state.
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  await page.context().storageState({ path: memberFile });
});
```

Duplicate for `admin.setup.ts` with admin credentials and `playwright/.auth/admin.json`.

Always gitignore the auth dir — committed sessions leak secrets and go stale:

```gitignore
playwright/.auth/
test-results/
playwright-report/
blob-report/
```

Faster path when you have a programmatic login: skip the UI entirely and seed `storageState` from an
API token or a `request` call inside the setup project — same output JSON, no browser round-trip.

## GitHub Actions workflow (shard + merge + artifacts)

```yaml
name: e2e
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        shard: [1, 2, 3, 4]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npx playwright install --with-deps      # browsers + OS libs
      - run: npx playwright test --shard=${{ matrix.shard }}/4
        env:
          CI: 'true'
          BASE_URL: http://localhost:3000
          MEMBER_EMAIL: ${{ secrets.MEMBER_EMAIL }}
          MEMBER_PASSWORD: ${{ secrets.MEMBER_PASSWORD }}
      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}                       # keep the trace even when the job fails
        with:
          name: blob-report-${{ matrix.shard }}
          path: blob-report/
          retention-days: 7

  merge-report:
    if: ${{ !cancelled() }}
    needs: [test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - uses: actions/download-artifact@v4
        with: { path: all-blob-reports, pattern: blob-report-*, merge-multiple: true }
      - run: npx playwright merge-reports --reporter=html ./all-blob-reports
      - uses: actions/upload-artifact@v4
        with: { name: html-report, path: playwright-report/, retention-days: 14 }
```

Sharding only earns its complexity once a single runner overruns the ~5–10 min budget. Below that,
raise `workers` on one machine first. Each shard emits a `blob` report; the merge job stitches them
into one HTML report so reviewers see the whole suite, not four fragments.

Download `html-report`, run `npx playwright show-report`, and open any failed test's trace inline.
