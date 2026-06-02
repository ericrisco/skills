# Jest 30 setup (for repos already on Jest)

Use this only when the project is already invested in Jest (CRA, React Native, an old monorepo).
New projects: use Vitest 4 (see SKILL.md). Never run both runners in one suite.

## Versions that go together

- **Jest 30** (current, 30.2.x) — min **Node 18.x** (drops 14/16/19/21), min **TypeScript 5.4**.
- `jest-environment-jsdom` runs on **jsdom v26/27**.
- React 19 is supported in `pretty-format` (snapshot serialization).
- `@testing-library/react ^16.3`, `@testing-library/user-event ^14.6`, `@testing-library/jest-dom ^6.9`.

## Config

```js
// jest.config.js
module.exports = {
  testEnvironment: "jsdom",          // not the default 'node'
  setupFilesAfterEnv: ["<rootDir>/jest.setup.ts"],
  // ts-jest OR babel-jest below — pick one, see "TS transform"
};
```

```ts
// jest.setup.ts
import "@testing-library/jest-dom"; // bare import here — this is the Jest entry (Vitest uses /vitest)
```

The import path is the opposite of Vitest: in Jest the **bare** `@testing-library/jest-dom` is correct
because it registers against Jest's global `expect`. Using `/vitest` here fails.

## TS transform: ts-jest vs babel-jest

| Choice | When | Trade-off |
|---|---|---|
| **ts-jest** | You want real type-checking during tests | Slower; surfaces type errors as test failures |
| **babel-jest** (`@babel/preset-typescript`) | You already have Babel; want speed | Strips types, no type-checking — rely on `tsc --noEmit` separately |

```js
// ts-jest
module.exports = { preset: "ts-jest", testEnvironment: "jsdom" };
```

```js
// babel-jest — add to babel.config.js
module.exports = {
  presets: [
    ["@babel/preset-env", { targets: { node: "current" } }],
    "@babel/preset-typescript",
    ["@babel/preset-react", { runtime: "automatic" }],
  ],
};
```

## The Jest 30 breaking change that bites tests: window.location

jsdom became spec-compliant, so `window.location` is **no longer freely reassignable**. The old trick
breaks:

```ts
// Bad — throws "Cannot assign to read only property" under Jest 30 / jsdom v26+
delete (window as any).location;
window.location = { href: "https://x.test" } as any;
```

```ts
// Good — mutate individual props, or stub the navigation method
Object.defineProperty(window, "location", {
  value: new URL("https://x.test/dashboard"),
  writable: true,
});
// or, for assignment-based navigation:
const assign = jest.fn();
Object.defineProperty(window, "location", { value: { assign }, writable: true });
```

## Mock API parity with Vitest

| Vitest | Jest |
|---|---|
| `vi.mock("./api")` | `jest.mock("./api")` |
| `vi.fn()` | `jest.fn()` |
| `vi.spyOn(obj, "m")` | `jest.spyOn(obj, "m")` |
| `vi.useFakeTimers()` | `jest.useFakeTimers()` |
| `vi.advanceTimersByTime(ms)` | `jest.advanceTimersByTime(ms)` |

When migrating Jest -> Vitest, this table plus the jest-dom import swap (`/vitest`) and the config move
(`jest.config` -> `test:` block in `vite.config`/`vitest.config`) covers the bulk of the mechanical diff.
