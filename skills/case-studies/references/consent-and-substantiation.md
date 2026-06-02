# Consent & substantiation

The legal floor for any named, quoted, or imaged customer. No consent → anonymize or do not ship.

## Why this is non-negotiable

The FTC Consumer Reviews and Testimonials Rule has been in force since 21 October 2024. It bans fake and insider testimonials and unsubstantiated claims, with penalties up to ~$53,088 per violation (figure effective 17 Jan 2025 — the FTC inflation-adjusts the statutory max every January, so confirm the current number on FTC.gov before quoting it). A testimonial must be a real customer's honest statement; an insider/employee/affiliate endorsement needs a clear-and-conspicuous material-connection disclosure; you cannot publish a metric you cannot substantiate.

## Intake form — fields to capture at the win

Capture this immediately after the customer wins, while the result is fresh.

- **Customer**: company, contact name, title, email.
- **Baseline metric(s)**: the number(s) before, with date.
- **Result metric(s)**: the number(s) after, with date.
- **Timeframe**: the window between baseline and result.
- **Money figure**: revenue/cost impact, only if the customer permits publishing it.
- **Products used**: modules/features in the win.
- **The quote**: their own words, with the source (interview file, email, review).
- **Permissions**: may we publish name? title? company? logo? photo? the dollar figure?
- **Source of every number**: where each metric can be substantiated on demand.

## Consent / release checklist

- [ ] Written consent obtained **before** publishing (email confirmation is enough — keep it).
- [ ] The **exact quote** as it will appear was sent to the customer and approved.
- [ ] Permission scope is explicit: name, title, company, logo, image, dollar figure.
- [ ] Any quote edit for clarity was re-approved by the customer.
- [ ] Every metric has a retained source.
- [ ] Front-matter `consent:` set to `signed` (only then may a named version publish).
- [ ] The consent record is stored where the team can retrieve it later.

## Exact-quote-approval email (wording)

```text
Subject: Quick approval — your quote for our customer story

Hi <Name>,

Thank you again for the results we achieved together. We'd love to feature
<Company> in a customer story. Below is the exact quote we'd publish,
attributed to you as <Title>, <Company>:

  "<the exact quote>"

We'd also like to publish: <name / title / company / logo / the figure $X>.

Could you reply "approved" if this is accurate and you're happy for us to
publish it as written? If you'd like any wording changed, just send the edit
and we'll confirm the final version with you before anything goes live.

Thanks,
<You>
```

A reply of "approved" (or an approved edit) is the record. Retain it.

## Insider / material-connection disclosure

If the speaker is an employee, founder, investor, reseller, or anyone paid or otherwise connected, you may not present them as an ordinary customer. Either drop the quote, or add a clear, conspicuous disclosure adjacent to it:

```text
> "<quote>"
> — <Name>, <Title> (<Name> is an employee of <Company>.)
```

The disclosure must be impossible to miss — same proximity and prominence as the quote, not buried in a footer.

## Substantiation

You may publish a number only if you can point to its source on request. If the data does not exist or the customer will not let you cite it, the number does not appear. A plausible-sounding figure with no backing is exactly what the rule prohibits.

## Anonymization fallback

When consent is `pending` or refused but the result is still worth telling:

- Strip the name, logo, and any identifying detail (exact headcount, named region if it pinpoints them).
- Use a truthful descriptor: "a 200-seat logistics SaaS in Iberia."
- Keep the metrics only if they remain substantiated and non-identifying.
- Set front-matter `consent: anonymized`. Never attach a real name to an anonymized story later without fresh sign-off.
