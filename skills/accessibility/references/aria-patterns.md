# Accessible patterns (copy-ready)

The minimal correct ARIA + keyboard behavior for the widgets you can't build from a single native element. Written fresh; verify intent against the W3C ARIA Authoring Practices Guide. Reach for these **only** when no native element fits (Rule 0).

Recurring obligation for everything custom: **Name, Role, Value** — a name, the right role, and *state kept in sync* with the handler that changes the visuals.

---

## Modal dialog

Prefer native `<dialog>` + `el.showModal()` — it gives you the role, the backdrop, focus trap, and Escape-to-close for free. Build by hand only if you can't.

If hand-rolling: `role="dialog"` (or `alertdialog`), `aria-modal="true"`, and `aria-labelledby` pointing at the title.

| Key            | Behavior                                          |
| -------------- | ------------------------------------------------- |
| Open           | Move focus into the dialog (first control/title). |
| `Tab`          | Cycle within; from last element wrap to first.    |
| `Shift+Tab`    | From first element wrap to last.                  |
| `Esc`          | Close; **return focus to the trigger**.           |

Trap focus while open; mark the rest of the page inert (`inert` attribute or `aria-hidden` on the background). Never leave focus loose behind the overlay.

## Disclosure / accordion

A button that shows/hides a region. Native `<details><summary>` covers most cases — use it first.

Hand-rolled: a `<button>` with `aria-expanded` and `aria-controls` pointing at the panel id.

| Key             | Behavior                          |
| --------------- | --------------------------------- |
| `Enter`/`Space` | Toggle the panel; flip `aria-expanded`. |

```html
<button aria-expanded="false" aria-controls="sect1">Details</button>
<div id="sect1" hidden>…</div>
```

Toggle `aria-expanded` **and** the `hidden` attribute in the same handler.

## Tabs

`role="tablist"` wraps `role="tab"` buttons; each tab `aria-controls` its `role="tabpanel"`. The active tab has `aria-selected="true"`; the panel has `tabindex="0"`.

Use **roving tabindex**: active tab `tabindex="0"`, others `-1`.

| Key                 | Behavior                                  |
| ------------------- | ----------------------------------------- |
| `Tab`               | Into the tablist (one stop), then panel.  |
| `←` / `→`           | Move between tabs (horizontal tablist).   |
| `Home` / `End`      | First / last tab.                         |
| `Enter`/`Space`     | Activate (if not auto-activating).        |

## Combobox (autocomplete)

`role="combobox"` on the input with `aria-expanded`, `aria-controls` → the listbox, and `aria-activedescendant` → the highlighted option id. The popup is `role="listbox"` of `role="option"`.

| Key             | Behavior                                            |
| --------------- | --------------------------------------------------- |
| `↓` / `↑`       | Open list / move highlight; update `aria-activedescendant`. |
| `Enter`         | Select the highlighted option, collapse.            |
| `Esc`           | Close the list, keep or clear the value.            |
| typing          | Filter; keep focus in the input the whole time.     |

Focus stays in the input — you move a virtual highlight via `aria-activedescendant`, not real focus.

## Menu button

A `<button aria-haspopup="menu" aria-expanded>` opens a `role="menu"` of `role="menuitem"`. Roving tabindex inside.

| Key                 | Behavior                                  |
| ------------------- | ----------------------------------------- |
| `Enter`/`Space`/`↓` | Open menu, focus first item.              |
| `↑` / `↓`           | Move between items.                       |
| `Home` / `End`      | First / last item.                        |
| `Esc`               | Close, return focus to the button.        |
| `Enter`             | Activate item, close.                     |

Note: a simple navigation dropdown of links is often better as a plain disclosure of `<a>` elements — don't reach for `role="menu"` unless it's an application action menu.

## Toast / live region

Transient status messages. Don't move focus to them — announce via a live region that already exists in the DOM.

- `role="status"` / `aria-live="polite"` — non-urgent ("Saved", "3 results"). Waits for a pause.
- `role="alert"` / `aria-live="assertive"` — urgent ("Submit failed", "Session expiring"). Interrupts. Use sparingly.

```html
<!-- present in the DOM before the message; inject text into it -->
<div role="status" aria-live="polite" class="sr-only"></div>
```

The region must exist *before* you write into it — injecting both the container and the text at once often isn't announced.

---

## The `.sr-only` utility

Visually hide while keeping it in the accessibility tree (skip links, live regions, icon-button names):

```css
.sr-only {
  position: absolute;
  width: 1px; height: 1px;
  padding: 0; margin: -1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
  border: 0;
}
```

Do **not** use `display:none` or `visibility:hidden` for this — both remove the text from screen readers too.
