# Price localization (PPP) — mechanics

Depth offloaded from SKILL.md. Most operators skip localization; read this when you actually sell across markets.

## PPP, not spot FX

Convert from purchasing power, not the exchange rate. A spot-FX conversion prices a $99 plan at whatever the dollar buys today in the local currency — which ignores that $99 of purchasing power is very different in São Paulo than in Zurich. PPP-adjusted regional pricing lifts revenue ~30% over straight currency conversion.

```text
local_price = home_list_price x PPP_factor(market)
```

Source the PPP factor from the **World Bank** or **OECD** PPP datasets (the conversion factor for GDP / private consumption). Do not invent factors; cite the table and date you used.

## Per-region rounding

After applying the PPP factor, round to the local price convention — a PPP-derived number like 73.41 is not a price you ship.

| Market | Convention | Example |
|--------|-----------|---------|
| US, DE, AU | charm pricing (.99 / .95) | $99, €99 |
| JP, CN, BR | round numbers preferred | ¥1,200, R$120 |

Charm prices convert well in US/DE/AU; round numbers read as more trustworthy in JP/CN/BR. Match the local norm rather than forcing one global style.

## FX vs PPP — when each

- **PPP** sets the *strategic* local list price (what the plan should cost to feel equivalent).
- **FX** only enters at the *billing* moment if you charge in the buyer's currency — and that is `../stripe/SKILL.md` / `../invoicing/SKILL.md` territory, not a pricing decision. Keep the FX conversion out of the price card.

## Geo-arbitrage guards

Cheaper regional prices invite VPN arbitrage — a buyer in a high-price market routing through a low-price one. Guard with:

- Local **payment-method** checks (a card issued in the claimed region).
- **Billing-address** verification against the region's price.
- Flagging mismatches between IP region and payment/billing region.

Do not rely on IP alone; it is the easiest signal to fake.

## Review cadence

Review regional prices **quarterly to semiannually**. Both PPP factors and FX drift, and a price set 18 months ago can be materially off purchasing power today. Put the review on a recurring calendar, not "when someone complains".

## Sample regional table

```text
home list (US): $99
market   PPP factor   PPP raw   rounded (local convention)
DE       0.85         $84.15    €79  (charm)
BR       0.45         $44.55    R$45 -> R$49 round-ish
JP       0.95         $94.05    ¥1,400 (round)
IN       0.30         $29.70    ₹2,400 (round)
```

Factors above are illustrative — pull live ones from World Bank/OECD before shipping.
