# Reconciliation playbook + jurisdiction retention

## Month-end reconciliation, step by step

Reconciliation proves your book balance equals the bank's statement balance for a closed period. Do it at least monthly; weekly for high transaction volume.

1. **Freeze the period.** Pick the statement cutoff date. Pull the bank statement ending balance and your ledger ending balance for the *same* date.
2. **Match line by line.** Tick off each bank line against a book entry and each book entry against a bank line. Two unmatched piles remain: bank-only and book-only.
3. **Resolve bank-only lines.** A bank line with no book entry is usually a fee, interest, or auto-debit you never recorded — record it now.
4. **Resolve book-only lines.** A book entry with no bank line is usually a check or deposit that has not cleared yet — legitimate timing; list it as a reconciling item, do not delete it.
5. **Drive Uncategorized to 0.** Nothing closes with transactions still uncategorized.
6. **Confirm the difference is 0** or fully explained by the listed uncleared items. Lock the period.

## The diagnostic ladder — when book ≠ bank

Walk these in order. Never post a "plug" entry to force agreement; a plug hides the error and it compounds next month.

| Step | Cause | How to spot it |
| --- | --- | --- |
| 1 | **Timing** | An uncleared check or deposit. Difference equals an exact, identifiable in-flight item. Legitimate — list it. |
| 2 | **Duplicate** | Same transaction entered twice (common after a CSV import). Search the amount; expect two identical entries. |
| 3 | **Missing entry** | A bank line (fee, auto-debit, interest) with no book counterpart. Record it. |
| 4 | **Transposition** | Difference is evenly **divisible by 9** (e.g., $90, $540, $63) → two digits likely swapped (54 keyed as 45, 91 as 19). Re-key the entry. |
| 5 | **Sign / side error** | Difference is exactly **twice** a single transaction → it was posted to the wrong side (debit where it should be credit). Re-post it correctly. |
| 6 | **Wrong amount** | None of the above patterns fit → compare each matched pair amount-for-amount until the off-by line surfaces. |

The divisible-by-9 and double-the-amount tricks resolve the large majority of small discrepancies in seconds — check them before re-reading the whole ledger.

## US record retention (IRS "How long should I keep records")

| Keep | Applies to |
| --- | --- |
| 3 years | General default — most returns and supporting records |
| 4 years | Employment-tax records (from the date tax was due or paid) |
| 6 years | If you underreported income by more than 25% |
| 7 years | Claims for a bad-debt deduction or worthless-security loss |
| Indefinitely | Unfiled returns, fraudulent returns, and asset **basis** records (keep basis docs until the period for the year you dispose of the asset closes) |

When records support more than one item, keep them for the **longest** applicable period.

## Spain — autónomo / estimación directa simplificada

Under estimación directa simplificada the obligation is **libros registro**, not full double-entry:

- **Libro registro de ingresos** — income.
- **Libro registro de compras y gastos** — purchases and expenses.
- **Libro registro de bienes de inversión** — capital assets.

Plus the VAT registers (when VAT-registered):

- **Libro registro de facturas expedidas** — invoices issued.
- **Libro registro de facturas recibidas** — invoices received.

Each register entry must carry: **fecha, nº de factura, NIF del tercero, base imponible, tipo y cuota de IVA, importe total.** Under **estimación directa normal**, full Plan General de Contabilidad partida doble (proper double-entry) applies instead of the simplified libros registro.
