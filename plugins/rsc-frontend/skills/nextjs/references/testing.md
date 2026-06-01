# Testing Next.js — Vitest 3, RTL, MSW 2, Playwright

Deep dive behind the "Verify" workflow. The core reality: **async Server Components are not
reliably renderable in jsdom**, so unit-test the data/logic functions and Server Actions, and cover
rendered pages with Playwright e2e.

## Stack & config

```ts
// vitest.config.ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./vitest.setup.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html"],
      thresholds: { lines: 80, functions: 80, branches: 75, statements: 80 },
    },
  },
});
```

```ts
// vitest.setup.ts
import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

afterEach(() => cleanup());
```

In unit tests you must mock Next's request-bound modules — `next/navigation` (`useRouter`,
`redirect`, `notFound`) and `next/headers` (`cookies`, `headers`) — because they have no real
request context under Vitest:

```ts
import { vi } from "vitest";
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
  redirect: vi.fn(),
  notFound: vi.fn(),
}));
```

## RTL behavior testing

Query by **role/label first**; `getByTestId` is the last resort. Create `userEvent` once per test;
use async `findBy`/`waitFor` for anything that appears after an interaction.

```tsx
// test-utils.tsx — render wrapper with the app providers
import { render, type RenderOptions } from "@testing-library/react";
import { type ReactElement, type ReactNode } from "react";
import { ThemeCtx } from "@/components/theme";

function Providers({ children }: { children: ReactNode }) {
  return <ThemeCtx value="light">{children}</ThemeCtx>;
}

export function renderWithProviders(ui: ReactElement, options?: RenderOptions) {
  return render(ui, { wrapper: Providers, ...options });
}
export * from "@testing-library/react";
```

```tsx
// signup-form.test.tsx
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { expect, test, vi } from "vitest";
import { renderWithProviders } from "./test-utils";
import { SignupForm } from "@/app/signup/form";

vi.mock("@/app/signup/actions", () => ({
  signup: vi.fn(async () => ({ status: "error", fieldErrors: { email: "Already registered" } })),
}));

test("shows a field error returned by the action", async () => {
  const user = userEvent.setup();
  renderWithProviders(<SignupForm />);
  await user.type(screen.getByLabelText(/email/i), "taken@example.com");
  await user.type(screen.getByLabelText(/password/i), "longenough");
  await user.click(screen.getByRole("button", { name: /sign up/i }));
  expect(await screen.findByText(/already registered/i)).toBeInTheDocument();
});
```

## MSW 2

MSW 2 uses `http` + `HttpResponse` (the old `rest` API is gone). Fail loudly on unmocked requests.

```ts
// mocks/server.ts
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";

export const handlers = [
  http.get("https://api.example.com/products", () =>
    HttpResponse.json([{ id: "p1", name: "Widget" }]),
  ),
];
export const server = setupServer(...handlers);
```

```ts
// vitest.setup.ts (append)
import { afterAll, afterEach, beforeAll } from "vitest";
import { server } from "./mocks/server";

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

```ts
// per-test override: force the products endpoint to 500
import { http, HttpResponse } from "msw";
import { server } from "./mocks/server";

server.use(
  http.get("https://api.example.com/products", () =>
    HttpResponse.json({ error: "boom" }, { status: 500 }),
  ),
);
```

## Testing Server Actions

`"use server"` files run server-side — test the **function**, not a rendered tree. Call it with a
`FormData`, mock `auth()` and the DB, and assert the typed result plus that invalidation fired.

```ts
// signup.action.test.ts
import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/db", () => ({
  db: { user: { findUnique: vi.fn(async () => null), create: vi.fn(async () => ({ id: "u1" })) } },
}));
vi.mock("next/cache", () => ({ revalidateTag: vi.fn() }));

import { signup } from "@/app/signup/actions";
import { db } from "@/lib/db";

function fd(obj: Record<string, string>) {
  const f = new FormData();
  for (const [k, v] of Object.entries(obj)) f.set(k, v);
  return f;
}

