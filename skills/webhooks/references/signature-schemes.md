# Per-provider signature schemes

Every webhook signature is the same primitive — `HMAC-SHA256(secret, message)`
compared in constant time — wrapped in a different header layout. Map the
provider onto the generic verify routine in `SKILL.md` by answering three
questions: **which headers carry the id/timestamp/signature**, **what string is
signed**, and **how is the signature encoded**.

## Comparison table

| Provider | Signature header | Signed message | Encoding | Timestamp source |
|----------|------------------|----------------|----------|------------------|
| Standard Webhooks | `webhook-signature` (`v1,<sig> …` space-separated) | `{webhook-id}.{webhook-timestamp}.{raw-body}` | base64 | `webhook-timestamp` header (Unix seconds) |
| Stripe | `Stripe-Signature` (`t=<ts>,v1=<sig>`) | `{t}.{raw-body}` | hex | `t` field inside the header |
| GitHub | `X-Hub-Signature-256` (`sha256=<sig>`) | raw body only | hex | none — rely on TLS + secret; no replay window |
| Shopify | `X-Shopify-Hmac-SHA256` | raw body only | base64 | none |
| Slack | `X-Slack-Signature` (`v0=<sig>`) + `X-Slack-Request-Timestamp` | `v0:{timestamp}:{raw-body}` | hex | `X-Slack-Request-Timestamp` header |
| Svix | same as Standard Webhooks (`svix-id/timestamp/signature` or `webhook-*`) | `{id}.{timestamp}.{raw-body}` | base64 | timestamp header |

Notes that bite:

- **Stripe and Standard Webhooks both prefix versions and both allow multiple
  comma/space-separated signatures** for secret rotation — accept the request if
  *any* candidate matches. Never `break` on the first mismatch.
- **GitHub and Shopify sign the body alone** (no id/timestamp), so they have no
  built-in replay window. Lean on HTTPS and the secret; if you need replay
  protection, dedupe on a delivery id (`X-GitHub-Delivery`).
- **Slack signs `v0:{ts}:{body}`** with a colon separator and a literal `v0:`
  prefix — different layout from the dot-joined Standard Webhooks string.
- For the **Stripe** scheme specifically (event model, `stripe listen`, the
  billing flows) use `../../stripe/SKILL.md`; this table only covers verifying
  the signature.

## Verify primitives by language

The two things that must be language-correct: feed the **raw bytes** to the HMAC,
and use the **constant-time** comparator.

| Language | HMAC-SHA256 | Constant-time compare |
|----------|-------------|------------------------|
| Node.js | `crypto.createHmac("sha256", key).update(raw).digest()` | `crypto.timingSafeEqual(a, b)` (equal-length Buffers) |
| Python | `hmac.new(key, raw, hashlib.sha256).digest()` | `hmac.compare_digest(a, b)` |
| Go | `hmac.New(sha256.New, key); mac.Write(raw)` | `hmac.Equal(expected, got)` |
| Ruby | `OpenSSL::HMAC.digest("SHA256", key, raw)` | `Rack::Utils.secure_compare(a, b)` |
| PHP | `hash_hmac("sha256", $raw, $key, true)` | `hash_equals($a, $b)` |

```go
// Go — Standard Webhooks verify, constant time, raw body in.
func verify(raw []byte, id, ts, header, secretB64 string) bool {
	key, _ := base64.StdEncoding.DecodeString(secretB64)
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte(id + "." + ts + "."))
	mac.Write(raw)
	expected := base64.StdEncoding.EncodeToString(mac.Sum(nil))
	for _, part := range strings.Fields(header) { // space-separated for rotation
		sig := strings.TrimPrefix(part, "v1,")
		if hmac.Equal([]byte(sig), []byte(expected)) {
			return true
		}
	}
	return false
}
```

Whatever the layout, the order from `SKILL.md` does not change: raw body →
verify → timestamp window → dedupe → enqueue → `2xx`.
