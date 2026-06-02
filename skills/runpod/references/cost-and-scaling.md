# Cost & scaling

Full pricing and the math behind the SKILL.md "Cost control" section. All figures dated
**2026-06-02**; Community Cloud runs lower than Secure Cloud, so treat these as upper bounds.
Always reprice against https://www.runpod.io/pricing before committing.

## Pod pricing (per hour)

| GPU | VRAM | ~$/hr |
| --- | --- | --- |
| H100 SXM | 80GB | $3.29 |
| H100 PCIe | 80GB | $2.89 |
| A100 80GB PCIe | 80GB | $1.39 |
| L40S | 48GB | $0.86 |
| RTX 4090 | 24GB | $0.69 |
| A40 | 48GB | $0.44 |
| L4 | 24GB | $0.39 |

## Serverless pricing (per-hour equivalent, billed per second rounded up)

Billed only while a worker is active, from start to full stop. Roughly 2-3x the pod rate.

| GPU | VRAM | ~$/hr equiv |
| --- | --- | --- |
| H100 | 80GB | $4.18 |
| A100 | 80GB | $2.72 |
| L40 / L40S | 48GB | $1.90 |
| RTX 4090 | 24GB | $1.10 |
| L4 / A5000 / RTX 3090 | 24GB | $0.69 |

## Storage pricing

| Storage | ~$/GB/mo |
| --- | --- |
| Container disk | $0.10 |
| Network volume, standard, under 1TB | $0.07 |
| Network volume, standard, over 1TB | $0.05 |
| Network volume, high-performance | $0.14 |
| Pod volume disk, running | $0.10 |
| Pod volume disk, idle (stopped pod) | $0.20 |

The idle rate is **double** the running rate. A volume left on a stopped pod is a silent
leak. Network volumes also lock the endpoint/pod to a single data center, shrinking GPU
availability and adding network latency.

## Active vs flex math

- **Flex workers** spin up on demand → cold start, but bill nothing while idle. Best when
  traffic has real gaps.
- **Active workers** stay always-warm → zero cold start, but bill every second 24/7 at a
  **~40% discount** vs the flex rate.

Break-even intuition: an active worker pays off versus flex only when it would otherwise be
spun up often enough that paying the discounted always-warm rate beats paying flex's
per-request seconds plus idle-timeout tails. For genuinely bursty traffic, flex + FlashBoot
almost always wins.

## Worked monthly scenarios

Assume RTX 4090: pod $0.69/hr, serverless $1.10/hr equiv.

1. **Bursty inference, 100k req/day, 2s each, business hours.**
   ~55.5 GPU-hours/day of real work → ~$61/day on flex serverless plus small idle-timeout
   tails. A 24/7 pod is ~$497/mo flat. With work concentrated in ~8 hours, **flex wins** —
   you do not pay for the 16 idle hours.

2. **Steady 24/7 inference at high utilization.**
   If the GPU is busy >60% of every hour, the serverless 2-3x premium overtakes a flat pod.
   **A dedicated Pod (~$497/mo) wins.** If a latency SLA forbids cold starts but utilization
   is moderate, active serverless (40% off flex) is the middle ground.

3. **Fine-tuning, single 6-hour run, A100 80GB.**
   ~6 × $1.39 = ~$8.34 on a Pod. On serverless the 600s default execution timeout would kill
   the job outright, and the premium rate makes it pointless. **Pod, always.**

## Scaling strategy knobs

Endpoints scale workers up by one of two scalers:

- **Queue Delay** — add a worker when requests wait longer than a threshold. Smooths latency.
- **Request Count** — add a worker per N queued requests. Predictable throughput scaling.

Always pair either with **Max Workers ~20% above expected peak** as the hard cost ceiling,
and **Active Workers** only when an SLA forbids cold starts. Enable **FlashBoot** on flex to
make scale-from-zero cheap.
