# Deployments API — full reference

Source: https://replicate.com/docs/topics/deployments (accessed 2026-06-02).

A deployment is a private, dedicated endpoint pointing at one model version. It autoscales from zero
to hundreds of instances, keeps a warm floor if you ask, caps spend with a ceiling, and lets you swap
hardware without touching `predict.py`. Updates roll out with no downtime.

## Config fields

| Field | Meaning | Cost/latency effect |
|---|---|---|
| `model` | `owner/model` the deployment serves | — |
| `version` | the immutable version SHA to run | pin it; bump via update |
| `hardware` | e.g. `gpu-t4`, `gpu-a100-large`, `gpu-h100` | bigger = faster + pricier |
| `min_instances` | warm floor (>=0) | >0 kills cold starts but bills idle 24/7 |
| `max_instances` | concurrency ceiling | the hard spend cap under spikes |

Start `min_instances: 0` (scale to zero) and only raise it when measured cold-start latency hurts
users. Set `max_instances` deliberately — it is your protection against a traffic spike becoming a
surprise bill.

## Create / update via HTTP API

```bash
# create
curl -s -X POST https://api.replicate.com/v1/deployments \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-endpoint",
    "model": "owner/model",
    "version": "<version-sha>",
    "hardware": "gpu-a100-large",
    "min_instances": 1,
    "max_instances": 5
  }'

# update (rolling — bump version or rescale with no downtime)
curl -s -X PATCH https://api.replicate.com/v1/deployments/owner/my-endpoint \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"version": "<new-version-sha>", "min_instances": 2}'
```

## Via the Python client

```python
client = replicate.Client()

client.deployments.create(
    name="my-endpoint",
    model="owner/model",
    version="<version-sha>",
    hardware="gpu-a100-large",
    min_instances=1,
    max_instances=5,
)

# scale or roll a new version
client.deployments.update("owner/my-endpoint", min_instances=2, version="<new-sha>")
```

## Calling a deployment

You call it like any model — the deployment just routes to your private instances:

```python
deployment = client.deployments.get("owner/my-endpoint")
prediction = deployment.predictions.create(input={"prompt": "..."})
prediction.reload()
```

Async + webhook works the same: pass `webhook=` / `webhook_events_filter=` to the deployment's
`predictions.create`.

## Rolling updates

Updating `version` rolls new instances in and drains old ones with no downtime. Because versions are
immutable SHAs, you can roll back by updating `version` to the previous SHA. Never depend on "latest" —
pin the SHA so a teammate's `cog push` does not silently change what the endpoint serves.

## Monitoring

The dashboard and API expose per-deployment **latency, throughput, error rate, and GPU memory**. Watch
GPU memory to right-size hardware, and error rate after every rolling update — a spike right after a
version bump means roll back to the prior SHA.
