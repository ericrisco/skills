# WCAG 2.2 Level AA checklist (grouped by POUR)

The conformance bar. Each item is tagged how it's best verified:

- **[auto]** — an engine (axe-core) catches it reliably.
- **[manual]** — needs a human (keyboard, screen reader, judgement).
- **[both]** — automation flags candidates, a human confirms intent.

**NEW** marks a criterion introduced in WCAG 2.2 (W3C Recommendation 2023-10-05). WCAG 2.2 added 9 criteria and **removed 4.1.1 Parsing** — don't chase it anymore.

This is the AA conformance set (A + AA). Numbers (`x.y.z`) are the official SC ids so you can cross-reference the spec.

---

## Perceivable

- **1.1.1 Non-text Content (A)** — every image/icon/control has a text alternative; decorative images use `alt=""`. **[both]** (axe flags missing alt; a human judges whether it's *meaningful*).
- **1.3.1 Info and Relationships (A)** — structure is in the markup: headings, lists, `<label for>`, `<th scope>`, fieldset/legend. **[both]**
- **1.3.2 Meaningful Sequence (A)** — DOM order matches reading order; don't reorder with CSS in a way that breaks it. **[manual]**
- **1.3.4 Orientation (AA)** — don't lock to portrait/landscape unless essential. **[manual]**
- **1.3.5 Identify Input Purpose (AA)** — use `autocomplete` tokens on personal-data fields (`name`, `email`, `tel`). **[auto]**
- **1.4.1 Use of Color (A)** — color is never the only way to convey info; pair with text/icon/shape. **[manual]**
- **1.4.3 Contrast (Minimum) (AA)** — text **4.5:1**; large text (≥24px or ≥18.66px bold) **3:1**. **[auto in a real browser; jsdom can't]**
- **1.4.4 Resize Text (AA)** — text scales to 200% with no loss of content/function. **[manual]**
- **1.4.5 Images of Text (AA)** — use real text, not pictures of text, except logos. **[manual]**
- **1.4.10 Reflow (AA)** — content reflows to a 320px-wide viewport with no 2-D scrolling. **[manual]**
- **1.4.11 Non-text Contrast (AA)** — UI components and meaningful graphics hit **3:1** (input borders, focus indicators, icon glyphs, chart segments). **[both]**
- **1.4.12 Text Spacing (AA)** — no content clipped when users override line/letter/word spacing. **[manual]**
- **1.4.13 Content on Hover or Focus (AA)** — hover/focus popups are dismissable, hoverable, and persistent. **[manual]**

## Operable

- **2.1.1 Keyboard (A)** — all functionality available from the keyboard. **[manual]**
- **2.1.2 No Keyboard Trap (A)** — focus can always move away with the keyboard. **[manual]**
- **2.1.4 Character Key Shortcuts (A)** — single-key shortcuts can be turned off/remapped or only fire on focus. **[manual]**
- **2.4.1 Bypass Blocks (A)** — a skip link or landmarks let users bypass repeated content. **[both]**
- **2.4.2 Page Titled (A)** — every page has a unique, descriptive `<title>`. **[auto]**
- **2.4.3 Focus Order (A)** — focus order preserves meaning and operability. **[manual]**
- **2.4.4 Link Purpose (In Context) (A)** — link text says where it goes; no bare "click here". **[both]**
- **2.4.5 Multiple Ways (AA)** — more than one way to find a page (nav, search, sitemap). **[manual]**
- **2.4.6 Headings and Labels (AA)** — headings and labels describe topic/purpose. **[manual]**
- **2.4.7 Focus Visible (AA)** — keyboard focus is always visibly indicated. **[both]**
- **2.4.11 Focus Not Obscured (Minimum) (AA)** — **NEW** — a focused element isn't entirely hidden by sticky headers/footers/cookie bars. **[manual]**
- **2.5.1 Pointer Gestures (A)** — multipoint/path gestures have a single-pointer alternative. **[manual]**
- **2.5.2 Pointer Cancellation (A)** — actions fire on up-event, allow abort. **[manual]**
- **2.5.3 Label in Name (A)** — the accessible name contains the visible label text. **[both]**
- **2.5.4 Motion Actuation (A)** — device-motion features have a UI alternative and can be disabled. **[manual]**
- **2.5.7 Dragging Movements (AA)** — **NEW** — anything by dragging has a single-pointer (tap/button) alternative. **[manual]**
- **2.5.8 Target Size (Minimum) (AA)** — **NEW** — interactive targets ≥ **24×24 CSS px**, or spaced so a 24px circle doesn't overlap neighbors (spacing exception). **[both]**
- **2.3.1 Three Flashes or Below (A)** — nothing flashes more than 3×/second. **[manual]**

## Understandable

- **3.1.1 Language of Page (A)** — `<html lang="…">` set. **[auto]**
- **3.1.2 Language of Parts (AA)** — inline language changes marked with `lang`. **[manual]**
- **3.2.1 On Focus (A)** — focus alone doesn't trigger a context change. **[manual]**
- **3.2.2 On Input (A)** — changing a setting doesn't auto-change context without warning. **[manual]**
- **3.2.3 Consistent Navigation (AA)** — repeated nav stays in the same relative order. **[manual]**
- **3.2.4 Consistent Identification (AA)** — same-function components are labeled consistently. **[manual]**
- **3.2.6 Consistent Help (A)** — **NEW** — help (contact, FAQ link, chat) appears in the same relative order across pages. **[manual]**
- **3.3.1 Error Identification (A)** — errors are identified in text and described. **[both]**
- **3.3.2 Labels or Instructions (A)** — inputs have labels/instructions. **[both]**
- **3.3.3 Error Suggestion (AA)** — when known, suggest a correction. **[manual]**
- **3.3.4 Error Prevention (Legal/Financial/Data) (AA)** — reversible/checked/confirmed submissions. **[manual]**
- **3.3.7 Redundant Entry (A)** — **NEW** — don't ask for info already provided in the same process; auto-populate or let them select it. **[manual]**
- **3.3.8 Accessible Authentication (Minimum) (AA)** — **NEW** — no cognitive-function test to authenticate (no puzzles, no transcription); allow paste and password managers. **[manual]**

## Robust

- **4.1.2 Name, Role, Value (A)** — every UI component exposes a correct name, role, and current state/value to assistive tech. **[both]**
- **4.1.3 Status Messages (AA)** — status updates are announced without moving focus (live regions / roles). **[both]**

> 4.1.1 Parsing was **removed** in WCAG 2.2. Modern browsers recover from minor markup errors; the criterion no longer applies.

---

## How to work this list

1. Run axe (browser, `wcag22aa` tag) — clears most **[auto]** rows.
2. Do a keyboard-only pass — clears the operable **[manual]** rows.
3. One screen-reader spot check — names/roles/state, live-region announcements (4.1.2, 4.1.3).
4. Zoom 200% + 320px reflow — 1.4.4 / 1.4.10.
5. Manually verify the 2.2 NEW rows; they're almost all **[manual]** and the ones most teams miss.
