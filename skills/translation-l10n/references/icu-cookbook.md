# ICU MessageFormat cookbook

Lookup recipes for the patterns that don't fit inline in SKILL.md. ICU is for plurals and `select` only — format dates/numbers with `Intl.*`, not inside the message.

## Full-sentence pattern (named args)

Never assemble a sentence from fragments. Put the whole sentence in one message and let the translator reorder freely.

```icu
{name} shared {count, plural, one {# photo} other {# photos}} with you
```

The translator owns the entire string, so Japanese or Arabic word order is theirs to set — your call site stays `t("share.summary", { name, count })`.

## Nested plural + select

Combine gender/category selection with pluralization. Each block still needs its own `other`.

```icu
{gender, select,
  female {{count, plural, one {She has # follower} other {She has # followers}}}
  male   {{count, plural, one {He has # follower}  other {He has # followers}}}
  other  {{count, plural, one {They have # follower} other {They have # followers}}}
}
```

## selectordinal — 1st / 2nd / 3rd

`plural` is for cardinals (1 item); `selectordinal` is for ordinals (1st place). English needs `one`/`two`/`few`/`other`; other languages differ.

```icu
You finished {place, selectordinal,
  one {#st}
  two {#nd}
  few {#rd}
  other {#th}
}
```

## The `#` token

Inside a `plural`/`selectordinal` block, `#` prints the formatted number for the current locale. Outside such a block it is a literal `#`. Don't reuse the count variable name where `#` already does the job.

## Escaping literals

ICU treats `{`, `}`, and `'` as syntax. To print them literally, wrap in single quotes; a doubled `''` prints one apostrophe.

```icu
This is a literal '{brace}' and an apostrophe '' here.
```

- `'{brace}'` → renders the text `{brace}` unparsed.
- `''` → renders `'`.
- A lone `'` that doesn't open a quoted span is treated as literal in most ICU implementations, but quote it explicitly to be safe.

## Per-language plural categories (quick table)

CLDR rules, summarized. Catalogs for these languages must supply exactly these categories.

| Language | Categories used |
| --- | --- |
| English (en), German (de), Spanish (es) | `one`, `other` |
| French (fr) | `one`, `many`, `other` |
| Russian (ru) | `one`, `few`, `many`, `other` |
| Polish (pl) | `one`, `few`, `many`, `other` |
| Arabic (ar) | `zero`, `one`, `two`, `few`, `many`, `other` |
| Chinese (zh), Japanese (ja), Korean (ko) | `other` only |

A category your language doesn't use is simply ignored; a category it *does* use but you omitted falls through to `other` — often wrong (e.g. Russian "2 файла" needs `few`, not `other`).

## Skeletons (number/date inside ICU)

ICU supports number/date "skeletons" (`{price, number, ::currency/EUR}`), but prefer formatting outside the message with `Intl` so the format stays in code, reviewable and testable, rather than scattered across translator-edited catalogs. Reserve skeletons for cases where the number is grammatically fused into the sentence.

## Validation before ship

Parse every catalog with your ICU library at build time and assert:
- every `plural`/`selectordinal`/`select` has an `other` clause,
- all placeholders present in the source key exist in each translation,
- no unbalanced `{`/`}`.

A failing parse should break CI, not surface at runtime.
