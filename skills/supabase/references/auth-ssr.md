# Cookie-based Auth with @supabase/ssr (Next.js App Router)

Full wiring for server-side auth. The package is `@supabase/ssr` (it replaced `@supabase/auth-helpers`).
Three clients plus middleware; the rule everywhere is **`getClaims()` for authorization, never
`getSession()`**. `getClaims()` verifies the JWT signature locally against your project's published
public keys — the documented default since new projects sign with asymmetric keys (2025-10-01 onward).
Keep `getUser()` as the strict, higher-cost fallback for when you need to catch a banned or deleted
user mid-session (it round-trips to the Auth server on every call). On a legacy project still using a
symmetric JWT secret, `getClaims()` transparently falls back to that same round-trip.

## lib/supabase/client.ts (browser)

```ts
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
```

## lib/supabase/server.ts (Server Components / Route Handlers / Server Actions)

```ts
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (toSet) => {
          try {
            toSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Called from a Server Component — cookies are read-only here.
            // Safe to ignore: middleware refreshes the session.
          }
        },
      },
    },
  );
}
```

## middleware.ts (mandatory — refreshes expired tokens)

Server Components can't write cookies, so the *only* place an expired access token gets refreshed is
middleware. Without this, sessions silently expire mid-session.

```ts
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (toSet) => {
          toSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          toSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // IMPORTANT: getClaims() verifies the JWT signature locally (asymmetric keys,
  // default for new projects) — the lower-latency default. Swap to getUser() only
  // if you need strict per-request revalidation against the Auth server (live
  // ban/delete detection). Do not put logic between createServerClient and this call.
  const { data } = await supabase.auth.getClaims();
  const user = data?.claims;

  if (!user && !request.nextUrl.pathname.startsWith("/login")) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }
  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```

## Server-action sign-in / sign-out

```ts
"use server";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export async function signIn(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: String(formData.get("email")),
    password: String(formData.get("password")),
  });
  if (error) return { error: error.message };
  redirect("/dashboard");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
```

## OAuth + PKCE callback route

OAuth (and magic-link) flows use PKCE: the provider redirects back with a `code` you exchange for a
session. Add a route handler at `/auth/callback`.

```ts
import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/";

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(`${origin}${next}`);
  }
  return NextResponse.redirect(`${origin}/auth/auth-code-error`);
}
```

## Protecting a Server Component

```ts
const supabase = await createClient();
const { data } = await supabase.auth.getClaims(); // local JWK verify; never getSession() here
if (!data?.claims) redirect("/login");
// Need to catch a just-banned/deleted user this request? Use getUser() instead (Auth round-trip).
```

## auth-helpers → @supabase/ssr migration checklist

- Remove `@supabase/auth-helpers-nextjs`; install `@supabase/ssr`.
- Replace `createClientComponentClient` → `createBrowserClient` (lib/supabase/client.ts).
- Replace `createServerComponentClient` / `createRouteHandlerClient` → `createServerClient` with the
  `getAll`/`setAll` cookie adapter (lib/supabase/server.ts).
- Add `middleware.ts` for token refresh — this was implicit before and is now explicit.
- Audit every server-side `getSession()` and switch authorization checks to `getClaims()` (keep
  `getUser()` only where live ban/delete detection is required).

## SvelteKit / Remix

Same `@supabase/ssr` package and the same `getClaims()` rule. SvelteKit: create the server client in
`hooks.server.ts`, refresh in the handle hook, expose via `event.locals`. Remix: create the client per
request in the loader/action with the `getAll`/`setAll` adapter backed by Remix's cookie session.
