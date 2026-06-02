# Reference: plans, prices, locations, reliability

Dated figures (post the **2026-04-01 price adjustment**). Hetzner raised most
plan prices on that date — treat exact cents as "verify in the console," use
these as bands for the decision.

## Plan matrix

| Plan | Chip | vCPU / RAM / disk | Price band (post-2026-04-01) | EU-only? | Pick when |
|---|---|---|---|---|---|
| CX23-class | Intel (shared) | 2 / 4 GB / 40 GB | ~€3.99/mo | Yes | Cheapest viable, tiny EU workloads |
| CPX22 | AMD (shared) | 2 / 4 GB / 80 GB | ~€7.99/mo | No | Default app box, best value |
| CPX32 | AMD (shared) | 4 / 8 GB / 160 GB | ~€13.99/mo | No | Mid app + small DB |
| CPX42 | AMD (shared) | 8 / 16 GB / 320 GB | ~€25.49/mo | No | Heavier services |
| CAX (ARM64) | Ampere (shared) | varies | cheapest per-core | Yes | ARM-clean workloads, max cores/€ |
| CCX13 | Dedicated vCPU | 2 / 8 GB | ~€15.99/mo | No | Steady CPU, no noisy-neighbor |

## IPv4 / IPv6 economics

- **IPv4 is a paid add-on:** ~€0.0010/hour, roughly €0.50–0.60/mo per address.
- **IPv6 is free.** An IPv6-only box is cheaper.
- **The catch:** IPv6-only breaks any upstream that isn't dual-stack — several
  container registries, package mirrors, CI runners, and IPv4-only SSH clients.
  Symptom: `docker pull` or `apt update` hangs/fails on a fresh IPv6-only box.
  Keep one IPv4 unless you've confirmed every dependency reaches over IPv6.

## Traffic / locations

- **EU locations include 20 TB/mo egress:** Nuremberg (nbg1), Falkenstein (fsn1),
  Helsinki (hel1). Overage ~€1/TB.
- **US (Ashburn / Hillsboro) and Singapore include far less** transfer — the
  common surprise bill. Choosing US "for latency" can cost more in traffic than
  it saves in milliseconds for egress-heavy apps.
- **No own datacenter in APAC** (Singapore aside). Asian users pay a real latency
  cost; weigh it explicitly rather than assuming a global footprint.

## Reliability trade-offs (name these honestly)

- **No managed-database service.** You run and back up Postgres/MySQL yourself.
- **No formal uptime SLA.** There is no contractual availability guarantee.
- **Support tiers:** phone support is only for dedicated-server customers; Cloud
  is ticket-based.

These are the reasons Hetzner is cheap, not defects to hide. The skill's value is
making the cheap box reproducible and hardened so the trade-offs are the only
thing you're accepting — not also an unhardened, un-monitored host.

## Sources

- hcloud CLI v1.65.0 (2026-05-21): github.com/hetznercloud/cli/releases
- `datacenter` deprecation (removed after 2026-07-01): hcloud CLI release notes
- Price adjustment (2026-04-01): docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/
- Plans/prices/traffic/locations/reliability: betterstack.com Hetzner Cloud review + hetzner.com/cloud
- Firewall layers + cloud-init: community.hetzner.com tutorials

All accessed 2026-06-02.
