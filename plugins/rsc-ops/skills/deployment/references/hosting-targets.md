# Hosting targets — Vercel, Hetzner, and the "always 3 options" framework

Where the container/artifact actually runs. The parent `../SKILL.md` covers the build
(Dockerfile), the pipeline (GitHub Actions), and one self-hosted target (Coolify) in depth.
This chapter is the *hosting decision* layer: the main targets, what each is good and bad
at, and a repeatable method to recommend **exactly three** for any given project.

Facts below were verified June 2026. Pricing and free-tier limits move — re-check the
linked source before quoting a number to a stakeholder; treat figures here as orientation,
not a contract.

```text
requirements ─▶ decision matrix ─▶ pick 3 targets ─▶ trade-offs ─▶ recommend
                                    (1) Hetzner+Coolify  (2) Vercel  (3) the case-fit third
```

---

## Vercel — zero-ops serverless/edge, the Next.js home turf

Vercel is a managed frontend-cloud: you connect a Git repo, every push builds and deploys,
preview URLs appear per PR, and routing/TLS/CDN are handled for you. There is no server to
patch and no OS to own. It is the reference target for **Next.js** (Vercel maintains the
framework) and excellent for any framework that compiles to static assets + serverless/edge
functions.

**What you get out of the box**

- Git-push deploys, immutable deployments, instant rollback (promote a previous deployment).
- Per-PR **preview deployments** with their own URL, isolated from production.
- Global CDN for static assets; functions run on demand — you never size a box.
- Automatic HTTPS, custom domains, and a managed WAF (paid tiers).

**Functions & runtimes (2026)**

- **Vercel Functions** with the **Node.js runtime** is now the recommended path. The older
  standalone **Edge Functions** product is deprecated — prefer Node-runtime functions, which
  have full API support, Fluid Compute, and Active-CPU pricing.
- **Fluid Compute** (default for new projects since Apr 2025) lets one function instance
  handle multiple concurrent invocations and bills **per CPU-second of actual execution** —
  I/O wait time is *not* billed. That makes I/O-bound serverless (DB calls, upstream APIs,
  LLM streaming) much cheaper than classic per-invocation-duration billing.
- **Timeouts:** Hobby serverless functions are capped at 10s. Pro defaults to 15s,
  configurable up to **300s (5 min)**. Edge-runtime responses must start streaming within
  ~25s and may stream up to 300s.

**Regions**

- Node-runtime functions execute in **a single region by default** — Washington, D.C. (`iad1`).
- You can pin a different region or run multi-region, but multi-region compute only helps if
  your **data is also replicated** to those regions; otherwise you just add a cross-region DB
  hop. Static/CDN assets are global regardless.

**Plans & cost shape (2026)**

| Plan | Price | Shape |
| --- | --- | --- |
| Hobby | Free | Personal, **non-commercial only**. ~100 GB transfer, 1M function invocations, limited CPU/memory hours. 10s function cap. |
| Pro | $20 / user / mo | Includes $20 usage credit; overages bill against the credit, then per-unit. ~1 TB Fast Data Transfer, 10M edge requests. Commercial use, team seats, Fluid Compute, 300s functions. |
| Enterprise | Custom (commonly ~$45k+/yr) | 99.99% SLA, isolated infra, managed WAF, SCIM/SSO, HIPAA/SOC2/PCI attestations, multi-region with failover. |

**Where Vercel wins**

- Next.js (or any static-front + serverless-API) app where you want **zero ops**.
- **Spiky / unpredictable traffic** — scales to zero and back, you pay for what runs.
- Small teams that value preview URLs and ship velocity over infra control.

**Where Vercel hurts**

- **Cost at scale / sustained traffic.** Metered transfer + Active CPU can dwarf a flat-rate
  VPS once you have steady high traffic; this is the canonical reason teams migrate off.
- **Always-on / long-running** workloads (queues, websockets held open, heavy background
  jobs, big batch) fight the serverless model — function timeouts and per-second compute bite.
- **Data residency:** default `iad1` is US. EU-only residency needs region pinning *and* an
  EU data store, and the platform itself is US-headquartered — check compliance requirements.
