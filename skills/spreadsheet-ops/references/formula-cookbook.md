# Formula cookbook

Rule one, repeated because it causes the most broken formulas: **arguments are comma-separated, never
semicolons** — the file format is comma-only regardless of your locale's display separator.

## Lookups

```text
# Exact match, no column-index counting, works leftward:
=XLOOKUP(A2, Sheet2!$A:$A, Sheet2!$B:$B, "not found")

# Multi-criteria with FILTER (dynamic array):
=FILTER(Orders!B:B, (Orders!A:A=A2)*(Orders!C:C="PAID"))

# Avoid: VLOOKUP with a hardcoded index and approximate-match default
# Bad:  =VLOOKUP(A2, Sheet2!A:B, 2)        ' 4th arg defaults to TRUE → wrong row
# Good: =VLOOKUP(A2, Sheet2!$A:$B, 2, FALSE)  ' or just use XLOOKUP
```

## Conditional sums

```text
# Sum amount where region=EU AND status=OPEN:
=SUMIFS(amount, region, "EU", status, "OPEN")

# Common #VALUE! cause: the sum range and a criteria range are different sizes.
# Bad:  =SUMIFS(B2:B100, C2:C50, "EU")     ' mismatched lengths → #VALUE!
# Good: =SUMIFS(B2:B100, C2:C100, "EU")    ' all ranges identical shape
```

## Readability: LET and helper columns

```text
# Name a sub-expression once instead of recomputing it:
=LET(rate, VLOOKUP(A2, Rates!$A:$B, 2, FALSE),
     net,  B2 * (1 - rate),
     ROUND(net, 2))

# Replace a deep IF chain (Bad) with a lookup table + XLOOKUP (Good):
# Bad:  =IF(A1>90,"A",IF(A1>80,"B",IF(A1>70,"C","D")))
# Good: =XLOOKUP(A1, Bands!$A:$A, Bands!$B:$B, "F", -1)  ' -1 = exact-or-next-smaller
```

## Dynamic arrays

```text
=SORT(UNIQUE(FILTER(A2:A100, B2:B100<>"")))   ' spills automatically
```
A spill blocked by data in its target range raises `#SPILL!` — clear the cells below; do not
Ctrl+Shift+Enter.

## Error decoder

| Error | Means | Usual fix |
| --- | --- | --- |
| `#VALUE!` | A wrong argument type, or mismatched range sizes in SUMIFS/array math | Make all ranges the same shape; coerce text-numbers with `VALUE()` |
| `#REF!` | A reference no longer exists (deleted row/column/sheet) | Repoint the reference; check after structural edits |
| `#N/A` | Lookup found nothing | Add the 4th arg / `if_not_found`: `XLOOKUP(...,"")` |
| `#SPILL!` | A dynamic array cannot spill — something blocks the range | Clear the blocking cells below/right |
| `#NAME?` | Unknown function or name — often a typo or a locale/semicolon artifact | Fix the name; switch semicolons to commas |
| `#DIV/0!` | Division by zero/empty | Guard: `=IFERROR(a/b, 0)` or `=IF(b=0,0,a/b)` |
| `#NUM!` | Invalid numeric argument (e.g. negative sqrt) | Validate the input range |

## Cross-sheet helpers (long-standing — Excel since 2013, also in Google Sheets)

```text
=SHEET()          ' index of the current sheet
=SHEET("Q2")      ' index of a named sheet
=SHEETS()         ' count of sheets in the workbook
```
