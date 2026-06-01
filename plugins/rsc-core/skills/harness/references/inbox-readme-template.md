# Inbox — drop any raw data here

This is the **ingest folder** of your knowledge base. Throw anything in here
and an agent will process it into the wiki on the next sweep.

> Aquí cae cualquier dato en crudo. No hay formato rígido. El sistema se
> adapta a tu caos, no al revés.

## What you can drop

Anything. Really:

- Facturas, extractos bancarios, modelos de impuestos — `*.pdf`
- Fotos de recibos, capturas, pizarras — `*.png`, `*.jpg`, `*.heic`
- Exports de APIs, payloads — `*.json`
- Hojas de cálculo, CSVs de transacciones — `*.csv`, `*.xlsx`
- Notas sueltas, markdown, txt — `*.md`, `*.txt`
- Páginas guardadas, documentos — `*.html`, `*.docx`, `*.eml`

If the agent can read it, it gets ingested. If it can't, the original is
preserved and a gap is logged for you — nothing is ever silently dropped.

## How it works

1. **You drop** files here (or whole folders).
2. **The agent sales a pasear** — run a sweep by saying *"procesa el inbox"*
   (or it runs on a schedule, see below). For each file it:
   - detects the format and extracts the content,
   - classifies it into a topic (`finanzas/`, `legal/`, `crm/`, …) by what
     it's *about*, not what format it is,
   - relates it to what's already in the wiki (cross-links),
   - compiles it into a wiki article.
3. **Processed files move** to `_processed/YYYY-MM-DD/` as an audit trail —
   the byte-for-byte original is also preserved under
   `../raw/<topic>/_originals/`.
4. **Each new file feeds and improves the system** — the maintenance and
   improvement loop runs automatically after the sweep.

## Folders

- `_processed/` — files already ingested, archived by sweep date. Safe to
  prune once you trust the wiki.

## Schedule the walk (optional)

```bash
# Nightly inbox sweep at 02:00
schedule create wiki-inbox --cron "0 2 * * *" --command "procesa el inbox"
```

You don't have to wait for the schedule — say *"procesa el inbox"* anytime.
