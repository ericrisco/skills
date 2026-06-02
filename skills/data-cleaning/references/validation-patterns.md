# Validation patterns — pandera, GX Core, dbt

The gate is what makes cleaned data *trustworthy*: it asserts the contract holds and fails loud when next
month's file drifts. Pick the lightest tool that covers your blast radius.

## Which validator

| Situation | Use | Why |
| --- | --- | --- |
| One pipeline, validate a DataFrame in Python | **pandera** | Lightweight, in-process, lives next to `clean()`; pin `pandera==0.31.1` (supports pandas ≥ 3) |
| Many datasets/teams, shared data-quality platform, results store + docs | **GX Core 1.0** | Heavier; Data Context / Suites / Checkpoints are infrastructure, overkill for one script |
| Cleaning lives in a SQL warehouse, not Python | **dbt** model contracts + tests | Contract enforced at build; tests run post-materialization |

Default to pandera. Escalate only when the heavier tool's features are actually needed.

## Pandera — the full DataFrameModel

```python
import pandera.pandas as pa
from pandera.typing import Series

class CustomerSchema(pa.DataFrameModel):
    customer_id: Series[int]   = pa.Field(unique=True, ge=1)
    country:     Series[str]   = pa.Field(isin=["US", "ES", "FR"])
    age:         Series[float] = pa.Field(ge=0, le=120, nullable=True)
    email:       Series[str]   = pa.Field(str_matches=r"^[^@\s]+@[^@\s]+\.[^@\s]+$", nullable=True)
    signup:      Series[pa.DateTime] = pa.Field(nullable=False)

    class Config:
        strict = True        # reject unexpected columns — schema drift fails the build
        coerce = True        # coerce to declared dtype; raise if a value can't be coerced
        ordered = False      # set True if column order is part of the contract

    @pa.check("email", name="lowercase_email")
    def email_is_lower(cls, s: Series[str]) -> Series[bool]:
        # custom row-wise check: returns a boolean Series, one per row
        return s.isna() | (s == s.str.lower())

    @pa.dataframe_check
    def row_budget(cls, df) -> bool:
        # whole-frame invariant: catch a truncated/exploded extract
        return 1 <= len(df) <= 5_000_000
```

`coerce` fixes types the contract expects. `nullable` declares which columns may hold NA. Field checks
(`ge`, `le`, `isin`, `unique`, `str_matches`) are allowed-value rules. `@pa.check` is a custom column
check; `@pa.dataframe_check` is a whole-frame invariant.

## Lazy errors + the quarantine split

`lazy=True` collects **every** violation across the frame instead of dying on the first. Use it to split
valid rows from failing rows — the failures become the quarantine, never a silent drop.

```python
def validate_and_split(df, schema):
    """Return (valid_df, quarantine_df). Quarantine is kept, never discarded."""
    try:
        valid = schema.validate(df, lazy=True)
        return valid, df.iloc[0:0].copy()          # empty quarantine — everything passed
    except pa.errors.SchemaErrors as e:
        # failure_cases columns: schema_context, column, check, failure_case, index
        bad_idx = e.failure_cases["index"].dropna().unique()
        quarantine = df.loc[df.index.isin(bad_idx)].copy()
        quarantine["_failed_checks"] = (
            e.failure_cases.dropna(subset=["index"])
             .groupby("index")["check"].agg(lambda c: "; ".join(map(str, c)))
        )
        valid = df.loc[~df.index.isin(bad_idx)]
        return valid, quarantine

valid, quarantine = validate_and_split(df, CustomerSchema)
quarantine.to_parquet("quarantine.parquet")        # someone investigates these
print(f"valid={len(valid)} quarantined={len(quarantine)}")   # the audit diff
```

Validate **output** always. Validate **input expectations** too when you can state them (e.g. raw must have
these columns before you start) — it turns a confusing mid-pipeline crash into a clear "the source changed".

## GX Core 1.0 — checkpoint sketch

GX rebranded its OSS to **GX Core** and shipped 1.0 GA with a simplified API. Reach for it when validation
is a shared platform across many datasets, not a single script.

```python
import great_expectations as gx

context = gx.get_context()                                   # Data Context
ds  = context.data_sources.add_pandas("customers_src")       # Data Source
asset = ds.add_dataframe_asset(name="customers")
batch = asset.add_batch_definition_whole_dataframe("batch")

suite = context.suites.add(gx.ExpectationSuite(name="customers_suite"))
suite.add_expectation(gx.expectations.ExpectColumnValuesToBeBetween(column="age", min_value=0, max_value=120))
suite.add_expectation(gx.expectations.ExpectColumnValuesToBeInSet(column="country", value_set=["US", "ES", "FR"]))

vd = context.validation_definitions.add(
    gx.ValidationDefinition(name="customers_vd", data=batch, suite=suite)
)
checkpoint = context.checkpoints.add(gx.Checkpoint(name="customers_cp", validation_definitions=[vd]))
result = checkpoint.run(batch_parameters={"dataframe": df})
assert result.success, "GX checkpoint failed — see Data Docs"
```

The flow is always **Data Context → Data Source → Expectation Suite → Validation Definition → Checkpoint**.
You get a results store and generated Data Docs — worth the weight only when many people consume them.

## dbt — contracts vs tests (cleaning in the warehouse)

When cleaning is SQL in a warehouse, the contract lives in the model's YAML. **Contracts** are enforced at
*build* (the model fails to build if the output is off-contract). **Tests** validate *after*
materialization.

```yaml
# models/staging/_stg_customers.yml
models:
  - name: stg_customers
    config:
      contract: { enforced: true }          # build fails if columns/types drift — the contract
    columns:
      - name: customer_id
        data_type: bigint
        constraints: [{ type: not_null }, { type: unique }]
      - name: country
        data_type: varchar
        data_tests:                          # validated post-materialization — the tests
          - accepted_values: { values: ["US", "ES", "FR"] }
      - name: age
        data_type: integer
        data_tests:
          - dbt_utils.accepted_range: { min_value: 0, max_value: 120 }
```

Contract = "this shape is guaranteed at build"; tests = "these values held after the run". Use both: the
contract stops schema drift, the tests catch data drift.
