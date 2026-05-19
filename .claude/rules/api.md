---
description: Rules that apply only under src/api/** — server-side API code.
globs: ["src/api/**", "apps/api/**", "server/**"]
---

# API code rules

Applies to backend HTTP/RPC handlers, controllers, and route definitions.

## Required

- **Validate at the boundary.** Every request body / query param / path param goes through a schema validator (Zod, Pydantic, ajv, etc.) before reaching business logic.
- **Never trust the client.** Auth, authz, and tenancy checks happen server-side regardless of any client-side gating.
- **Return typed errors.** Don't leak stack traces or raw DB errors to clients. Use a structured `{ error: { code, message } }` shape.
- **Idempotency keys for mutations** where the spec allows retries (payments, webhooks, queued jobs).
- **Rate-limit at the edge.** Per-route, per-actor. Use sliding-window or token-bucket — not just a fixed counter.

## Logging

- Structured logs (JSON), one event per request with: method, path, status, latency_ms, user_id (if known), request_id.
- No PII in log bodies. Hash or redact emails, names, tokens.
- Errors logged at `error` level include the request_id so they can be correlated with traces.

## Testing

- Every route has at least: happy path, validation failure, authz failure, server error path.
- Use a real DB (test container or in-memory) — no mocking the DB layer.
- Test the response shape contract, not just the status code.

## Don't

- Don't return 200 with `{ success: false }`. Use the right status code.
- Don't put business logic in route handlers — extract to a service layer.
- Don't catch broad exceptions to "make tests pass". Catch what you can handle; let the rest surface.
