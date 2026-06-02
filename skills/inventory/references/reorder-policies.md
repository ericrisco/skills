# Reorder point, EOQ, and review mode

Two separate levers, then the schemas your artifacts must match.

## Reorder point (when)

```text
ROP = (avg daily demand × lead-time days) + safety_stock
```

Worked: avg 40/day, LT 9 days, SS 207 (from `safety-stock.md` formula 2):

```text
ROP = 40·9 + 207 = 360 + 207 = 567 units
```

When on-hand drops to 567 you trigger. The 360 covers expected demand during the wait; the 207 covers the variability.

## EOQ (how much)

```text
EOQ = √(2 · D · S / H)
   D = annual demand, S = ordering cost per PO, H = annual holding cost per unit
```

Worked: D = 14,600/yr, S = €45/order, H = €3/unit/yr:

```text
EOQ = √(2 · 14,600 · 45 / 3) = √(1,314,000 / 3) = √438,000 ≈ 662 units/order
```

EOQ is the cost-minimizing order *size*. It is not a trigger and not a max — round it to supplier pack/MOQ, but never wait for on-hand to fall to EOQ before ordering.

## Continuous vs periodic review

| | Continuous (min-max, s,S) | Periodic |
|---|---|---|
| Trigger | on-hand hits ROP `s` | fixed cadence (e.g. weekly) |
| Order to | up to max `S` | up to target level |
| Needs | perpetual stock visibility | only a clock |
| Reaction | fastest | delayed up to one interval |
| Buffer | lead-time exposure only | lead-time **+ review-interval** exposure |
| Best for | A items, live system | B/C items, batched POs |

**Review-interval buffer adjustment.** Periodic review is blind between checks, so it must cover demand over `lead_time + review_interval`. Add to safety stock:

```text
SS_periodic = Z · σ_demand · √(LT + review_interval)
```

A weekly review with a 9-day lead time buffers √16 instead of √9 — about a third more buffer. That extra cash is the price of batching POs; charge it knowingly.

## Policy-table schema (what verify.sh checks)

CSV, one row per SKU. Required columns, exact names:

```text
sku,abc_class,avg_demand,lead_time,safety_stock,reorder_point,order_qty,review_mode
S-101,A,40,9,207,567,662,continuous
S-512,C,12,7,18,102,300,periodic
S-733,A,30,21,140,770,500,ddmrp
```

Invariants verify.sh enforces:
- every column present; no duplicate `sku`.
- `abc_class` non-empty; `review_mode` ∈ {continuous, periodic, ddmrp}.
- `reorder_point >= safety_stock` (ROP sits at or above the buffer).
- `order_qty > 0`.

## Trigger-list schema

CSV. Only SKUs at or below ROP belong here.

```text
sku,on_hand,reorder_point,suggested_order_qty
S-101,540,567,662
S-512,90,102,300
```

Invariants:
- every `sku` exists in the policy table.
- `on_hand <= reorder_point` (no false triggers — a SKU above ROP must not appear).
- `suggested_order_qty > 0`.

Hand this list to `procurement` to raise the actual POs.
