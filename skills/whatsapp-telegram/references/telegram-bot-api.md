# Telegram Bot API reference

Base: `https://api.telegram.org/bot${TG_TOKEN}/<METHOD>`. Token from @BotFather, kept in env. Bot API 10.0 (2026-05-08). Facts accessed 2026-06-02.

## Messaging method catalog

| Method | Use |
| --- | --- |
| `sendMessage` | Text (≤4096 chars), `parse_mode`, `reply_markup`. |
| `sendPhoto` | Photo by `photo` URL/file_id, `caption` ≤1024. |
| `sendDocument` | Arbitrary file. |
| `sendMediaGroup` | 2–10 items as an album. |
| `editMessageText` | Edit a previously sent message (good for live status). |
| `deleteMessage` | Remove a message. |
| `answerCallbackQuery` | Acknowledge an inline-button tap (call within seconds or the client shows a spinner). |
| `setMyCommands` | Register the `/` command menu. |

Successful responses are `{ "ok": true, "result": {...} }`. Capture `result.message_id`.

## MarkdownV2 escaping

In `parse_mode=MarkdownV2`, escape these reserved chars with `\` everywhere they are literal text:

```
_ * [ ] ( ) ~ ` > # + - = | { } . !
```

```ts
const escapeMdV2 = (s: string) => s.replace(/[_*[\]()~`>#+\-=|{}.!]/g, "\\$&");
```
Inside `pre`/`code` entities only `` ` `` and `\` need escaping. When in doubt for dynamic text, use `parse_mode=HTML` (escape only `< > &`).

## 4096-char chunking
```ts
function chunk(text: string, max = 4096): string[] {
  const out: string[] = [];
  for (let i = 0; i < text.length; i += max) out.push(text.slice(i, i + max));
  return out;
}
```

## Rate limits + 429 backoff

- ~30 msg/s broadcast across chats; ~1 msg/s to the same chat.
- 429 body: `{ "ok": false, "error_code": 429, "parameters": { "retry_after": 5 } }`. Sleep `retry_after` seconds, retry.
- Paid Broadcasts (enable via @BotFather): up to 1000 msg/s, 0.1 Telegram Stars per message above the free tier.

```ts
async function call(method: string, payload: object, tries = 5): Promise<any> {
  for (let i = 0; i < tries; i++) {
    const res = await fetch(`https://api.telegram.org/bot${process.env.TG_TOKEN}/${method}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const json = await res.json();
    if (json.ok) return json.result;
    if (json.error_code === 429) {
      await new Promise((r) => setTimeout(r, (json.parameters?.retry_after ?? 1) * 1000));
      continue;
    }
    throw new Error(`Telegram ${method}: ${json.error_code} ${json.description}`);
  }
  throw new Error(`Telegram ${method}: rate-limited after ${tries} tries`);
}
```

## Inbound: setWebhook XOR getUpdates (never both)

### setWebhook
```bash
curl -sS "https://api.telegram.org/bot${TG_TOKEN}/setWebhook" \
  -d url=https://example.com/tg \
  -d secret_token=$(openssl rand -hex 16) \
  --data-urlencode 'allowed_updates=["message","callback_query"]' \
  -d max_connections=40
```
Telegram echoes the `secret_token` in the `X-Telegram-Bot-Api-Secret-Token` request header on each update — compare it and reject mismatches. `max_connections` range 1–100, default 40. `allowed_updates` filters update types.

### getUpdates (long-poll, dev / single instance)
```ts
let offset = 0;
for (;;) {
  const updates = await call("getUpdates", { offset, timeout: 30 });
  for (const u of updates) {
    offset = u.update_id + 1; // ack: advance past processed updates
    // handle u.message / u.callback_query
  }
}
```
Calling `getUpdates` while a webhook is set returns an error — `deleteWebhook` first. Run exactly one delivery mode.
