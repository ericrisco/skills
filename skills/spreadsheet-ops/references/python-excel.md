# Python → Excel: openpyxl vs xlsxwriter vs pandas

Versions seen on PyPI 2026-06-02: openpyxl 3.1.5, pandas on the 3.x line, plus xlsxwriter (a separate
install — pandas does not bundle it). Re-check PyPI before pinning.

## Choosing the engine

| Need | Library | Notes |
| --- | --- | --- |
| Open + modify an existing `.xlsx` | openpyxl | Only one that round-trips an existing file. |
| New file, charts + conditional formats | xlsxwriter | Write-only. Richest formatting. |
| New file, very large, low memory | xlsxwriter `constant_memory` or openpyxl `write_only` | Stream row-by-row; cannot revisit written cells. |
| Quick DataFrame dump | pandas `to_excel` | Wraps an engine — pass `engine=` explicitly (see below). |
| Append a sheet to an existing file | pandas `ExcelWriter(engine="openpyxl", mode="a")` | xlsxwriter cannot append — it is write-only. |

For `.xlsx`, pandas `ExcelWriter`/`to_excel` resolves its engine from the `io.excel.xlsx.writer`
option: **xlsxwriter when it is installed, otherwise openpyxl**. That makes the effective default
environment-dependent — the same script writes through different engines on two machines, and append
mode silently needs openpyxl regardless. Do not rely on the implicit pick: always pass `engine=`
(`"xlsxwriter"` for a new formatted file, `"openpyxl"` for read/modify/append). Being explicit is the
whole fix for the long-standing default-engine confusion.

## The no-compute trap (full)

openpyxl stores the formula string; it never evaluates it. Excel/LibreOffice computes on open and
caches the result.

```python
from openpyxl import load_workbook

wb = load_workbook("book.xlsx")
ws = wb.active
ws["C2"] = "=A2*B2"
wb.save("book.xlsx")

# default load: cell holds the formula text
print(load_workbook("book.xlsx").active["C2"].value)            # "=A2*B2"
# data_only: cell holds the LAST CACHED value — None if never opened in Excel
print(load_workbook("book.xlsx", data_only=True).active["C2"].value)  # None
```

If a downstream consumer needs the number, either compute it in Python and write the literal value, or
open the file once headless (e.g. `libreoffice --headless --convert-to xlsx`) so the cache is populated.

Array and data-table formulae are preserved on read/write but, likewise, not evaluated.

## Chart + conditional format (xlsxwriter, new file)

```python
import pandas as pd

df = pd.DataFrame({"month": ["Jan", "Feb", "Mar"], "revenue": [100, 140, 90]})
with pd.ExcelWriter("report.xlsx", engine="xlsxwriter") as xl:
    df.to_excel(xl, sheet_name="data", index=False)
    wb, ws = xl.book, xl.sheets["data"]

    # conditional format: highlight revenue < 100
    ws.conditional_format("B2:B4", {
        "type": "cell", "criteria": "<", "value": 100,
        "format": wb.add_format({"bg_color": "#fde0e0"}),
    })

    # column chart bound to the data range
    chart = wb.add_chart({"type": "column"})
    chart.add_series({
        "categories": "=data!$A$2:$A$4",
        "values":     "=data!$B$2:$B$4",
        "name":       "Revenue",
    })
    ws.insert_chart("D2", chart)
```

Conditional formats on an **existing** file go through openpyxl's `openpyxl.formatting.rule` instead
(xlsxwriter cannot reopen the file).

## Large files

- xlsxwriter: `Workbook(path, {"constant_memory": True})` — flushes each row, near-flat memory; you
  cannot go back and rewrite an already-written cell.
- openpyxl: `Workbook(write_only=True)` then `ws.append([...])` per row. Same constraint.

## Append-mode gotchas

- `df.to_excel("f.xlsx")` with the default mode **truncates** the whole workbook. To keep existing
  sheets use `ExcelWriter(..., engine="openpyxl", mode="a")`.
- `if_sheet_exists` must be set in append mode: `"error"` (default), `"replace"`, `"overlay"`, `"new"`.
- xlsxwriter ignores `mode="a"` — it has no read path. Use openpyxl to append.
