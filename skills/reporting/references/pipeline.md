# reporting — full worked pipeline

The four layers end to end: **fetch → narrate → render → deliver**, plus schedule and reliability
gate. Pinned stack as of 2026-06-02: `pandas`, `Jinja2`, `WeasyPrint==68.1`, `Matplotlib`. Re-check
PyPI and pin what you resolve.

```text
report/
  templates/report.html.j2     # one template, scoped by params
  metrics.csv                  # the agreed source (owned by the data team)
  render.py                    # fetch → narrate → render
  deliver.py                   # render → deliver (calls email-connector / google-workspace)
  recipients.yaml              # per-recipient params, NOT forked templates
  requirements.txt             # pandas, jinja2, weasyprint==68.1, matplotlib, pyyaml
  .github/workflows/report.yml # the schedule (zero-infra option)
```

## 1. The Jinja2 template skeleton

```html
<!-- templates/report.html.j2 -->
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
  @page { size: A4; margin: 18mm; }
  body { font: 11pt/1.45 "Helvetica Neue", Arial, sans-serif; color: #1a1a1a; }
  h1 { font-size: 20pt; margin: 0 0 2mm; }
  .summary { background: #f4f6f8; border-left: 4px solid #2563eb; padding: 4mm 5mm; }
  table { width: 100%; border-collapse: collapse; margin-top: 6mm; font-size: 10pt; }
  th, td { text-align: left; padding: 2mm 3mm; border-bottom: 1px solid #e2e8f0; }
  .delta-up { color: #15803d; } .delta-down { color: #b91c1c; }
</style>
</head>
<body>
  <h1>{{ title }}</h1>
  <p><strong>Period:</strong> {{ period }}</p>

  <section class="summary">
    <h2>Executive summary</h2>
    <p>{{ summary }}</p>
    <ul>{% for t in takeaways %}<li>{{ t }}</li>{% endfor %}</ul>
  </section>

  {% if chart_b64 %}<img src="data:image/png;base64,{{ chart_b64 }}" style="width:100%">{% endif %}

  <table>
    <thead><tr><th>Week</th><th>Revenue</th><th>WoW</th></tr></thead>
    <tbody>
      {% for r in rows %}
      <tr>
        <td>{{ r.week }}</td><td>€{{ "{:,.0f}".format(r.revenue) }}</td>
        <td class="{{ 'delta-up' if r.wow >= 0 else 'delta-down' }}">{{ "%+.1f"|format(r.wow) }}%</td>
      </tr>
      {% endfor %}
    </tbody>
  </table>
</body>
</html>
```

## 2. Render: fetch → narrate → render (WeasyPrint pinned)

```python
# render.py
import base64, io
import pandas as pd
import matplotlib
matplotlib.use("Agg")                      # headless: no display needed in CI
import matplotlib.pyplot as plt
from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML                 # WeasyPrint==68.1

def chart_png_b64(df: pd.DataFrame) -> str:
    fig, ax = plt.subplots(figsize=(8, 2.6))
    ax.plot(df["week"], df["revenue"], marker="o")
    ax.set_title("Revenue by week"); ax.grid(True, alpha=0.3)
    peak = df["revenue"].idxmax()           # annotate the anomaly, don't ship a bare chart
    ax.annotate("peak", (df["week"][peak], df["revenue"][peak]),
                textcoords="offset points", xytext=(0, 8))
    buf = io.BytesIO(); fig.savefig(buf, format="png", bbox_inches="tight", dpi=130)
    plt.close(fig)
    return base64.b64encode(buf.getvalue()).decode()

def narrate(cur: float, prev: float) -> tuple[str, list[str]]:
    delta = (cur - prev) / prev * 100
    flag = " — investigate" if abs(delta) >= 20 else ""
    summary = (f"Revenue {'up' if delta >= 0 else 'down'} {abs(delta):.1f}% WoW "
               f"(€{cur:,.0f} from €{prev:,.0f}){flag}.")
    takeaways = [summary, "Pipeline coverage holding at 3.1x.", "No SLA breaches this period."]
    return summary, takeaways

def build_pdf(df: pd.DataFrame, params: dict) -> bytes:
    df = df[df["region"] == params["region"]].reset_index(drop=True)
    df["wow"] = df["revenue"].pct_change() * 100
    cur, prev = df["revenue"].iloc[-1], df["revenue"].iloc[-2]
    summary, takeaways = narrate(cur, prev)
    env = Environment(loader=FileSystemLoader("templates"), autoescape=True)
    html = env.get_template("report.html.j2").render(
        title=f'{params["region"]} weekly revenue', period=params["period"],
        summary=summary, takeaways=takeaways, chart_b64=chart_png_b64(df),
        rows=df.tail(8).to_dict("records"),
    )
    return HTML(string=html).write_pdf()     # 68.1: stable A4/@page CSS
```

