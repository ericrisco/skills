# Google Sheets API v4 + Apps Script V8

Versions seen on PyPI 2026-06-02: gspread 6.2.1, gspread-formatting 1.2.1; Sheets API v4; Apps Script
on the V8 runtime. Re-check before pinning.

## Credentials (handoff)

Creating the OAuth client / service account is `../google-workspace/SKILL.md`. This skill assumes a
credential exists. gspread auth modes:

| Mode | Call | Use for |
| --- | --- | --- |
| Service account | `gspread.service_account(filename="key.json")` | Bots, cron, servers |
| End-user OAuth | `gspread.oauth()` | Acting as a human |
| Public read | `gspread.api_key("API_KEY")` | Read-only public sheets |

**Service account access requirement:** a service account sees nothing until the sheet is shared with
its `client_email` (read it from the key JSON). A `PermissionError`/`SpreadsheetNotFound` is almost
always an unshared sheet. Share with Editor for writes.

## Quota math

- 300 read req/min/project, 60 read req/min/user (writes mirror these), as published 2026-06-02.
- Refilled each minute; no daily cap when under the per-minute ceiling.
- A `batchUpdate` counts as **one** request no matter how many sub-requests it carries.
- These numbers move — confirm against Google's current "Usage limits" page before sizing a job.

Implication: collapse N writes into one `batchUpdate`, and back off on 429.

## batchUpdate request shape

```python
service.spreadsheets().batchUpdate(
    spreadsheetId=SID,
    body={"requests": [
        {"updateCells": {  # write a block of values
            "range": {"sheetId": 0, "startRowIndex": 0, "startColumnIndex": 0},
            "rows": [{"values": [{"userEnteredValue": {"stringValue": "order_id"}}]}],
            "fields": "userEnteredValue",
        }},
        {"repeatCell": {  # conditional-style formatting on a range
            "range": {"sheetId": 0, "startRowIndex": 1, "endRowIndex": 100},
            "cell": {"userEnteredFormat": {"backgroundColor": {"red": 0.99, "green": 0.88, "blue": 0.88}}},
            "fields": "userEnteredFormat.backgroundColor",
        }},
    ]},
).execute()
```

## Exponential backoff on 429

```python
import time, random
from googleapiclient.errors import HttpError

def with_backoff(call, tries=5):
    for n in range(tries):
        try:
            return call()
        except HttpError as e:
            if e.resp.status != 429 or n == tries - 1:
                raise
            time.sleep((2 ** n) + random.random())  # 1s, 2s, 4s... + jitter
```

A1 (`Sheet1!A1:C10`) vs R1C1 indices: gspread uses A1 strings; the raw API `GridRange` uses
zero-based `startRowIndex`/`endRowIndex` (end-exclusive). Mixing them off-by-one is a common bug.

## Apps Script V8

Target **V8**: Google deprecated the legacy Rhino runtime (Feb 2025) with retirement set for on or
after 2026-01-31, so never author new code against it. V8 has no `fetch`, no timers, no streams; no ES6
`import/export`; no private `#fields`.

HTTP — use UrlFetchApp:

```javascript
function pull() {
  const res = UrlFetchApp.fetch("https://api.example.com/data", {
    method: "get", muteHttpExceptions: true,
  });
  if (res.getResponseCode() !== 200) throw new Error(res.getContentText());
  return JSON.parse(res.getContentText());
}
// Parallel requests: UrlFetchApp.fetchAll([{url: ...}, {url: ...}]);
```

Batch reads/writes — never per-cell:

```javascript
function fillTotals() {
  const sh = SpreadsheetApp.getActiveSheet();
  const rows = sh.getDataRange().getValues();          // ONE read
  const totals = rows.slice(1).map(r => [r[1] * r[2]]); // qty * price
  sh.getRange(2, 4, totals.length, 1).setValues(totals); // ONE write
}
```

Time-driven trigger (run nightly at 02:00):

```javascript
function install() {
  ScriptApp.newTrigger("fillTotals").timeBased().everyDays(1).atHour(2).create();
}
```

Custom menu (`onOpen` simple trigger):

```javascript
function onOpen() {
  SpreadsheetApp.getUi().createMenu("Ops")
    .addItem("Fill totals", "fillTotals").addToUi();
}
```

For cross-sheet formulas, `SHEET()` (sheet index) and `SHEETS()` (sheet count) have shipped for years
(Excel since 2013; present in Google Sheets) — safe to emit. For richer integrations, check Apps
Script's current advanced-services list rather than assuming a given service exists.
