# Security & IPC — full hardened example

The SKILL.md gives the rules; this is the copy-paste reference that puts them together.

## Hardened `main.ts`

```ts
import { app, BrowserWindow, ipcMain, session, shell } from 'electron';
import path from 'node:path';

const APP_ORIGIN = 'https://app.local'; // or 'file://' for a fully local bundle

function createWindow() {
  const win = new BrowserWindow({
    width: 1100,
    height: 720,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      allowRunningInsecureContent: false,
    },
  });
  win.loadFile(path.join(__dirname, 'renderer/index.html'));
}

app.whenReady().then(() => {
  // CSP as a response header — covers the initial document, unlike a <meta> tag.
  session.defaultSession.webRequest.onHeadersReceived((details, cb) => {
    cb({
      responseHeaders: {
        ...details.responseHeaders,
        'Content-Security-Policy': [
          "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'",
        ],
      },
    });
  });
  createWindow();
});

// Navigation lockdown — applies to every webContents the app creates.
app.on('web-contents-created', (_e, contents) => {
  contents.on('will-navigate', (e, url) => {
    if (new URL(url).origin !== APP_ORIGIN) e.preventDefault();
  });
  contents.on('will-attach-webview', (e) => e.preventDefault()); // no <webview> tags
  contents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('https://')) shell.openExternal(url);
    return { action: 'deny' }; // never open a new in-app window to arbitrary content
  });
});
```

## IPC handlers with validation (`main.ts`, continued)

Every handler treats its arguments as hostile. Validate type, bound size, and never feed an
attacker string into `path.join`, `child_process`, or `eval`.

```ts
import { z } from 'zod';

const SaveNote = z.object({ id: z.string().uuid(), text: z.string().max(10_000) });

ipcMain.handle('note:save', async (_e, raw: unknown) => {
  const { id, text } = SaveNote.parse(raw); // throws → rejects the renderer's invoke()
  return db.notes.upsert(id, text);
});

ipcMain.handle('config:read', async () => readUserConfig()); // no input to validate
```

## `preload.ts` — one function per channel

```ts
import { contextBridge, ipcRenderer } from 'electron';
import type { Api } from './ipc/types';

const api: Api = {
  readConfig: () => ipcRenderer.invoke('config:read'),
  saveNote: (id, text) => ipcRenderer.invoke('note:save', { id, text }),
  onSync: (cb) => {
    const handler = () => cb();
    ipcRenderer.on('sync:done', handler);
    return () => ipcRenderer.removeListener('sync:done', handler); // give callers cleanup
  },
};

contextBridge.exposeInMainWorld('api', api);
```

## Shared contract (`ipc/types.ts`)

```ts
export interface Config { theme: 'light' | 'dark'; }

export interface Api {
  readConfig(): Promise<Config>;
  saveNote(id: string, text: string): Promise<void>;
  onSync(cb: () => void): () => void; // returns an unsubscribe fn
}
```

## Renderer global typing (`renderer/global.d.ts`)

```ts
import type { Api } from '../ipc/types';
declare global {
  interface Window { api: Api; } // window.api is now fully typed in the renderer
}
export {};
```

Renderer usage stays type-safe and capability-scoped:

```ts
const cfg = await window.api.readConfig();
await window.api.saveNote(crypto.randomUUID(), 'hello');
```

## Electron Fuses

Fuses flip security bits in the packaged binary itself, so they hold even if the JS is
tampered with. Apply at build time (e.g. via `@electron/fuses`):

```ts
import { FuseV1Options, FuseVersion, flipFuses } from '@electron/fuses';

await flipFuses(appPath, {
  version: FuseVersion.V1,
  [FuseV1Options.RunAsNode]: false,                 // no ELECTRON_RUN_AS_NODE bypass
  [FuseV1Options.EnableCookieEncryption]: true,     // encrypt the cookie store at rest
  [FuseV1Options.EnableNodeOptionsEnvironmentVariable]: false, // no NODE_OPTIONS injection
  [FuseV1Options.EnableNodeCliInspectArguments]: false,        // no --inspect debug port
  [FuseV1Options.OnlyLoadAppFromAsar]: true,        // refuse to run unpacked app code
  [FuseV1Options.LoadBrowserProcessSpecificV8Snapshot]: false,
});
```

## The full security checklist (each item, with the why)

- [ ] `nodeIntegration: false` — renderer must not get `require`/`process`; XSS would become RCE.
- [ ] `contextIsolation: true` — page and preload run in separate worlds; page can't rewrite the bridge.
- [ ] `sandbox: true` — OS-level sandbox around the renderer process.
- [ ] `webSecurity: true` — keep same-origin policy; disabling it to "fix CORS" opens the whole app.
- [ ] `allowRunningInsecureContent: false` — no mixed http content on an https page.
- [ ] CSP set via `onHeadersReceived`, not a `<meta>` tag — covers the initial document.
- [ ] `will-navigate` denies origins outside your app — navigation grants attacker content your privilege.
- [ ] `setWindowOpenHandler` denies new windows; external links go through `shell.openExternal` after protocol allow-listing.
- [ ] `will-attach-webview` denied (or `webviewTag: false`) — `<webview>` is a fresh attack surface.
- [ ] Every `ipcMain.handle` validates and bounds its args — the renderer is an untrusted client.
- [ ] No `ipcRenderer` (or its methods) exposed over `contextBridge` — one function per channel only.
- [ ] No `@electron/remote` — it's a direct renderer→main escalation path; use explicit IPC.
- [ ] Electron Fuses applied (run-as-node off, cookie encryption on, ASAR integrity on).
- [ ] App is on one of the latest 3 Electron majors — older = unpatched Chromium CVEs.
- [ ] No attacker-controlled string reaches `path.join`, `child_process`, `shell.openExternal`, or `eval`.
