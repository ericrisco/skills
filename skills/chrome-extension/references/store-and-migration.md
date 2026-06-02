# Chrome Web Store submission + MV2→MV3 migration

Two long branches offloaded from SKILL.md: getting through review, and dragging
an old MV2 extension to MV3. Facts dated 2026-06-02 from developer.chrome.com.

## Store submission, step by step

1. **Register the developer account.** One-time **$5 USD** fee, covers up to 20
   extensions on that account. Use a Google account you control long-term — it
   owns the listings.
2. **Prepare the package.** Build, then zip the **build output only** (`dist/`).
   Strip `node_modules`, `.git`, README, and any source map you do not want
   public. The zip's root must contain `manifest.json`.
3. **Create the item** in the Developer Dashboard and upload the zip. Bump
   `version` in `manifest.json` on every upload — the store refuses a duplicate
   version.
4. **Listing assets:**
   - Icon: **128×128 PNG** (the store icon; separate from the toolbar icons).
   - Screenshots: at least one, **1280×800 or 640×400 PNG/JPEG**. More is better
     for conversion; show the actual UI, not marketing fluff.
   - Optional promo tiles and a YouTube link.
   - A clear, honest **description** and a **category**.
5. **Privacy practices form.** You must disclose what data you collect and why,
   certify you do not sell it for unrelated purposes, and provide a
   **privacy-policy URL** if you collect any user data. The legal copy itself is
   out of scope here — see `../gdpr-privacy/SKILL.md` and `../data-policy/SKILL.md`;
   this skill only tells you the URL plugs into this form.
6. **Permission justifications.** For each permission and each broad host match,
   the form asks why. Write one concrete sentence per permission. Vague answers
   ("for functionality") get rejected.
7. **Submit.** Review is typically **1–3 business days**; simple extensions often
   under 24h. You can use **staged rollout** to ship a new version to a
   percentage of users first and halt if metrics tank.

### Surviving review

- Least privilege: every permission must map to a visible feature. `activeTab`
  over `host_permissions`; specific origins over `<all_urls>`.
- No remotely hosted code — bundle everything. Reviewers run static checks for
  remote `<script src>` and `eval` of fetched strings.
- Single clear purpose per extension; do not bundle unrelated features.
- If rejected, the email names the policy. Fix the named issue, reply via the
  **appeals** flow in the dashboard with what changed, and resubmit. Do not
  silently re-upload the same package.

## MV2 → MV3 migration map

| MV2 | MV3 | Notes |
|---|---|---|
| `background.page` / `background.scripts` + `persistent: true` | `background.service_worker` (string), `"type": "module"` for imports | no DOM, no `window`; it terminates when idle |
| long-lived global state in the background page | `chrome.storage` (+ `chrome.storage.session` for in-memory) | worker restarts wipe globals |
| `setInterval` / `setTimeout` for periodic work | `chrome.alarms` | timers do not survive worker sleep |
| blocking `chrome.webRequest` (modify/block requests) | `chrome.declarativeNetRequest` (static + dynamic rules) | DNR never sees request bodies; declare rule resources |
| `chrome.tabs.executeScript(tabId, {code/file})` | `chrome.scripting.executeScript({ target: { tabId }, files })` | new signature; needs `scripting` permission |
| `chrome.tabs.insertCSS` | `chrome.scripting.insertCSS` | same shape change |
| remote `<script src>` / CDN libraries | bundle the library into the package | remote code is banned by MV3 CSP + policy |
| `browser_action` / `page_action` | unified `action` | one toolbar entry point |
| MV2-style host access by default | explicit `host_permissions` + prefer `activeTab` | broad hosts now warn loudly at install |

### Migration order that works

1. Flip `manifest_version` to `3` and convert `background` to a `service_worker`
   string. Move every event listener to the top level, synchronous.
2. Replace background-page globals with `chrome.storage` reads/writes.
3. Swap timers for `chrome.alarms`.
4. Convert `webRequest` blocking rules to `declarativeNetRequest` rule sets.
5. Update every `tabs.executeScript`/`insertCSS` to the `scripting.*` signature
   and add the `scripting` permission.
6. Remove all remote code; bundle dependencies.
7. Re-audit permissions — MV3 is the moment to drop `<all_urls>` for `activeTab`.

## Recent platform notes (version-dated)

- `chrome.userScripts.execute()` — Chrome 135 (Mar 2025): run dynamic,
  user-supplied scripts under a dedicated permission.
- `chrome.sidePanel.getLayout()` — Chrome 140 (Sep 2025).
- `chrome.storage` viewer/editor in DevTools — Chrome 132 (Jan 2025): inspect
  extension storage without a debug page.
- Cross-browser `browser` namespace exposed in Chrome — Chrome 148 (May 2026):
  the `browser.*` promise-based namespace now works in Chrome too, easing
  Firefox/Edge portability.

(Source: developer.chrome.com "What's new in Chrome extensions", accessed
2026-06-02.)
