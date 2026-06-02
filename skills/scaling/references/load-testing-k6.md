# Load testing with k6

The full hands-on companion to Lever 4 in `../SKILL.md`. k6 is a load generator: you write a JS test, k6 spins up *virtual users* (VUs) that run it in a loop, and it reports latency distribution, throughput, and error rate against the **thresholds** you declared. k6 hit v1.0.0 on 2025-04-28 (SemVer); the current v1 line is v1.7.x and v2.0.0 shipped May 2026.

## Install

```bash
brew install k6                  # macOS
docker run --rm -i grafana/k6 run - <script.js   # containerized, no local install
# linux: see grafana.com/docs/k6 for the apt/yum repo
```

Verify with `k6 version`.

## The mental model: VU, iteration, stage

- **VU (virtual user):** one concurrent worker running the default function in a loop. 50 VUs ≈ 50 users hammering at once.
- **Iteration:** one full pass through `export default function`. `sleep()` inside it models think-time between user actions — without it each VU loops as fast as the machine allows, which is unrealistic.
- **Stage:** a `{ duration, target }` step that ramps VUs up, holds, or ramps down. Stages chained together shape the load profile.

VUs are *not* requests-per-second. RPS is an emergent result of `VUs × (1 / iteration_time)`. If you need an exact RPS, use the `constant-arrival-rate` executor (below) instead of VU stages.

## Thresholds = the SLO gate

Thresholds turn a test into pass/fail. The process exits non-zero when any threshold is breached — that is what lets CI fail the build.

```javascript
export const options = {
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1500'], // tail latency budget
    http_req_failed: ['rate<0.01'],                  // <1% errors
    http_reqs: ['rate>200'],                         // sustained throughput floor
  },
};
```

Note: in Grafana Cloud, thresholds are evaluated every 60 s, so `abortOnFail` can lag up to a minute — fine for CI gating on the final summary, relevant only if you depend on instant aborts.

## The test-type ladder

Run these in order; each answers a different question. Same script, different `stages`.

```javascript
// SMOKE — does the script work and the system respond at all? (run this first, always)
stages: [{ duration: '1m', target: 2 }]

// LOAD — does it hold the expected steady-state traffic within SLO?
stages: [
  { duration: '2m', target: 100 },   // ramp
  { duration: '5m', target: 100 },   // hold at expected peak
  { duration: '2m', target: 0 },
]

// STRESS — where is the knee? push past expected until latency goes vertical.
stages: [
  { duration: '2m', target: 200 },
  { duration: '5m', target: 200 },
  { duration: '2m', target: 400 },
  { duration: '5m', target: 400 },
  { duration: '2m', target: 0 },
]

// SPIKE — survive a sudden surge (Product Hunt / Reddit hug) and recover?
stages: [
  { duration: '10s', target: 500 },  // slam
  { duration: '1m', target: 500 },
  { duration: '10s', target: 0 },    // does it recover, or stay degraded?
]

// SOAK — any leak/degradation over hours? memory creep, connection exhaustion.
stages: [
  { duration: '5m', target: 100 },
  { duration: '4h', target: 100 },
  { duration: '5m', target: 0 },
]
```

For exact-RPS targets, swap stages for an arrival-rate executor:

```javascript
export const options = {
  scenarios: {
    steady: {
      executor: 'constant-arrival-rate',
      rate: 500, timeUnit: '1s',       // 500 rps regardless of latency
      duration: '5m',
      preAllocatedVUs: 100, maxVUs: 800,
    },
  },
};
```

## Reading the summary

After a run, look at three things in order:

1. **`http_req_failed`** — if errors climbed under load, latency numbers are meaningless. Fix capacity/errors first.
2. **`http_req_duration` p95/p99** — the tail. p50 looking fine while p99 explodes is the classic "most users fine, some users furious" signal.
3. **The knee** — the VU/RPS level where p95 stops being flat and turns vertical. That number *is* your capacity ceiling. Everything above it is the danger zone.

Export raw results for graphing:

```bash
k6 run --out json=results.json script.js
k6 run --out experimental-prometheus-rw script.js   # → Grafana/Prometheus
```

## CI gate

k6 exits non-zero on threshold breach, so the gate is just the exit code:

```yaml
# .github/workflows/load-test.yml (excerpt)
- name: k6 load test (gates on thresholds)
  run: k6 run --quiet load.js
  env:
    TARGET_URL: ${{ secrets.STAGING_URL }}   # prod-like, never localhost
```

A failed threshold fails the step, which fails the job. No extra assertion logic needed.

## Rules that keep results honest

- **Target a prod-like environment**, ideally staging that mirrors prod (same instance sizes, same DB tier, same pooler). Localhost measures your laptop.
- **Ramp gradually** in load/stress tests — instant max load tests cold-start behavior, not steady-state. Use the spike test deliberately when cold-start *is* the question.
- **Decide cache state on purpose.** Warm the cache first to test steady-state, or test stone-cold to measure the miss-storm against the origin — but know which one you're measuring.
- **Run from outside your own network** when WAN latency and the CDN matter to the result; a runner inside the same VPC hides the real client experience.
