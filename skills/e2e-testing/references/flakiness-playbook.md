# flakiness-playbook — the 2026 patterns, reproduced and fixed

A flaky test passes and fails on the same code. Industry flaky rates sit around 2–5%; a 3% rate on a
40-minute pipeline costs roughly an engineer-day per week in reruns and erodes trust until people
"just hit retry". Each pattern below has a named cause and a deterministic fix. **Open the trace
first** — `npx playwright show-trace trace.zip` replays the failing run with DOM snapshots, network,
and console, which turns a one-line CI log into an actual diagnosis.

## 1. Auto-wait racing a re-render (read-once assertion)

The element exists when you read it, but the async update lands a frame later.

```ts
// Repro — captures one frame; flakes when the fetch resolves after the read.
const total = await page.locator('#total').textContent();
expect(total).toBe('$42.00');

// Fix — web-first assertion re-polls until the text matches or times out.
await expect(page.getByTestId('total')).toHaveText('$42.00');
```

## 2. Route handler registered after `goto`

The first request fires before the mock is in place, so it hits the network unmocked.

```ts
// Repro — initial /api/orders already went out by the time the route is set.
await page.goto('/orders');
await page.route('**/api/orders', r => r.fulfill({ json: orders }));

// Fix — register before navigation; now the first request is intercepted.
await page.route('**/api/orders', r => r.fulfill({ json: orders }));
await page.goto('/orders');
```

## 3. `networkidle` never settling in an SPA

SPAs with polling, websockets, or analytics beacons keep the network busy forever, so
`waitUntil: 'networkidle'` hangs until timeout.

```ts
// Repro — hangs because a heartbeat poll keeps the connection alive.
await page.goto('/dashboard', { waitUntil: 'networkidle' });

// Fix — wait on a concrete UI signal instead of network silence.
await page.goto('/dashboard');
await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
```

## 4. `waitForResponse` subscribed too late

If you `await` the action and only then wait for the response, the event already fired.

```ts
// Repro — the click's response can resolve before the listener attaches.
await page.getByRole('button', { name: 'Save' }).click();
const res = await page.waitForResponse('**/api/save'); // may hang or catch the wrong call

// Fix — start waiting first, then act, then await the promise.
const resPromise = page.waitForResponse('**/api/save');
await page.getByRole('button', { name: 'Save' }).click();
const res = await resPromise;
expect(res.ok()).toBeTruthy();
```

## 5. Strict-mode violation ("resolved to 2 elements")

A locator matches more than one node. The throw is correct — your selector is ambiguous.

```ts
// Repro — two "Delete" buttons on the page.
await page.getByRole('button', { name: 'Delete' }).click(); // throws in strict mode

// Fix — scope to the row, do not paper over it with .first().
await page
  .getByRole('row', { name: 'Invoice 1024' })
  .getByRole('button', { name: 'Delete' })
  .click();
```

## 6. `storageState` leakage between tests/roles

Sharing one mutated session file across roles, or letting one test's writes bleed into the next.

- One state file per role: `admin.json`, `member.json`, `anon` (none).
- Regenerate every CI run; gitignore `playwright/.auth/`.
- Playwright already gives each test a fresh `BrowserContext` (cookies/storage reset). If state leaks
  between tests, the cause is a shared fixture or committed state — not the framework.

## 7. `test.use()` scope confusion

`test.use({...})` applies to its whole file or `describe` block. Setting it at the top when only one
test needs the override silently changes siblings.

```ts
test.describe('mobile checkout', () => {
  test.use({ viewport: { width: 390, height: 844 } }); // scoped to this block only
  test('completes on a phone viewport', async ({ page }) => { /* ... */ });
});
```

## 8. Headed-vs-headless drift

Green when watched, red in CI (or vice-versa). Usually viewport size, animation timing, or font
rendering differences.

- Pin `viewport` in the config so headed and headless agree.
- Disable animations for determinism: `use: { ...devices['Desktop Chrome'] }` plus a global
  `* { animation: none !important; transition: none !important; }` style, or
  `await page.emulateMedia({ reducedMotion: 'reduce' })`.
- Reproduce in the mode that fails: run CI's exact command headless locally, or
  `npx playwright test --headed --project=chromium` to watch a headed-only failure.

## Trace-viewer workflow

1. CI uploads the trace (config has `trace: 'on-first-retry'`).
2. Download the artifact, then `npx playwright show-trace path/to/trace.zip`.
3. Step the timeline: inspect the DOM snapshot at the failing action, the network tab for the
   missed/late request, and the console for errors.
4. Reproduce locally with `--repeat-each=20` (or `--shard` parity) to measure the flake as a rate.
5. Fix the cause from the table above; confirm the rate hits zero, not merely lower.

When a flake survives this, hand the trace to `../debug/SKILL.md`: turn it into a measured k/N rate,
isolate one variable at a time, fix the cause, and add the test that proves it gone.
