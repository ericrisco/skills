# DDMRP: demand-driven buffers

When a static reorder point keeps whipsawing on erratic demand — you re-tune safety stock every cycle and it is still wrong — replace the fixed point with three buffer zones that recalculate off actual demand.

## The three zones

| Zone | Covers | Sized off |
|---|---|---|
| **Red** | safety / critical protection | lead-time variability + demand variability (the un-skippable floor) |
| **Yellow** | demand coverage over the lead time | average daily usage × decoupled lead time |
| **Green** | the order cycle / order frequency | the larger of: minimum order qty, an order-cycle target, or lead-time × usage |

Top of green = red + yellow + green; that is your "order up to" level. The zones move as average daily usage and lead time change, so you are not hand-editing a number every month.

## The trigger: net flow position

```text
net_flow_position = on_hand + on_order − qualified_demand
```

`qualified_demand` = confirmed/near-term demand (open orders, spikes within the spike horizon). The reorder signal fires when net flow position drops out of green **into the yellow zone** — order enough to bring it back to the top of green.

This differs from a fixed ROP: it nets in on-order and known demand spikes instead of reacting only to on-hand crossing one static line, so it doesn't double-order while a PO is in transit and doesn't ignore a known incoming spike.

## When DDMRP beats a static ROP

Use it only for SKUs that are some combination of:
- **erratic demand** (Z-class, CV > 1) where a stable σ_demand assumption breaks,
- **long lead time** where a misjudged buffer is expensive to unwind,
- **strategic / high value** (the AZ corner) where stockouts genuinely hurt.

Do **not** use it for steady C items — a flat reorder point is cheaper to run and good enough. Set `review_mode = ddmrp` in the policy table for the SKUs you move onto buffer zones; the red zone plays the role of `safety_stock` and the green-trigger level plays the role of `reorder_point` for the verify.sh invariants.
