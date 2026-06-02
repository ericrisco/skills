# Record cookbook

Per-type reference with the edge cases that bite. Names ending in `.` are fully-qualified; `@` is the zone apex.

## A / AAAA — name to IP

```text
example.com.   300  A     76.76.21.21
example.com.   300  AAAA  2606:4700:3033::6815:1a2b
```

- Publish AAAA only if the origin actually serves IPv6, or you'll hand IPv6 clients a dead address.
- Round-robin (multiple A rows) is crude load distribution, not failover — resolvers pick arbitrarily and don't health-check.

## CNAME — alias one name to another

```text
www.example.com.   3600  CNAME  cname.vercel-dns.com.
```

- **Never at the apex** (RFC 1034 §3.6.2). A CNAME cannot coexist with the SOA/NS that must exist there.
- A CNAME target should resolve to A/AAAA, not chain endlessly. Avoid CNAME-to-CNAME loops.

## ALIAS / ANAME — apex flattening

Vendor names differ (Cloudflare flattening, Netlify ALIAS, Route 53 alias, DNSimple ALIAS). The provider resolves the target to A/AAAA at query time and returns those, so the apex stays spec-legal.

```text
example.com.   300  ALIAS  apex-loadbalancer.netlify.app.
```

- The flattened A/AAAA inherit the *provider's* resolution; if the target changes IP, you don't edit anything.

## MX — mail exchange

```text
example.com.   3600  MX  1   aspmx.l.google.com.
example.com.   3600  MX  5   alt1.aspmx.l.google.com.
```

- The number is **priority**; lower is tried first. Equal priorities load-balance.
- Targets must be hostnames (A/AAAA), **never IPs and never CNAMEs** (RFC 2181).
- An apex with no MX falls back to the A record for mail — usually not what you want.

## TXT — SPF / DKIM / DMARC / verification

```text
example.com.        3600  TXT  "v=spf1 include:_spf.google.com ~all"
default._domainkey  3600  TXT  "v=DKIM1; k=rsa; p=MIGfMA0GCSq...long-key..."
_dmarc              3600  TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
```

- A single TXT string maxes at **255 characters**. Longer values (RSA-2048 DKIM keys) must be split into multiple quoted chunks in one record; the resolver concatenates them: `"chunk1" "chunk2"`.
- **SPF allows at most 10 DNS lookups** when evaluated; each `include`/`a`/`mx`/`redirect` counts. Blow past it and SPF returns `permerror` (treated as fail). Flatten or trim includes.
- One SPF record per domain only — a second `v=spf1` TXT is a permerror.
- The *records* are this skill. Tuning policy, alignment, and reputation is ../email-deliverability/SKILL.md.

## CAA — certificate authority authorization

```text
example.com.   3600  CAA  0 issue     "letsencrypt.org"
example.com.   3600  CAA  0 issuewild "letsencrypt.org"
example.com.   3600  CAA  0 iodef     "mailto:security@example.com"
```

- `issue` gates normal certs; `issuewild` separately gates wildcards; `iodef` is where CAs report violations.
- No CAA record = any CA may issue. A CAA listing only CA-X makes ACME from CA-Y fail with a CAA error (RFC 8659).
- CAA is checked at the apex and walked up; a tight apex policy covers subdomains unless overridden.

## SRV — service location

```text
_sip._tcp.example.com.   3600  SRV  10 5 5060 sip.example.com.
#                                     |  | |    target
#                          priority --+  | +-- port
#                               weight --+
```

- Format: `priority weight port target`. Lower priority first; weight distributes within equal priority.
- Name must be `_service._proto`. Target is a hostname, not an IP.

## NS / SOA — delegation and zone metadata

- The apex's `NS` records name the authoritative servers; the registrar's delegation must match them or queries `SERVFAIL`/go stale.
- `SOA` holds the zone serial and timers. Bump the serial on every edit if you run your own primary, or secondaries won't pull the change.

## PTR / reverse DNS

- PTR lives in the *IP owner's* reverse zone (`x.x.x.x.in-addr.arpa`), set by your hosting provider, not in your forward zone. Mail servers are judged on matching forward/reverse — set it via the host's panel.

## DNSSEC

- DNSSEC signs answers so resolvers can detect tampering. You enable signing at the DNS provider, then publish the resulting **DS record at the registrar** (parent zone) to complete the chain of trust.
- Common failure: enabling signing but forgetting the DS at the registrar (or a stale DS after a key roll) → `SERVFAIL` for validating resolvers. When migrating providers, turn DNSSEC **off**, cut over, then re-enable — a mismatched DS during cutover breaks the whole zone.
