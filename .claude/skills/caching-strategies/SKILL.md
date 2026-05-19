---
name: caching-strategies
description: Production caching patterns across the stack — HTTP caching, CDN, Redis/Memcached application cache, browser cache, database query cache. Includes invalidation strategies (the hard part) and stampede prevention. Use when adding cache, debugging stale data, or designing for high read load.
---

# Caching strategies

> "There are only two hard things in Computer Science: cache invalidation and naming things." — Phil Karlton

This skill is about doing the first one less badly.

## When to use this skill

- Adding a cache layer (any layer)
- Debugging stale data or inconsistent reads
- Designing for high read traffic
- Reducing DB or external API load
- Optimizing TTFB and Core Web Vitals

## The cache hierarchy

Requests flow through these layers, top to bottom:

1. **Browser cache** — fastest, free, hardest to invalidate.
2. **CDN / edge cache** — Cloudflare, Fastly, Cloudfront. Geographically close to users.
3. **Reverse proxy cache** — Varnish, Nginx, Cloudflare Workers KV.
4. **Application cache** — in-process LRU, or shared (Redis/Memcached).
5. **Database query cache** — PG materialized views, MySQL query cache (mostly deprecated).
6. **Origin** — your DB, your APIs.

Cache as close to the user as you can while still being correct.

## Pattern 1: Cache-aside (most common)

App checks cache; on miss, fetches origin and populates cache.

```python
def get_user(user_id):
    key = f"user:{user_id}"
    cached = redis.get(key)
    if cached:
        return json.loads(cached)
    user = db.query("SELECT * FROM users WHERE id = ?", user_id)
    redis.setex(key, ttl=300, value=json.dumps(user))
    return user
```

