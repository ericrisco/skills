# Multiformat ingest — turning any raw file into `raw/`

This document defines how the **Fetch** step of the wiki protocol
(`wiki-protocol.md`) converts an arbitrary input — a PDF invoice, a phone
photo, a bank-statement CSV, an API dump — into the markdown that lives in
`02-DOCS/raw/`. It is the "el agente sale a pasear" engine for raw data:
the wiki accepts **any** format, not just text.

The promise: **you drop a file, the agent figures out what it is and how to
read it.** No rigid per-format pipeline you have to configure. If the agent
can perceive it, it ingests it. If it can't, it preserves the original and
logs a gap — never silently drops data.

---

## The invariant — every format produces the same three artifacts

Whatever the input, a successful Fetch produces:

1. **Preserved original** at `raw/<topic>/_originals/<original-filename>`.
   The byte-for-byte source is never lost. Binaries (PDF, images, xlsx) live
   here forever; the markdown is a derived view, not a replacement.
2. **Extracted-text markdown** at `raw/<topic>/YYYY-MM-DD-<slug>.md`, using
   `wiki-raw-template.md`. Its `Source:` line points at the original
   (`_originals/<filename>`) and records the extraction method.
3. **A compiled wiki article** (the normal Compile step in `wiki-protocol.md`).

`_originals/` is the only second-level subdirectory allowed under a `raw/`
topic. It is never compiled or linted as content; it is the archive.

The Raw field of the compiled article links to the **extracted markdown**
(`../../raw/<topic>/<slug>.md`), not to the binary.

---

## Format detection

Detect by extension first, then by content sniff if the extension is missing
or lying. Route to the matching handler below. When two handlers could
apply (e.g. an `.html` file that is really a saved table), prefer the one
that preserves the most structure.

| Input | Handler |
|-------|---------|
| `.md`, `.txt`, `.rst`, `.org` | Plain text |
| `.pdf` | PDF |
| `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.heic` | Image (vision) |
| `.json`, `.ndjson`, API responses | JSON / API |
| `.csv`, `.tsv`, `.xlsx`, `.xls`, `.parquet` | Tabular |
| `.html`, `.htm`, a URL | HTML / web |
| `.docx`, `.rtf`, `.odt` | Rich document |
| `.eml`, `.mbox` | Email |
| anything else / unreadable | Unknown binary |

---

## Handlers

### Plain text (`.md`, `.txt`, …)

Copy content into the raw template verbatim. Clean formatting noise only
(stray whitespace, nav chrome). No original-preservation step needed — the
text *is* the markdown — but if the source file had a meaningful name or
binary siblings, still drop a copy in `_originals/` for provenance.

### PDF

1. Read the PDF with the agent's native PDF capability (the `Read` tool
   accepts `.pdf` via its `pages` parameter — read in ≤20-page batches for
   large files).
2. Transcribe the text faithfully into the raw template. Preserve headings,
   tables (as markdown tables), and figure captions. For scanned/image PDFs
   with no text layer, fall back to the **Image** handler page by page (the
   agent reads the rendered pages as images and transcribes).
3. Preserve the original PDF in `_originals/`.
4. Record `Extraction: PDF text layer` (or `PDF → vision OCR` for scanned)
   in the raw file's metadata block.

Typical inputs: invoices, bank statements, tax models, contracts, reports.

### Image (vision)

1. Use the agent's vision capability (the `Read` tool renders images) to
   **transcribe and describe** the image: any visible text verbatim (OCR),
   plus a short structured description of what the image shows (a receipt, a
   whiteboard diagram, a screenshot of a dashboard…).
2. If the image is primarily a document (receipt, scanned page), prioritise
   faithful text transcription over description.
3. Preserve the original image in `_originals/`.
4. Record `Extraction: vision OCR + description`.

### JSON / API

1. Preserve the **raw JSON** in `_originals/` (pretty-printed is fine; keep
   the data intact).
2. Write a markdown summary into the raw file: what the payload is, its
   top-level shape (keys / array length), notable fields, and a short sample
   (truncate large arrays — note how many items were elided). Do **not**
   paste megabytes of JSON into the markdown; the original holds the full
   data, the markdown holds the readable digest.
3. For data pulled from a live API, record the endpoint URL and the pull
   timestamp in `Source:` / `Collected:`.

### Tabular (CSV, TSV, Excel, Parquet)

1. Preserve the original spreadsheet/CSV in `_originals/`.
2. Write a markdown summary: column schema (name + inferred type), row
   count, a sample of the first ~10 rows as a markdown table, and any
   obvious aggregates worth surfacing (totals, date range, distinct
   categories). For a bank statement, that means: period covered, number of
   transactions, total in/out, balance if present.
3. Do not transcribe thousands of rows into markdown — summarise. The
   original is the source of truth for full data; the markdown is the index
   into it.

### HTML / web

1. If it's a URL, fetch it with the agent's web-fetch capability. If it's a
   local `.html` file, read it.
2. Strip boilerplate (nav, ads, scripts, cookie banners), convert the main
   content to clean markdown.
3. Preserve the original HTML in `_originals/` only when it was a local file
   the user supplied; for fetched URLs the `Source:` URL is the provenance,
   no binary copy needed.

### Rich document (`.docx`, `.rtf`, `.odt`)

1. Extract the text content into markdown, preserving headings and tables.
   If the agent can't open the format directly, ask the user to export to
   PDF or paste the content, and note the limitation.
2. Preserve the original in `_originals/`.

### Email (`.eml`, `.mbox`)

1. Extract headers worth keeping (From, To, Date, Subject) into the metadata
   block, then the body as markdown. Split `.mbox` into one raw file per
   message when messages are thematically distinct.
2. Preserve the original in `_originals/`.

### Unknown binary / unreadable

**Never silently drop it.**

1. Preserve the original in `_originals/`.
2. Write a stub raw file recording: filename, size, detected type (if any),
   and `Extraction: FAILED — agent could not read this format`.
3. Append a gap to `wiki/gaps.md`:
   `gap | unreadable input <filename> — needs manual extraction or a converter`.
4. Leave the file flagged for the user. Do not move it to `_processed/`
   unless the user acknowledges; an unread file is not "processed".

---

## Topic assignment is content-driven, not format-driven

The handler decides *how to read* the file. The **topic** (`raw/<topic>/`,
`wiki/<topic>/`) is decided by **what the content is about**, exactly as in
the normal Compile step. A PDF invoice and a CSV export from the same vendor
may both land under `finanzas/`. A photo of a contract and a `.docx` of the
same contract both land under `legal/`. Never create topics named after
formats (`raw/pdfs/` is wrong; `raw/finanzas/` is right).

This is what makes the wiki **domain-agnostic**: the formats are plumbing,
the topics are the user's actual world model.

---

## Metadata additions to the raw template

When a raw file comes from a non-text source, extend the standard
`wiki-raw-template.md` header with one extra line:

```
> Source: _originals/2026-02-invoice-acme.pdf
> Collected: 2026-06-01
> Published: 2026-02-14
> Extraction: PDF text layer
```

`Extraction:` values: `verbatim text`, `PDF text layer`, `PDF → vision OCR`,
`vision OCR + description`, `JSON digest`, `tabular summary`, `HTML → markdown`,
`docx extract`, `email extract`, `FAILED`.

This line lets a later Query or Lint know whether it's reading a faithful
copy or a lossy digest, and whether to go back to `_originals/` for detail.
