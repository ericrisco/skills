# Evals — forecasting

These cases are read by the catalog eval harness, not by a standalone runner here.
`should_trigger` and `should_not_trigger` check routing: each near-miss in
`should_not_trigger` names the real sibling skill it actually belongs to
(`financial-model`, `unit-economics`, `inventory`, `data-cleaning`, `analyze`), so a
correct router sends it there instead of to forecasting. The `capability` case is a
rubric scored by a judge against its `must_include` list — it grades whether a
forecast actually establishes a baseline, backtests with rolling origin, reports
WAPE/bias/MASE, and ships an interval. Separately, run `scripts/verify.sh` to confirm
the pipeline emits a valid artifact (`ds,forecast` plus an interval column, correct
row count, and an accuracy line); that script is read-only against your project and
exits 0 on a clean/empty target.
