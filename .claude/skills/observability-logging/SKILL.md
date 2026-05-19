---
name: observability-logging
description: Structured logging that's actually useful in production — log levels, correlation IDs, context propagation, what to log vs what not to, log aggregation patterns, PII safety. Complements distributed-tracing and prometheus-configuration skills. Use when setting up logging in a new service, taming log noise, or improving incident debugging.
---

# Observability — structured logging

Logs answer "what happened?". Metrics answer "how often?". Traces answer "where?". This skill is about logs done right.

## When to use this skill

- Setting up logging in a new service
- Migrating from `print` / `console.log` to structured logging
- Reducing log noise without losing signal
- Adding correlation across services
- Debugging "I can see in production something's wrong but I don't know what"

## Core principle: structured > unstructured

Plain text:
```
[2025-11-01 10:23:45] ERROR User 1234 failed to checkout, error: Card declined
```

Structured (JSON):
```json
{
  "ts": "2025-11-01T10:23:45.123Z",
  "level": "error",
  "msg": "checkout_failed",
  "user_id": 1234,
  "order_id": "ord_01H8",
  "amount_cents": 4999,
  "currency": "USD",
  "error_code": "card_declined",
  "request_id": "req_abc",
  "service": "api",
  "version": "1.42.0"
}
```

The structured version is filterable, aggregatable, joinable across services. The text version is grep-only.

**Always structured in production.** Always.

## Log levels (and when to use each)

| Level | When | Example |
|---|---|---|
| `trace` | Per-function entry/exit, every variable | Almost never in prod |
| `debug` | Detailed flow, useful for dev / triage | "fetched 47 rows from users", "cache miss" |
| `info` | Significant business events | "user signed up", "order placed", "deploy started" |
| `warn` | Recoverable issues, retry attempts, degraded states | "retry 2/5 on payment API", "cache backend slow" |
| `error` | Operations that failed, but the system continues | "request failed with 500", "job moved to DLQ" |
| `fatal` | Process is going down | "DB connection pool exhausted, exiting" |

Production: `info` and above. `debug` only for short windows during triage.

**Anti-pattern**: every line is `INFO`. Then you can't filter signal from noise.

## Correlation: request_id and beyond

Every request, job, event carries an ID that propagates through everything it touches.

```python
import contextvars, uuid, logging

request_id_var = contextvars.ContextVar('request_id', default=None)

class CorrelationFilter(logging.Filter):
    def filter(self, record):
        record.request_id = request_id_var.get()
        return True

# Middleware (FastAPI)
@app.middleware("http")
async def correlation(request, call_next):
    rid = request.headers.get('x-request-id') or str(uuid.uuid4())
    token = request_id_var.set(rid)
    try:
        response = await call_next(request)
        response.headers['x-request-id'] = rid
        return response
    finally:
        request_id_var.reset(token)
```

Every log line in that request automatically has `request_id`. Across services, propagate via header so you can trace a request through 5 hops.

### Trace context (W3C)

Better than just `request_id`: use W3C Trace Context (`traceparent` header). Compatible with OpenTelemetry — your logs auto-correlate with your traces.

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
              version-trace_id-span_id-flags
```

Most modern frameworks have OpenTelemetry plugins that do this automatically.

## What to log

### Always log
- **Service start/stop** (with version)
- **Request received / response sent** (one line each, with status, duration, route)
- **Background job start/end** (with name, args summary, duration, result)
- **External call** (URL/service, status, duration) — even on success
- **State transitions** (order: pending → paid, user: active → suspended)
- **Errors with stack traces** — but suppress duplicates (see "deduplication" below)
- **Auth events** (login, logout, failed login, password change, MFA used)

### Conditionally log
- **Cache hits/misses** — at `debug`, summary at `info` (hourly rates as metrics)
- **DB queries** — at `debug` for slow ones, never at `info`
- **Validation failures** — yes, at `warn`, with the actual input (sanitized)

### NEVER log
- **Passwords, tokens, API keys, session IDs** — even in `debug`
- **Full credit card numbers, CVV, SSN** — even partial in some jurisdictions
- **Request bodies blindly** — they might contain PII or secrets
- **Email contents** — often PII
- **Full stack traces in `info`** — they belong in `error`

### Sanitize

```python
SENSITIVE_KEYS = {'password', 'token', 'secret', 'authorization', 'api_key', 'card_number', 'cvv', 'ssn'}

def sanitize(obj, depth=0):
    if depth > 5: return "[truncated]"
    if isinstance(obj, dict):
        return {k: ('[REDACTED]' if k.lower() in SENSITIVE_KEYS else sanitize(v, depth+1)) for k, v in obj.items()}
    if isinstance(obj, list):
        return [sanitize(x, depth+1) for x in obj[:100]]
    return obj
