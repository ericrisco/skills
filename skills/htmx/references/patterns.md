# htmx UX recipes

Copy-ready patterns. Each shows the client markup and the server fragment it expects. All
assume htmx 2.0.x, template auto-escaping on, and that endpoints branch on `HX-Request` to
serve the partial vs the full page (see [server-contract.md](server-contract.md)).

## Active search (debounced)

```html
<input type="search" name="q" placeholder="Search contacts…"
       hx-get="/contacts" hx-target="#results" hx-swap="innerHTML"
       hx-trigger="keyup changed delay:500ms, search">
<table><tbody id="results"><!-- _rows.html --></tbody></table>
```

`changed` fires only when the value actually changed; `delay:500ms` debounces. The server
returns just the `<tr>` rows. The endpoint reuses the same `_rows.html` partial it includes in
the full page, so there is one source of truth.

## Click-to-load and infinite scroll

Click-to-load: the button replaces itself (`outerHTML`) with the next rows plus a fresh button.

```html
<tbody id="rows">{# ...rows... #}</tbody>
<button hx-get="/rows?page=2" hx-target="#rows" hx-swap="beforeend"
        hx-on::after-request="this.remove()">Load more</button>
```

Infinite scroll: make the *last row* the trigger with `revealed` — when it scrolls into view it
loads the next page and appends it.

```html
<tr hx-get="/rows?page=3" hx-trigger="revealed"
    hx-target="#rows" hx-swap="beforeend">…last row…</tr>
```

Server returns the next page's rows; the new last row carries the next `revealed` trigger.

## Inline edit (click-to-edit)

```html
<!-- view state -->
<div hx-target="this" hx-swap="outerHTML">
  <span>{{ contact.email }}</span>
  <button hx-get="/contacts/{{ contact.id }}/edit">Edit</button>
</div>
```

```html
<!-- GET .../edit returns the form, which replaces the div (outerHTML inherited) -->
<form hx-put="/contacts/{{ contact.id }}" hx-target="this" hx-swap="outerHTML">
  <input name="email" value="{{ contact.email }}">
  <button>Save</button>
  <button type="button" hx-get="/contacts/{{ contact.id }}">Cancel</button>
</form>
```

`PUT` returns the view state again; the form is replaced by the updated view.

## Delete row + out-of-band count

One response removes a row and updates a counter elsewhere.

```html
<tr id="row-{{ id }}">
  <td>{{ name }}</td>
  <td><button hx-delete="/items/{{ id }}"
              hx-target="#row-{{ id }}" hx-swap="delete"
              hx-confirm="Delete this item?">Delete</button></td>
</tr>
```

```html
<!-- DELETE response: empty body for the target (swap:delete) plus OOB badge update -->
<span id="item-count" hx-swap-oob="true">{{ remaining }} items</span>
```

## Modal dialog (load on demand)

```html
<button hx-get="/items/{{ id }}/detail" hx-target="#modal" hx-swap="innerHTML">Details</button>
<div id="modal"></div>
```

The endpoint returns the dialog markup; a close button swaps an empty fragment back in, or fire
`HX-Trigger: closeModal` and listen with `hx-trigger="closeModal from:body"`.

## Progress bar (polling, ended by HX-Trigger)

```html
<div id="progress" hx-get="/jobs/{{ id }}/progress"
     hx-trigger="every 600ms" hx-swap="innerHTML">
  <progress value="0" max="100"></progress>
</div>
```

While the job runs, the endpoint returns an updated `<progress>`. When it finishes, the endpoint
responds with markup that has **no** `every 600ms` trigger (polling stops because the element was
replaced) and sets `HX-Trigger: jobDone` so other regions can react. This is the right way to end
polling — do not poll forever.

## Tabs

```html
<nav>
  <button hx-get="/tab/overview" hx-target="#panel">Overview</button>
  <button hx-get="/tab/activity" hx-target="#panel">Activity</button>
</nav>
<section id="panel" hx-swap="innerHTML"><!-- active panel --></section>
```

Each tab endpoint returns only its panel fragment.