Pros: simple, lazy (only caches what's used).
Cons: cache miss = full origin trip. First request is always slow.

## Pattern 2: Write-through

On write, update DB AND cache.

```python
def update_user(user_id, data):
    db.update(user_id, data)
    redis.setex(f"user:{user_id}", ttl=300, value=json.dumps(data))
```

Pros: cache is always warm.
Cons: writes are slower; if cache write fails after DB write succeeds, you have stale cache.

**Mitigation**: write to DB first, then invalidate (not update) cache. Next read repopulates.

## Pattern 3: Write-behind (use sparingly)

Write to cache, async-flush to DB. Used in extreme write throughput scenarios.

**Risk**: cache loss = data loss. Only use with replicated cache + durable write log. Most apps should not do this.

## Pattern 4: Read-through

Cache layer fetches from origin on miss (vs. cache-aside where the app does it).

Implemented in proxies/CDNs more than app code. Cleaner abstraction; harder to debug.

## Invalidation strategies

This is where most bugs live.

### TTL (time-to-live)

Set an expiry. Simple but accept stale data for up to TTL.

```python
redis.setex(key, ttl=60, value=...)
```

**Rule of thumb**:
- High-cardinality + rapidly changing data: TTL 30s–5min
- Reference data (countries, categories): TTL 1h–24h
- Truly static (compiled assets): "forever" (years) with content-hashed URLs

### Explicit invalidation on write

Delete the cache entry when the underlying data changes:

```python
def update_user(user_id, data):
    db.update(user_id, data)
    redis.delete(f"user:{user_id}")
```

Works for single keys. Breaks down when data appears in many derived keys (`user:123`, `friends_of:456`, `team:7`).

### Tag-based invalidation

Group related keys under a tag; invalidate the tag.

```python
def cache_with_tags(key, tags, value, ttl):
    redis.setex(key, ttl, value)
    for tag in tags:
        redis.sadd(f"tag:{tag}", key)

def invalidate_tag(tag):
    keys = redis.smembers(f"tag:{tag}")
    if keys:
        redis.delete(*keys)
        redis.delete(f"tag:{tag}")
```

Cloudflare and Fastly have built-in cache tags. Useful for "invalidate everything for user X".

### Versioned keys

Embed a version in the key. Bump version to invalidate all related keys at once.

```python
schema_version = "v2"
key = f"user:{schema_version}:{user_id}"
```

Useful for migrations; bad for ad-hoc invalidation.

## Stampede prevention (thundering herd)

When a hot key expires, many requests miss simultaneously and all hit the origin.

### Probabilistic early expiration

Recompute *before* expiry, randomly, with probability rising as expiry approaches.

```python
import random, math

def should_recompute(value, ttl_remaining, beta=1.0):
    # Higher beta = more eager refresh
    return random.random() < math.exp(-beta * ttl_remaining)
```

Most requests serve cached; a few proactively refresh.

### Mutex / single-flight

Only one request recomputes; others wait or serve stale.

```python
def get_with_lock(key, recompute_fn, ttl):
    cached = redis.get(key)
    if cached:
        return cached
    lock_key = f"lock:{key}"
    if redis.set(lock_key, "1", nx=True, ex=10):
        try:
            value = recompute_fn()
            redis.setex(key, ttl, value)
            return value
        finally:
            redis.delete(lock_key)
    else:
        # someone else is recomputing; serve stale or wait
        return redis.get(f"stale:{key}") or wait_and_retry(key)
```

### Serve stale while revalidating

Keep stale value for a grace period after expiry; refresh async.

HTTP: `Cache-Control: max-age=60, stale-while-revalidate=300`.
CDNs honor it automatically. Your app cache can implement the same.

## HTTP caching (the rules to know)

```
Cache-Control: public, max-age=300, s-maxage=600, stale-while-revalidate=86400
ETag: "abc123"
Last-Modified: Wed, 21 Oct 2025 07:28:00 GMT
Vary: Accept-Encoding, Authorization
```

Rules:
- **`max-age`** is for browsers; **`s-maxage`** is for shared caches (CDN).
- **`private`** = browsers OK, CDN no. Use for personalized responses.
- **`public`** = anyone can cache.
- **`no-cache`** = revalidate every time (not "don't cache" — confusing name).
- **`no-store`** = actually don't store.
- **`Vary: Authorization`** = critical if same URL serves different responses per user.
- **`immutable`** = "I promise this never changes" — for content-hashed assets.

For static assets with hashed filenames (`/app.abc123.js`): `Cache-Control: public, max-age=31536000, immutable`. Cache forever.

## CDN caching

- Use **`Cache-Tag`** headers (Cloudflare) or **`Surrogate-Key`** (Fastly) for tag-based purges.
- Don't cache responses with `Set-Cookie` unless you `Vary: Cookie` carefully.
- Personalized content (user dashboards): CDN shouldn't cache. Set `Cache-Control: private`.
- Cache HTML carefully — it's often the highest-leverage layer but easiest to get wrong.

## What to cache (and what NOT to)

**Cache**:
- DB queries that hit the same row repeatedly (user lookups, configs)
- Aggregations and counts that don't need to be perfectly current
- External API responses (rate-limited APIs are obvious candidates)
- Rendered HTML for anonymous users
- Static assets aggressively (forever with hashing)

**Don't cache**:
- Anything with PII unless properly scoped
- Authentication state (use sessions, not cache)
- Strongly-consistent reads (financial balances, inventory at checkout)
- Anything that changes every request

## Cache key design

- **Namespace** keys: `app:env:resource:id` → `myapp:prod:user:42`
- **Include version** when schema changes: `myapp:prod:user:v2:42`
- **No PII in keys** when keys appear in logs/metrics
- **Keep keys short** — they're transmitted on every command
- **Hash variable-length parts** if they can be unbounded: `myapp:query:${sha256(sql)}:${args_hash}`

## Anti-patterns

- **Caching with no TTL.** Memory leaks waiting to happen.
- **Same key for different users** (forgot to scope to user_id) — data leaks.
- **Caching write-heavy data.** Cache helps reads, not writes.
- **Trying to keep cache and DB perfectly in sync.** They never will be. Accept eventual consistency or don't cache.
- **Using cache as primary storage.** Redis can be durable, but if it's your only copy, plan for loss.
- **Skipping the cache for "freshness"** while still measuring DB load — pick a lane.
- **One cache instance for everything.** Hot keys can saturate a single Redis. Shard or use a cluster.

## Debugging stale data

1. Check the TTL: `TTL key` in Redis.
2. Check who wrote it last: structured logging on cache writes.
3. Check the chain: browser → CDN → reverse proxy → app → cache → DB. Stale data hides at any layer.
4. Add a debug header: `X-Cache: HIT/MISS` so you can see at a glance.

## Monitoring

- **Hit rate** — should be > 80% for hot caches; if not, cache is misconfigured or TTL is too short.
- **Eviction rate** — if non-zero, you're under-provisioned.
- **Latency** — cache should be < 1ms. If not, something's wrong (network, hot key).
- **Origin fall-through rate** — what % of requests miss cache and hit origin? Watch for spikes.