```

Apply to anything that touches user-controlled or sensitive data before logging.

## Context propagation

Add context that's known higher up, automatically:

```python
logger = structlog.get_logger().bind(
    service='api',
    version=os.getenv('APP_VERSION'),
    env=os.getenv('ENV'),
)

# Per-request enrichment in middleware
@app.middleware("http")
async def ctx(request, call_next):
    log = logger.bind(
        request_id=request.headers.get('x-request-id'),
        method=request.method,
        path=request.url.path,
        user_id=getattr(request.state, 'user_id', None),
    )
    request.state.log = log
    return await call_next(request)

# Use in handler
@app.get("/orders/{id}")
async def get_order(id: str, request: Request):
    request.state.log.info("order_fetch", order_id=id)
    ...
```

Result: every log line in the request has `service`, `version`, `env`, `request_id`, `method`, `path`, `user_id` automatically.

## Log aggregation patterns

### Hot path → cold path

- **Hot path**: container stdout → log collector (Fluent Bit, Vector) → message bus (Kafka) → searchable store (Loki, Elasticsearch).
- **Cold path**: same → object store (S3) for long retention.

Costs:
- Searchable storage is expensive — keep 14–30 days.
- Cold storage is cheap — keep 1–7 years.

### Sampling

For high-throughput, sample debug logs:

```python
if request_id_hash(record.request_id) % 100 == 0:
    # 1% sample
    keep_debug = True
```

Keep all `error` and above. Sample lower levels.

### Cardinality bombs

Don't put unbounded values in fields that get indexed:

```json
// Bad — user_id is high cardinality, breaks some backends as a label
{"level": "info", "user_id": 12345, "msg": "fetched"}
```

Cardinality-safe in log fields (good for search). Cardinality-deadly in metric labels (different system — see prometheus-configuration). Don't confuse them.

## OpenTelemetry: the unified path

Modern observability uses OTel for logs + metrics + traces from one SDK:

```python
# Auto-instrumentation with OTel
from opentelemetry import trace
from opentelemetry.instrumentation.logging import LoggingInstrumentor

LoggingInstrumentor().instrument(set_logging_format=True)
# Now every log line auto-includes trace_id and span_id when within a span
```

Backends: Honeycomb, Datadog, Grafana Cloud, Tempo + Loki, self-hosted Jaeger + Elastic.

## Local dev vs. production

| Aspect | Local | Production |
|---|---|---|
| Format | Human-readable, colored | JSON |
| Level | `debug` | `info` |
| Output | stdout | stdout (k8s/runtime captures) |
| Sampling | None | Sample debug, keep errors |

Use environment-aware config:

```python
if os.getenv('ENV') == 'prod':
    structlog.configure(processors=[structlog.processors.JSONRenderer()])
else:
    structlog.configure(processors=[structlog.dev.ConsoleRenderer()])
```

## Specific framework idioms

### Node.js (Pino)

```javascript
import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  formatters: { level: (label) => ({ level: label }) },
  base: { service: 'api', version: process.env.APP_VERSION },
});

const childLog = logger.child({ request_id: requestId, user_id: userId });
childLog.info({ order_id: 'ord_1' }, 'order_fetched');
```

### Python (structlog)

```python
import structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt='iso'),
        structlog.processors.JSONRenderer(),
    ],
)

log = structlog.get_logger()
log.info('order_fetched', order_id='ord_1', amount_cents=4999)
```

### Go (zap)

```go
import "go.uber.org/zap"

logger, _ := zap.NewProduction()
defer logger.Sync()

logger.Info("order_fetched",
    zap.String("order_id", "ord_1"),
    zap.Int("amount_cents", 4999),
)
```

## Anti-patterns

- **`print` / `console.log`** in production — unstructured, no levels, no context.
- **String concatenation**: `log.info("user " + id + " did X")` — searchable text but not filterable by `user_id`.
- **Logging exceptions without context**: `log.error(str(e))` loses traceback. Use `log.exception(...)` or `log.error("...", exc_info=True)`.
- **Multi-line stack traces** in JSON without escaping — breaks log parsers.
- **Logging at `info` what should be `debug`** — every "got 47 rows" pollutes the signal.
- **Logging passwords / tokens "for debugging"** — they end up in archive forever.
- **Different log shape per service** — joins across services become impossible. Standardize the envelope.
- **Logging giant request/response bodies** — fills your log bill, may contain secrets.
- **No timestamps** — every modern logger does this; if yours doesn't, switch.
- **No service identifier** — when 12 services share a log store, you need to filter.

## Triage workflow (the test for "good logging")

When an incident happens, you should be able to answer in < 5 minutes, only via logs:

1. **What is the user-facing impact?** (search by user_id or request_id)
2. **What service / endpoint is degraded?** (filter by service + level=error)
3. **What's the error rate over time?** (aggregate error count by minute)
4. **Where did it start?** (find first error after a clean window)
5. **What was the user trying to do?** (full request_id timeline across services)

If you can't answer one of these, your logging has a gap. Fix it before the next incident.