describe("signup action", () => {
  it("returns field errors for invalid input", async () => {
    const res = await signup({ status: "idle" }, fd({ email: "nope", password: "x" }));
    expect(res.status).toBe("error");
    expect(res.fieldErrors?.email).toBeDefined();
  });

  it("creates the user on valid input", async () => {
    const res = await signup({ status: "idle" }, fd({ email: "a@b.com", password: "longenough" }));
    expect(res.status).toBe("ok");
    expect(db.user.create).toHaveBeenCalledOnce();
  });
});
```

For an action that mutates and revalidates, also `expect(revalidateTag).toHaveBeenCalledWith("posts")`.

## Testing Route Handlers

Import the exported `GET`/`POST` and invoke with a real `Request`; assert status and JSON.

```ts
// route.test.ts
import { describe, expect, it, vi } from "vitest";

vi.mock("@/auth", () => ({ auth: vi.fn(async () => ({ user: { id: "u1" } })) }));
vi.mock("@/lib/db", () => ({
  db: { project: { create: vi.fn(async () => ({ id: "p1", name: "X" })) } },
}));

import { POST } from "@/app/api/projects/route";

describe("POST /api/projects", () => {
  it("creates a project (201)", async () => {
    const req = new Request("http://localhost/api/projects", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name: "X" }),
    });
    const res = await POST(req as never);
    expect(res.status).toBe(201);
    expect(await res.json()).toMatchObject({ project: { id: "p1" } });
  });
});
```

## RSC caveat

**Async Server Components are NOT reliably renderable in jsdom.** Do not snapshot or `render()` an
`async function Page()`. Instead: unit-test the data functions it calls (e.g. `getProject`), unit-test
its client islands in isolation, and assert the composed, rendered page through Playwright e2e.

## Playwright e2e

```ts
// playwright.config.ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  use: { baseURL: "http://localhost:3000" },
  webServer: {
    command: "next build && next start",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
```

```ts
// e2e/rename.spec.ts — login → submit a form action → assert the revalidated UI
import { expect, test } from "@playwright/test";

test("renaming a project updates the list", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel(/email/i).fill("user@example.com");
  await page.getByLabel(/password/i).fill("password123");
  await page.getByRole("button", { name: /sign in/i }).click();

  await page.goto("/projects/p1");
  await page.getByLabel(/project name/i).fill("Renamed");
  await page.getByRole("button", { name: /save/i }).click();
  await expect(page.getByRole("heading", { name: "Renamed" })).toBeVisible();
});
```

```ts
// stub network at the browser level when needed
await page.route("**/api/notifications", (route) =>
  route.fulfill({ json: { count: 0 } }),
);
```

```ts
// e2e/a11y.spec.ts — accessibility smoke with @axe-core/playwright
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

test("home page has no critical a11y violations", async ({ page }) => {
  await page.goto("/");
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations.filter((v) => v.impact === "critical")).toEqual([]);
});
```

## Coverage targets & commands

| Layer                       | Target | Tooling          |
| --------------------------- | ------ | ---------------- |
| Utilities / pure functions  | ≥ 90%  | Vitest           |
| Hooks                       | ≥ 85%  | Vitest + RTL     |
| Presentational components   | ≥ 80%  | Vitest + RTL     |
| Container / stateful comps  | ≥ 70%  | Vitest + RTL     |
| Pages (RSC) & full flows    | e2e    | Playwright       |

```bash
vitest run                 # unit + integration, once
vitest run --coverage      # with v8 coverage thresholds
playwright test            # e2e (builds + starts the app via webServer)
```

## Anti-patterns

- `container.querySelector(...)` instead of role/label queries — tests implementation, not behavior.
- Asserting render counts or internal state — brittle; assert what the user sees.
- Mocking React itself — mock the network (MSW) and the DB/`auth` modules instead.
- Ignoring `act(...)` warnings — they signal an unawaited update; fix with `findBy`/`waitFor`.
- Snapshotting an RSC page — async Server Components are not jsdom-renderable; use Playwright.

## See Also

- `react.md` — the components and hooks under test.
- `data-and-caching.md` — the Server Actions and data functions these tests target.
