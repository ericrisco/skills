# Compliance footer — wording, matrix, LIA checklist

Every cold send needs a footer that (a) identifies you truthfully, (b) gives a working opt-out, and (c) satisfies the recipient's jurisdiction. Write for the **strictest plausible jurisdiction** the recipient could be in. All figures accessed 2026-06-02.

## Jurisdiction matrix

| | CAN-SPAM (US) | GDPR (EU B2B) | CASL (Canada) | Spam Act (Australia) |
|---|---|---|---|---|
| Legal basis for cold B2B | Truthful + opt-out (no prior consent) | Art. 6(1)(f) legitimate interest **+ documented LIA** | Implied consent (conspicuous publication / existing relationship) — strict | Inferred consent for conspicuously-published business addresses |
| Postal address | **Required**, physical | Identify the controller; address recommended | **Required** | Sender identification required |
| Opt-out window | Within **10 business days** | Without undue delay (**treat 24-48h**) | Honored **without delay**, ≤10 business days | Functional unsubscribe, honored ≤5 business days |
| Penalty | Up to **$53,088 per email** (Jan 2025) | Up to **€20M or 4%** of global revenue | Up to **CA$10M** per violation | Civil penalties per breach |

*(Sources: Instantly compliance guide / Puzzle Inbox; litemail.ai / complydog GDPR cold-email guides 2026; standard CASL / Australian Spam Act 2003 references.)*

## EU country notes (enforcement varies)

- **UK (ICO) / France (CNIL):** relatively permissive for genuine B2B legitimate-interest outreach.
- **Germany:** strict — UWG often treated as requiring prior consent for B2B email; tread carefully.
- **Poland:** frequently requires prior consent even B2B.
- Default: if you cannot confirm the recipient's country, write to the strictest (assume consent-style) and keep the LIA on file.

## Footer wording (drop-in)

```text
You're receiving this because {{the legitimate-interest reason — e.g. "you lead
infra at a team we believe we can help"}}. Not relevant? Reply "stop" or use the
one-click unsubscribe and you won't hear from us again.

{{Company legal name}}
{{Physical postal address — street, city, country}}
Unsubscribe: {{one-click opt-out link}}
```

Notes:
- The `Unsubscribe:` link must be backed by an RFC 8058 one-click header (`List-Unsubscribe` + `List-Unsubscribe-Post`) for bulk Gmail/Yahoo sending. **You specify it must exist and be one-click; wiring the header is `email-deliverability`'s job.**
- "Reply stop" is a fallback, not a substitute for the link.
- Keep the From/Reply-To accurate and the subject honest — a deceptive subject voids CAN-SPAM compliance on its own.

## Legitimate Interest Assessment (LIA) checklist — EU sends

Keep this documented *before* sending to EU recipients:

1. **Purpose test** — is there a genuine business interest (offering a relevant solution to a relevant role)? Name it.
2. **Necessity test** — is cold email a proportionate way to reach this interest, or is there a less intrusive route?
3. **Balancing test** — does your interest override the recipient's privacy expectation? B2B role-based address + relevant offer usually passes; consumer address usually does not.
4. **Data minimization** — you hold only what's needed (name, role, business email, the signal). No scraped personal/sensitive data.
5. **Opt-out honored fast** — 24-48h, suppression list updated, never re-contacted.

If any test fails, do not send — that is a targeting problem to take back to `lead-gen`, not a wording fix.
