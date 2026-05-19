---
name: webhooks-design
description: Webhook design from both sides — sending and receiving. Signature verification, retry with backoff, idempotency, ordering, signed payloads, deliverability monitoring. Use when integrating with Stripe/GitHub/Slack-style webhooks or designing your own webhook system.
---

# Webhooks design

Webhooks are HTTP callbacks: "event happened, here's the data, here's the URL to call". Simple in principle, full of subtle traps in practice.

## When to use this skill

- Building a webhook receiver for Stripe, GitHub, Slack, Twilio, etc.
- Designing your own webhook system to deliver to customers
- Debugging duplicate, lost, or malformed deliveries
- Hardening webhook endpoints against abuse

## Receiver side (consuming webhooks)

### Mandatory checklist

- [ ] Verify the signature on every request
- [ ] Respond fast (< 5s, ideally < 1s)
- [ ] Be idempotent — same event ID may arrive twice
- [ ] Return correct status codes (2xx = received, 5xx = retry)
- [ ] Log raw payload for replay/debugging
- [ ] Handle out-of-order events
- [ ] Rate-limit per source

### Pattern: receive → enqueue → respond → process

The receiver does the minimum to validate + store; an async worker does the actual processing.

```python
@app.route('/webhooks/stripe', methods=['POST'])
def stripe_webhook():
    # 1. Read raw body BEFORE any parsing
    raw_body = request.get_data()
    signature = request.headers.get('Stripe-Signature')

    # 2. Verify signature
    try:
        event = stripe.Webhook.construct_event(raw_body, signature, WEBHOOK_SECRET)
    except (ValueError, stripe.error.SignatureVerificationError):
        return '', 400  # Bad signature → don't retry

    # 3. Idempotency check
    if event_log.exists(event_id=event['id']):
        return '', 200  # Already saw this, ack and move on

    # 4. Persist event (durable)
    event_log.insert(event_id=event['id'], type=event['type'], payload=raw_body)

    # 5. Enqueue for async processing
    queue.publish('webhook.stripe', {'event_id': event['id']})

    # 6. Respond fast
    return '', 200
```

The actual business logic (charging the customer, sending the email) runs in the worker, not in the HTTP handler.

### Signature verification

Always use the sender's recommended library when available. If implementing yourself:

```python
import hmac, hashlib

def verify_signature(payload_bytes, signature_header, secret):
    expected = hmac.new(secret.encode(), payload_bytes, hashlib.sha256).hexdigest()
    # Compare using constant-time comparison
    return hmac.compare_digest(signature_header, expected)
```

**Critical**: use `hmac.compare_digest` (or equivalent), not `==`. Timing attacks are real.

Variants:
- **Stripe**: `Stripe-Signature: t=1234,v1=hash` — includes timestamp for replay protection.
- **GitHub**: `X-Hub-Signature-256: sha256=<hash>` — HMAC of raw body.
- **Slack**: `X-Slack-Signature: v0=<hash>` — HMAC of `v0:timestamp:body`.

### Replay protection

Signature alone doesn't prevent replays. Include and check a timestamp:

```python
def verify_with_timestamp(payload, signature, timestamp, secret, max_age=300):
    if abs(time.time() - timestamp) > max_age:
        raise SignatureError("Request too old")
    # ... HMAC check on (timestamp + body) ...
```

Reject requests older than ~5 minutes.

### Idempotency

Every webhook delivery has an event ID. Persist it; refuse duplicates:

```sql
CREATE TABLE webhook_events (
  event_id TEXT PRIMARY KEY,
  source TEXT NOT NULL,
  type TEXT NOT NULL,
  payload JSONB NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

```python
try:
    db.execute(
        "INSERT INTO webhook_events (event_id, source, type, payload) VALUES (?, ?, ?, ?)",
        (event_id, source, type, payload)
    )
except UniqueViolationError:
    return '', 200  # Duplicate, ack
```

### Out-of-order events

Webhooks can arrive in any order. For state-changing events, include event timestamps and ignore older-than-current updates:

```python
def update_subscription(event):
    sub = db.subscriptions.find(event['subscription_id'])
    if sub.updated_at >= event['created_at']:
        return  # We have a newer state; skip
    sub.update(event['data'])
