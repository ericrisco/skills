# Carriers, exception codes, and claim windows

Lookup material offloaded from the spine: the per-carrier exception-code map, the
full claim matrix with required evidence, and runnable EasyPost snippets. All facts
accessed 2026-06-02 (Sifted / ShipperHQ / Goshippo / LateShipment / FedEx / USPS /
ShippingEasy / Cahoot / EasyPost docs).

## Normalize the exception code to one of four buckets

Carriers emit different codes for the same physical event. Map to a bucket, then run
the protocol from the SKILL's EXCEPT table.

| Bucket | Physical event | Typical FedEx wording | Typical UPS wording | Typical USPS wording |
| ------ | -------------- | --------------------- | ------------------- | -------------------- |
| Address / access | Bad, incomplete, or inaccessible address | "Incorrect address", "Customer not available or business closed" | "Address Correction", "The receiver was not available" | "No Access to Delivery Location", "Insufficient Address" |
| Failed attempt | Carrier tried, nobody/access to receive | "Delivery attempted" | "A delivery attempt was made" | "Delivery Attempted - No Access" |
| Weather / operational | Weather, network, mechanical delay | "Local delivery restriction — weather", "Operational delay" | "Adverse weather conditions", "Emergency situations or natural disasters" | "Emergency weather delay", "Processing exception" |
| Damage / loss | Item damaged, lost, or contents missing | "Shipment damaged", "Package handling — damaged" | "This package was damaged in transit" | "Damaged in Transit", "Loss/rifling" |

Rule: never route on the raw string. Two carriers will name "we couldn't deliver"
four different ways — bucket first, then apply the severity clock.

## Full claim-window matrix

Windows vary by **service class** within a carrier; treat these as the governing
defaults and confirm the exact class before relying on a date. Filing late = the
claim is denied and the money is gone.

| Carrier | Claim type | Window | Required evidence |
| ------- | ---------- | ------ | ----------------- |
| USPS | Damage / missing contents | File no later than **60 days** from mailing date | Proof of value (receipt/invoice), evidence of insurance, photos of damage + packaging |
| USPS | Lost | After the service-specific waiting period, within the filing window for the class | Proof of value, proof of insurance, tracking |
| UPS | Damage | Notice within **60 days** of delivery date | Photos of item + packaging, declared value, tracking, label |
| UPS | Lost / undelivered | Within **60 days** of the scheduled delivery date | Proof of value, tracking, label |
| UPS | Guaranteed-service refund | Within **15 days** of the invoice date | The carrier invoice showing the service + late scan |
| FedEx | Damage / missing contents (US) | Within **60 days** of the ship date | Photos of item + packaging, value, weight/dims, tracking, label |
| FedEx | Damage / missing (international) | Within **21 days** of delivery | As above |
| FedEx | Lost / undelivered | Up to **9 months** from ship date | Proof of value, tracking, label |
| FedEx | Guaranteed-service refund | Within **15 days** of the invoice date | Invoice showing the committed service + the missed commitment |

Two clocks run at once on a guaranteed shipment that arrives damaged and late: the
**damage claim** (≈60 days) and the **service-refund claim** (≈15 days from invoice).
The 15-day refund clock is the one operators miss — file it first.

## EasyPost snippets

### Rate-shop + one-call buy

```python
import easypost
client = easypost.EasyPostClient(api_key)

shipment = client.shipment.create(
    to_address={"name": "...", "street1": "...", "city": "...",
                "state": "...", "zip": "...", "country": "US"},
    from_address=from_address,
    parcel={"length": 9.0, "width": 6.0, "height": 3.0, "weight": 12.0},
)

# Restrict to services that meet the promised delivery date upstream, then:
rate = shipment.lowest_rate(carriers=["USPS", "UPS", "FedEx"])
bought = client.shipment.buy(shipment.id, rate=rate)

label_url = bought.postage_label.label_url
tracking_code = bought.tracking_code
tracker = bought.tracker          # status starts at pre_transit
```

### Tracker webhook handler shape (event-driven, not polled)

EasyPost POSTs a `tracker.updated` event each time the parcel's status changes.
Decide the action per status; let `webhooks` own the actual endpoint/retries.

```python
def handle_easypost_event(event):
    if event["description"] != "tracker.updated":
        return
    tracker = event["result"]
    status = tracker["status"]            # in_transit, out_for_delivery, exception, delivered
    if status == "exception":
        bucket = normalize_exception(tracker["status_detail"])  # → one of the four buckets
        route_to_protocol(bucket, tracker)        # severity clock from the EXCEPT table
        notify_customer_proactively(tracker)      # facts only; tone → customer-support
    elif status in ("out_for_delivery", "delivered"):
        notify_customer_proactively(tracker)
```

### Reverse label — same create call, `is_return: true`

```python
return_shipment = client.shipment.create(
    to_address=from_address,    # your warehouse
    from_address=customer_addr, # the customer (to/from swap)
    parcel=parcel,
    is_return=True,
)
return_label = client.shipment.buy(
    return_shipment.id, rate=return_shipment.lowest_rate()
)
# Email return_label.postage_label.label_url to the customer.
```

Carrier coverage for rate-shop breadth: EasyPost ~100+ carriers, Shippo ~85+,
ShipStation ~200+. Choosing/hosting the integration is
`api-connector-builder` / `webhooks`; this skill decides which calls fire when.