- **Stateful services** (your own Postgres/Redis) don't live here; you attach a managed DB
  elsewhere and pay egress.

Source: [Vercel pricing](https://vercel.com/pricing) · [Vercel Functions](https://vercel.com/docs/functions) · [Fluid Compute](https://vercel.com/docs/fluid-compute)

---

## Hetzner — cheapest control, a VPS you own (run Coolify on it for self-hosted PaaS)

Hetzner is a German cloud/dedicated-server provider known for the best price/performance in
the market. You get a real Linux box (or a dedicated machine) at a flat monthly price with a
huge bandwidth allowance. It is the opposite trade-off from Vercel: **you own ops, and in
exchange you get full control and the lowest cost at scale.**

**Cloud VPS families (2026)**

| Family | CPU | Best for | Notes |
| --- | --- | --- | --- |
| **CX** | Shared Intel/AMD | Dev, test, cheapest x86 | EU-only locations |
| **CPX** | Shared AMD EPYC | General production | Global (incl. US, Singapore) |
| **CAX** | Shared **ARM** (Ampere Altra) | Best raw value; containers built multi-arch | Lowest prices in lineup |
| **CCX** | **Dedicated** AMD EPYC vCPU | Production DBs, CI, latency-consistent | No noisy neighbour |

Indicative entry pricing (post Apr-2026 adjustment, re-verify): **CX22** (2 vCPU / 4 GB /
40 GB) ~€4.49/mo; **CAX11** (2 ARM vCPU / 4 GB) ~€3.79/mo; **CPX22** ~€7.99/mo. Cloud plans
include a generous bandwidth allowance (~20 TB on EU regions) — egress that would cost a
fortune on hyperscalers is effectively free here.

**Regions**

- EU data-center parks: **Falkenstein**, **Nuremberg**, **Helsinki**.
- North America: **Ashburn, VA** and **Hillsboro, OR** (cloud products only — no dedicated
  root servers there).
- Asia: **Singapore** (cloud only, since 2024).
- EU regions are the natural fit for **EU data residency / GDPR** stories.

**Backups & disaster recovery**

- **Backups:** automatic daily disk copies, 7 rolling slots, priced as a percentage of the
  server cost (typically ~20%). Tied to the server — deleted with it.
- **Snapshots:** manual point-in-time disk images, billed by size; **survive server deletion**
  and are stored across locations — the right tool for pre-deploy safety points and DR.
- Neither captures **attached Volumes** — back those up separately.

**Coolify on Hetzner = self-hosted PaaS (the recommended combo)**

Hetzner gives you the box; [Coolify](./coolify.md) gives you the Heroku/Vercel-style DX on
top of it — push-to-deploy, preview URLs, automatic Let's Encrypt TLS, managed databases —
with **no per-seat or per-build fees**. This pairing is the workhorse default of the "3
options" framework below.

- **Minimum for Coolify:** 2 vCPU / 2 GB / 20+ GB. Comfortable real-world start: **CPX21/CPX22**
  (3 vCPU / 4 GB, ~€8/mo) comfortably runs 3–5 small/medium apps plus a managed Postgres.
- Install via Hetzner Console / Cloud API (one-click app or `cpx22` server type), or the
  Coolify install script on a fresh Ubuntu box.
- Once installed, everything in [`./coolify.md`](./coolify.md) applies: build packs, secrets,
  volumes, healthchecks, rolling/blue-green, rollback. **Cross-link, don't duplicate.**

**Where Hetzner (+Coolify) wins**

- **Cost-sensitive at any sustained scale** — flat monthly price, fat bandwidth, no metering.
- **EU data residency** with a clean, simple story (EU-owned, EU regions).
- **Always-on / stateful** workloads: your own Postgres, Redis, queues, websockets, cron,
  background workers — all first-class on a box you control.
- You want one platform hosting *many* projects cheaply (Coolify multi-app).

**Where Hetzner hurts**

- **You own ops:** OS patching, the Coolify upgrade, backups verification, capacity planning,
  incident response. No managed SLA — uptime is your job.
- **No scale-to-zero** and **no instant global edge**; a single box is a single region.
  Multi-region means multiple servers you orchestrate.
- Vertical scaling needs a resize/reboot; horizontal scaling is manual (more servers + a load
  balancer) rather than automatic.

Source: [Hetzner Cloud](https://www.hetzner.com/cloud) · [Hetzner locations](https://docs.hetzner.com/cloud/general/locations/) · [Backups/Snapshots](https://docs.hetzner.com/cloud/servers/backups-snapshots/overview/) · [Coolify on Hetzner](https://docs.hetzner.com/cloud/apps/list/coolify/)

---

## Coolify — already covered

The self-hosted PaaS layer (build packs, env/secrets, volumes, SSL, previews, rolling vs
blue-green, rollback, deploy API) lives in **[`./coolify.md`](./coolify.md)**. On Hetzner it
is the recommended way to get Vercel-like DX on infrastructure you own. Don't re-derive it
here.

---

## The "third option" pool — brief

When Hetzner+Coolify and Vercel are options 1 and 2, the **third** should fit the specific
case. Common picks:

| Target | One-liner | Pick it when |
| --- | --- | --- |
| **Railway** | Usage-based PaaS, fastest code→prod, minimal config | Side projects / early startups wanting zero DevOps and predictable small bills; ~4 regions, fine for single-region apps. |
| **Fly.io** | Machines billed by compute/uptime, **30+ global regions** | You need true global edge / low latency in many regions, GPU, or fine-grained machine control. Free allowance ~$5/mo compute. |
| **Managed cloud (AWS/GCP/Azure)** | Hyperscaler breadth + compliance | Enterprise compliance, deep managed-service needs, existing org commitment — at the cost of complexity and egress fees. |
| **Cloudflare (Pages/Workers)** | Edge-first, generous free tier | Edge-heavy static + lightweight Workers logic, aggressive global caching. |
| **Render / Netlify** | Vercel-like managed PaaS | Non-Next static/JAMstack (Netlify) or simple containers/web services (Render) when you don't want Vercel lock-in. |

Fly.io vs Railway crossover: below ~3 services with real traffic, **Railway's predictability
usually wins**; above it, **Fly.io's per-machine control yields better cost-per-request** and
real multi-region.

Source: [Fly.io pricing](https://fly.io/pricing/) · [Railway vs Fly](https://docs.railway.com/platform/compare-to-fly)

---

## Decision matrix

Score the project on these axes, then read across.

| Axis | Pulls toward Vercel | Pulls toward Hetzner+Coolify | Pulls toward 3rd option |
| --- | --- | --- | --- |
| **Traffic shape** | Spiky / bursty / scale-to-zero | Steady / sustained / always-on | Global edge latency → Fly.io |
| **Scale (users)** | Low–mid, unpredictable | Mid–high, predictable | Tiny side project → Railway |
| **Budget** | OK paying premium for zero-ops | Cost-sensitive, flat rate | Smallest fixed bill → Railway |
| **Stack** | Next.js / static + serverless | Anything; needs own DB/queue/ws | Edge Workers → Cloudflare |
| **Ops comfort** | None — don't want a server | Comfortable owning a Linux box | Some, but want managed → Railway/Render |
| **Data residency** | US-default (region-pin + EU DB to comply) | EU-native (Falkenstein/Nuremberg/Helsinki) | Hyperscaler EU regions → AWS/GCP |
| **Stateful services** | External managed DB only | First-class on the box | Managed DB add-ons → Railway |
| **Compliance/SLA** | Enterprise tier (HIPAA/SOC2, 99.99%) | DIY, no SLA | Hyperscaler attestations → AWS |

**Rule of thumb:** if the app is Next.js with bursty traffic and the team hates ops → Vercel.
If it's cost-sensitive, EU-resident, sustained traffic, or needs its own stateful services →
Hetzner+Coolify. The third option breaks the tie on the case's sharpest constraint (global
latency, tiniest bill, or enterprise compliance).

---

## The "always 3 options" framework

Never hand a stakeholder a single answer. **Gather requirements, then recommend exactly three
targets with explicit trade-offs** so they choose with eyes open.

**Step 1 — gather requirements (ask, don't assume):**

1. Expected **total users** and **concurrent users** (order of magnitude is enough).
2. **Traffic shape:** steady, daily-cyclic, or spiky/unpredictable?
3. **Budget:** hard monthly ceiling? Premium for zero-ops acceptable?
4. **Data region / residency:** any GDPR/EU-only or US-only constraint? Compliance (HIPAA/SOC2)?
5. **Team ops comfort:** happy owning a Linux box, or "no servers, ever"?
6. **Scaling needs:** scale-to-zero? global low latency? horizontal autoscale?
7. **Stateful needs:** own Postgres/Redis/queue/websockets/cron, or stateless front + managed DB?

**Step 2 — recommend exactly three.** Canonical slate, adapt the third to the case:

1. **Hetzner VPS + Coolify** — lowest cost at scale, full control, EU residency, owns ops.
2. **Vercel** — zero-ops, ideal for Next.js and spiky traffic, premium metered cost.
3. **A third that fits the sharpest constraint** — Railway (tiny/simple), Fly.io (global edge),
   or a hyperscaler (enterprise compliance).

**Step 3 — for each, state the trade-off in one line** (cost vs ops vs scale vs residency) and
name the **recommended default** for *this* project, plus the migration escape hatch (e.g.
"start on Vercel, the Dockerfile means you can move to Hetzner+Coolify if the bill grows").

### Worked examples

**A. Side project, <1k users, hobbyist budget, solo dev, no residency constraint**

1. **Hetzner CX22/CAX11 + Coolify** (~€4–5/mo) — flat, cheap, room to host several side
   projects on one box; you own a little ops. *Recommended if you'll host more than one app.*
2. **Railway Hobby** ($5/mo) — fastest code→prod, zero DevOps, predictable small bill.
   *Recommended if you want literally no server to think about.*
3. **Vercel Hobby** (free, non-commercial) — if it's a Next.js/static personal site with no
   commercial use. *Escape hatch: move to Pro or Hetzner when it goes commercial.*

**B. Next.js SaaS, spiky launch traffic, small team that hates ops, US-first**

1. **Vercel Pro** — *recommended default.* Native Next.js, preview URLs, scale-to-zero absorbs
   spikes, Fluid Compute keeps I/O-bound API cost sane. Trade-off: metered cost can climb.
2. **Hetzner CPX + Coolify** — the migration target once traffic is steady and the Vercel bill
   stops making sense; same Dockerfile, flat cost, but you take on ops.
3. **Fly.io** — if users are globally distributed and you need low latency in many regions
   before you'd outgrow Vercel.

**C. EU data-residency, cost-sensitive, sustained ~50k users, comfortable with ops**

1. **Hetzner (CPX/CCX in Falkenstein/Helsinki) + Coolify** — *recommended default.* EU-native
   residency, flat predictable cost at this scale, fat bandwidth allowance, your own Postgres
   on a CCX dedicated-vCPU box. Trade-off: you own patching, backups, and uptime (use
   snapshots + daily backups; consider a second box for HA).
2. **Vercel Enterprise** — only if zero-ops + 99.99% SLA + compliance attestations outweigh the
   large cost premium and you can pin EU regions with an EU data store.
3. **Managed cloud (AWS/GCP, EU region)** — if you need specific managed services or contractual
   compliance beyond what a self-hosted box provides, accepting more complexity and egress cost.

---

## See also

- `../SKILL.md` — Dockerfile, GitHub Actions, secrets flow; the artifact every target consumes.
- `./coolify.md` — the self-hosted PaaS layer that runs on Hetzner (build packs, secrets,
  volumes, SSL, rolling/blue-green, rollback, deploy API).
- `./github-actions.md` — CI builds/pushes the image; OIDC-to-cloud handshake for hyperscalers.
- `./dockerfiles-by-stack.md` — the per-stack images you deploy to any of these targets.
