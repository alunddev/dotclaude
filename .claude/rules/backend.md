---
description: Rules for server-side code (handlers, services, repositories, background jobs).
globs: ["src/server/**", "apps/server/**", "backend/**", "src/services/**", "src/jobs/**", "internal/**", "**/handlers/**"]
---

# Backend code rules

## Required

- **Layered architecture.** Handler → Service → Repository (or equivalent). Business logic never lives in route handlers.
- **Transactions at the right boundary.** Wrap unit-of-work in a transaction — usually at the service layer, not inside loops.
- **Idempotency for retryable mutations.** Webhooks, payment flows, queue jobs: accept idempotency keys, handle duplicate delivery.
- **Pagination on every list endpoint.** No unbounded queries returning to a client.
- **Structured logging.** One log per request, JSON, includes `request_id`. Errors include the request_id for correlation.
- **Graceful shutdown.** On SIGTERM, drain in-flight requests, close DB pool, close queue connection.

## Background jobs

- **Jobs are idempotent.** They may run twice. Design for that.
- **Jobs have timeouts.** Default 5 min unless specified. Long-running jobs should checkpoint progress.
- **Failed jobs go to a dead-letter queue or retry with backoff.** Never drop silently.
- **Heavy jobs run in a separate worker pool.** Don't compete with request-serving threads.

## Database access

- **Use the repository pattern or query builder.** No raw SQL strings scattered across services.
- **`SELECT *` is banned in production code.** Be explicit about columns — schema changes will surprise you otherwise.
- **N+1 detection is part of code review.** Use the ORM's "preload" / "include" / "with" mechanism, or escalate to a single query.

## Don't

- Don't use a single shared mutable global for things like cache or DB pool — use proper DI / lifecycle.
- Don't catch and swallow errors. Either handle them meaningfully or let them propagate with context.
- Don't put secrets in environment defaults inside code (`process.env.KEY || "fallback-secret"`).
- Don't write API endpoints that return different schemas for different inputs — use union types or separate endpoints.