```

### Status codes

| Status | Meaning to sender |
|---|---|
| 200/201/204 | Received, don't retry |
| 4xx | Bad request, **don't retry** (sig fail, malformed) |
| 5xx | Server error, **do retry** |
| timeout | Likely retry, depends on sender |

Be explicit about which class. Don't return 200 on signature failure (you'll never see the retry that would alert you to an issue).

### Rate limiting + WAF

Webhook endpoints are public URLs. They get scanned, fuzzed, attacked.

- Rate-limit per source IP (or per signing-key if you can identify the sender).
- Cap payload size (`Content-Length` check + body length limit).
- Reject requests with unexpected `Content-Type`.
- Put endpoints behind a WAF that blocks obvious abuse.

## Sender side (delivering webhooks)

If you're emitting webhooks to customers, you owe them reliability.

### Mandatory checklist

- [ ] Sign every payload (HMAC SHA-256 minimum)
- [ ] Include unique event ID
- [ ] Include timestamp
- [ ] Retry with backoff
- [ ] Cap retry attempts (then DLQ + customer alert)
- [ ] Provide delivery logs (success / failure / response code)
- [ ] Support manual replay
- [ ] Document signature scheme

### Delivery service architecture

```
[Event source] → [Outbox table] → [Delivery worker] → [Customer endpoint]
                                          ↓ on failure
                                    [Retry queue with backoff]
                                          ↓ on max retries
                                       [DLQ + alert]
```

Use the outbox pattern (see `message-queue-patterns`) so events don't get lost between DB commit and broker publish.

### Payload contract

```json
{
  "id": "evt_01H8...",
  "type": "invoice.paid",
  "created": 1730000000,
  "version": "2024-01-01",
  "data": {
    "object": { ... }
  }
}
```

- **`id`** — unique, used by receiver for idempotency.
- **`type`** — verb.noun or noun.verb, consistent across all events.
- **`created`** — Unix timestamp.
- **`version`** — versioned schema for future compatibility.
- **`data`** — the actual event payload.

### Signing

```python
def sign_payload(payload_bytes, secret):
    signature = hmac.new(secret.encode(), payload_bytes, hashlib.sha256).hexdigest()
    return signature

def deliver(endpoint, payload, secret):
    body = json.dumps(payload, separators=(',', ':')).encode()  # canonical
    signature = sign_payload(body, secret)
    headers = {
        'Content-Type': 'application/json',
        'X-MyApp-Signature': f'sha256={signature}',
        'X-MyApp-Event-Id': payload['id'],
        'X-MyApp-Timestamp': str(int(time.time())),
    }
    return requests.post(endpoint, data=body, headers=headers, timeout=10)
```

Always sign the **exact bytes you send**. Canonical JSON (no whitespace variations) matters.

### Retry policy

```python
ATTEMPTS = [
    timedelta(seconds=0),
    timedelta(seconds=30),
    timedelta(minutes=5),
    timedelta(minutes=30),
    timedelta(hours=2),
    timedelta(hours=6),
    timedelta(hours=24),
]
MAX_ATTEMPTS = len(ATTEMPTS)
```

After max attempts: mark as failed, alert the customer (email, dashboard), keep payload for manual replay.

### Customer-facing delivery logs

Customers need to see:
- All deliveries (success and failure)
- Response code + response body (truncated)
- Headers sent
- Retry timeline
- Manual replay button

This is non-negotiable for B2B webhook products.

### Endpoint health

If a customer's endpoint is consistently failing (e.g. > 50% failure rate for 24h), disable deliveries and notify them. Don't keep hammering a dead endpoint.

## Anti-patterns

### Receiver
- **Processing in the HTTP handler.** Spike in events → timeouts → sender retries → cascade.
- **Skipping signature verification "in dev"** that ends up in prod.
- **Returning 200 on signature failure** to silence retries — hides bugs.
- **Storing only parsed payload, not raw bytes** — can't re-verify signature later.
- **Reading the body twice without buffering** — breaks signature verification in some frameworks.

### Sender
- **No signing.** Receivers can't trust you.
- **Random retry intervals.** Predictable backoff is fixable; random is debuggable hell.
- **Sending PII without encryption-at-rest in delivery logs.**
- **Marketing "exactly-once delivery"** — impossible. Document at-least-once and how to dedupe.
- **No delivery logs for customers.** They'll find out from support tickets, not dashboards.
- **Putting URLs in the message body** that change between dev/prod — use HTTPS only, fixed shapes.

## Testing webhooks

### Locally
- **ngrok** / **localtunnel** to expose localhost to a public URL.
- **webhook.site** for inspecting payloads from third parties.
- **Stripe CLI** / **Twilio CLI** etc. — provider-specific local testing.

### In CI
- Mock the signature verification.
- Test idempotency by sending the same event twice; assert the second call is a no-op.
- Test bad signatures return 400, not 200.

### Replay tooling
Have a CLI or admin UI to replay any stored event by ID. You'll need it during incident response.
