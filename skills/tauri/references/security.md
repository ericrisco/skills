# Tauri v2 security — capabilities, permissions, scopes, CSP, isolation

The IPC bridge is default-deny. Nothing in the frontend can call Rust until a **capability**
applies to that window and grants the matching **permissions**, and a permission's **scope**
bounds what data/paths/hosts the command may touch. Get this layer right and an XSS in the
WebView can only do what you explicitly granted.

## The chain

```text
capability  ──applies to──▶  one or more windows/webviews
    │
    └─grants─▶  permissions  ──each maps──▶  scope (paths, hosts, …)
```

A webview matching **no** capability has **zero** IPC access. There is no global allow.

## Capability file anatomy

Files live in `src-tauri/capabilities/*.json` and are merged at build time.

```json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "main-capability",
  "description": "What the main window is allowed to do.",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "dialog:allow-open",
    {
      "identifier": "fs:allow-read-text-file",
      "allow": [{ "path": "$APPCONFIG/*" }]
    }
  ]
}
```

- `identifier` — unique per file.
- `windows` — glob of window labels this capability binds to (`["main"]`, `["settings-*"]`).
- `permissions` — either a string id (`plugin:permission-name`, e.g. `fs:allow-read-file`)
  or an object that **scopes** the permission with `allow` / `deny`.
- `platforms` (optional) — restrict to `["macOS", "windows", "linux", "iOS", "android"]`.

## Permission identifiers

Format is `plugin:permission`. Conventions:

- `core:default` — the baseline core permission set; safe to keep.
- `fs:allow-read-text-file`, `fs:allow-write-text-file`, `fs:allow-mkdir`, … — granular.
- `fs:default` / `http:default` — convenience bundles; **prefer granular** so you only
  grant the verbs you use.
- `deny-*` variants exist and win over `allow-*` — use to carve exceptions out of a bundle.

## Scope globs (fs / http)

Scopes restrict the *data* a permission reaches. They take path or URL globs, with
path variables resolved at runtime.

```json
// fs: read only inside the app config dir, never the home dir
{ "identifier": "fs:allow-read-text-file",
  "allow": [{ "path": "$APPCONFIG/*" }],
  "deny":  [{ "path": "$HOME/.ssh/*" }] }
```

Common path variables: `$APPCONFIG`, `$APPDATA`, `$APPLOCALDATA`, `$APPCACHE`, `$APPLOG`,
`$HOME`, `$DOCUMENT`, `$DOWNLOAD`, `$RESOURCE`, `$TEMP`. Prefer the `$APP*` set — they
resolve under the app's own sandbox dir.

```json
// http: only your API, nothing else
{ "identifier": "http:default",
  "allow": [{ "url": "https://api.example.com/*" }] }
```

`deny` always overrides `allow`. A permission with neither is effectively "any" — always
add an `allow`.

## Per-window privilege separation

Split capabilities so a low-trust window can't reach high-trust commands. Give the main UI
one capability and an embedded/third-party webview a far narrower one (or none).

```json
// capabilities/embed.json — a webview showing third-party content gets almost nothing
{ "identifier": "embed-capability", "windows": ["embed-*"], "permissions": ["core:default"] }
```

## CSP

CSP is enforced **only if set** in config. Until then the WebView runs whatever it loads.

```json
// tauri.conf.json — prod: lock to self; Tauri injects nonces/hashes for your assets
{ "app": { "security": {
  "csp": "default-src 'self'; img-src 'self' data:; connect-src 'self' https://api.example.com"
} } }
```

- Local scripts/styles are **hashed**; external ones get a **per-load nonce** — both only
  once a CSP string exists.
- In dev you typically need a looser `connect-src` for the Vite/HMR dev server; keep the
  strict policy for the production build (`devCsp` vs `csp` if you split them).
- A `<meta>` CSP tag does not cover the initial document — set CSP in config, not just markup.

## Isolation pattern

Use when frontend code might be untrusted — third-party npm deps, plugins, anything you
don't fully control. It injects a sandboxed `<iframe>` that intercepts every IPC message
before it reaches Rust, so you can validate or reject it. Messages are encrypted with the
browser's SubtleCrypto using an AES key **regenerated on each app start**.

1. Set the pattern in `tauri.conf.json`:

```json
{ "app": { "security": { "pattern": {
  "use": "isolation",
  "options": { "dir": "../dist-isolation" }
} } } }
```

2. Provide `dist-isolation/index.html` loading a hook that inspects each message:

```javascript
// dist-isolation/index.js
window.__TAURI_ISOLATION_HOOK__ = (payload) => {
  // inspect / sanitize / reject before it reaches Rust
  return payload;
};
```

Cost: a small per-message crypto overhead. Worth it whenever the frontend supply chain is
not fully trusted.

## Checklist

- [ ] Every window that calls Rust has a capability; no global allow.
- [ ] `fs`/`http` permissions carry an `allow` scope; sensitive paths in `deny`.
- [ ] Granular permissions, not `*:default` bundles, where practical.
- [ ] CSP set in config for the production build.
- [ ] Isolation pattern on if frontend deps/plugins are untrusted.
- [ ] No secrets in the frontend bundle — they live in Rust.