## 3. Per-recipient parameterization (one template, many scopes)

```yaml
# recipients.yaml — same template, audience-scoped params
- email: emea-lead@acme.com
  region: EMEA
  period: "2026-W22"
- email: amer-lead@acme.com
  region: AMER
  period: "2026-W22"
```

```python
# deliver.py — render once per recipient, hand the bytes to email-connector
import yaml, pandas as pd
from render import build_pdf
# from email_connector import send  # transport is email-connector's job, not this skill's

def main():
    df = pd.read_csv("metrics.csv", parse_dates=["updated_at"])
    freshness_gate(df, period="2026-W22")            # see §5 — refuse stale before any send
    for r in yaml.safe_load(open("recipients.yaml")):
        pdf = build_pdf(df, r)
        assert pdf and len(pdf) > 1024, "empty PDF — refusing to send"
        # send(to=r["email"], subject=f'Weekly revenue — {r["region"]}',
        #      body="Your weekly report is attached.", attachments=[("report.pdf", pdf)])

if __name__ == "__main__":
    main()
```

## 4. Schedule

**cron** (you already run a host):

```cron
# /etc/cron.d/weekly-revenue — Mondays 08:00, log everything, owner gets stderr by mail
0 8 * * 1 reportbot cd /opt/report && python deliver.py >> /var/log/report.log 2>&1
```

**GitHub Actions** (zero infra — the recommended cloud option):

```yaml
# .github/workflows/report.yml
name: weekly-revenue-report
on:
  schedule:
    - cron: "0 6 * * 1"        # 06:00 UTC ≈ 08:00 Europe/Madrid; cron here is always UTC
  workflow_dispatch: {}        # manual re-run for testing
jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r requirements.txt   # weasyprint==68.1 pinned here
      - run: sudo apt-get update && sudo apt-get install -y libpango-1.0-0 libpangoft2-1.0-0
      - run: python deliver.py
        env:
          SMTP_TOKEN: ${{ secrets.SMTP_TOKEN }}   # transport secret, owned by email-connector
```

Note: GitHub Actions `schedule:` cron is **UTC only** and may lag a few minutes under load — never
schedule a report to the exact minute it is "due"; give it slack.

## 5. Reliability gate

```python
# freshness + fail-loud. A report that ships stale numbers is worse than one that doesn't ship.
from datetime import datetime, timedelta, timezone

def freshness_gate(df, period: str, max_age_hours: int = 26):
    latest = df["updated_at"].max()
    if latest.tzinfo is None:
        latest = latest.tz_localize("UTC")
    age = datetime.now(timezone.utc) - latest.to_pydatetime()
    if age > timedelta(hours=max_age_hours):
        raise RuntimeError(
            f"STALE SOURCE: newest row is {age} old (> {max_age_hours}h) for {period}. "
            f"Refusing to send. Page the source owner — do NOT clean the data here (data-cleaning)."
        )
```

```python
# Wrap the whole run so a failure pages the owner instead of failing silently.
import sys, traceback
def run_guarded(fn, owner_alert):
    try:
        fn()
    except Exception as exc:           # noqa: BLE001 — we want everything
        owner_alert(f"REPORT FAILED: {exc}\n{traceback.format_exc()}")
        sys.exit(1)                    # non-zero so the scheduler also flags it
```

**Dead-report cleanup:** if delivery telemetry shows the last N editions went unopened, stop the
schedule and notify the owner. An unread recurring report is pure cost and inbox noise — killing it is
part of owning the report, not a failure.

## Boundary reminders

- The **transport** (SMTP/Gmail/Drive upload) is [`email-connector`](../../email-connector/SKILL.md)
  / [`google-workspace`](../../google-workspace/SKILL.md) — this pipeline calls it, never reimplements it.
- **Spreadsheet output** for analysts → [`spreadsheet-ops`](../../spreadsheet-ops/SKILL.md).
- **Notion / living-doc destination** → [`notion-connector`](../../notion-connector/SKILL.md).
- **Generic multi-step job wiring** beyond the report → [`automation-flows`](../../automation-flows/SKILL.md).
