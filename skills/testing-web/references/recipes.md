# Copy-paste recipes

All examples use Vitest 4 + `@testing-library/react ^16.3` + `user-event ^14.6`. For Jest, swap `vi.` for
`jest.` and the jest-dom import path (see jest-setup.md). Assume the SKILL.md config and setup file.

## Controlled input — assert the value the user sees

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

it("reflects typed text", async () => {
  const user = userEvent.setup();
  render(<NameField />);
  const input = screen.getByLabelText(/name/i);
  await user.type(input, "Ada");
  expect(input).toHaveValue("Ada");
});
```

## Form submit — verify the handler payload

```tsx
it("submits trimmed email", async () => {
  const user = userEvent.setup();
  const onSubmit = vi.fn();
  render(<SignupForm onSubmit={onSubmit} />);
  await user.type(screen.getByLabelText(/email/i), "  ada@x.test  ");
  await user.click(screen.getByRole("button", { name: /sign up/i }));
  expect(onSubmit).toHaveBeenCalledWith({ email: "ada@x.test" });
});
```

## Async data via MSW — mock the network boundary

```tsx
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";
import { render, screen } from "@testing-library/react";

const server = setupServer(
  http.get("/api/users/:id", () => HttpResponse.json({ name: "Ada" })),
);
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

it("shows the fetched name", async () => {
  render(<Profile id="1" />);
  expect(await screen.findByText("Ada")).toBeInTheDocument(); // findBy waits for the fetch
});

it("shows an error state on 500", async () => {
  server.use(http.get("/api/users/:id", () => new HttpResponse(null, { status: 500 })));
  render(<Profile id="1" />);
  expect(await screen.findByRole("alert")).toHaveTextContent(/failed/i);
});
```

## Custom render wrapping providers

```tsx
// test-utils.tsx — import { render } from here instead of @testing-library/react
import { render as rtlRender } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

export function render(ui: React.ReactElement) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return rtlRender(<QueryClientProvider client={client}>{ui}</QueryClientProvider>);
}
export * from "@testing-library/react";
```

## Fake timers — debounce / countdown

```tsx
it("debounces search by 300ms", async () => {
  vi.useFakeTimers();
  // user-event needs to share the fake clock:
  const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
  render(<Search onSearch={onSearch} />);
  await user.type(screen.getByRole("searchbox"), "ada");
  expect(onSearch).not.toHaveBeenCalled();
  vi.advanceTimersByTime(300);
  expect(onSearch).toHaveBeenCalledWith("ada");
  vi.useRealTimers(); // restore so other tests are not poisoned
});
```

## Hook with an effect and cleanup

```tsx
import { renderHook } from "@testing-library/react";

it("subscribes on mount and unsubscribes on unmount", () => {
  const unsub = vi.fn();
  const subscribe = vi.fn(() => unsub);
  const { unmount } = renderHook(() => useChannel("room", subscribe));
  expect(subscribe).toHaveBeenCalledOnce();
  unmount();
  expect(unsub).toHaveBeenCalledOnce();
});
```

## Error boundary

```tsx
function Boom(): never { throw new Error("kaboom"); }

it("renders fallback when a child throws", () => {
  const spy = vi.spyOn(console, "error").mockImplementation(() => {}); // silence React's logged throw
  render(<ErrorBoundary fallback={<p role="alert">Something broke</p>}><Boom /></ErrorBoundary>);
  expect(screen.getByRole("alert")).toHaveTextContent(/something broke/i);
  spy.mockRestore();
});
```
