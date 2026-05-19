---
name: feature-flags-implementation
description: Feature-flag patterns — release flags, experiment flags, ops flags, permission flags. Targeting, percentage rollouts, kill switches, flag debt cleanup. Provider-agnostic (LaunchDarkly, Unleash, Flipper, ConfigCat, Flagsmith, custom). Use when implementing flag-driven releases, A/B tests, or operational toggles.
---

# Feature flags

A flag is just a boolean (or richer value) you can flip without redeploying. The hard part is governance, not implementation.

## When to use this skill

- Decoupling deploy from release (ship dark, enable later)
- Gradual rollouts (1% → 10% → 100%)
- A/B testing
- Quick rollback without rolling back code (kill switch)
- Permissioning beta features by user/tenant
- Cleaning up old flags before they multiply

## The 4 types (different rules apply to each)

| Type | Lifetime | Owner | Example |
|---|---|---|---|
| **Release flag** | Hours–weeks | Engineer who added it | "Enable new checkout for 5% of users" |
| **Experiment flag** | Weeks–months | Product / data | "Test pricing page variant B" |
| **Ops flag** | Forever | SRE / on-call | "Disable expensive recommendation algorithm under load" |
| **Permission flag** | Forever | Product / customer success | "Enable Pro features for tenant X" |

**Mixing them is the #1 source of flag rot.** A flag that started as "release" lingers as "permission" with no owner.

## Provider selection

| Provider | Best for |
|---|---|
| **LaunchDarkly** | Large teams, lots of flags, paid |
| **Unleash** | Self-hosted, open source, good defaults |
| **Flagsmith** | Self-hosted or managed, simple |
| **PostHog** | Combined product analytics + flags |
| **Flipper** (Ruby) | Rails app with simple needs |
| **ConfigCat** | Cheap, simple, multi-language |
| **Custom (DB-backed)** | < 20 flags, monolith, want full control |

Default recommendation: Unleash (self-hosted) or LaunchDarkly (managed).

## Minimal abstraction

```typescript
// flag-client.ts
export interface FlagClient {
  isEnabled(key: string, context: Context): Promise<boolean>;
  getVariant(key: string, context: Context): Promise<string>;
  getValue<T>(key: string, defaultValue: T, context: Context): Promise<T>;
}

export interface Context {
  userId?: string;
  tenantId?: string;
  email?: string;
  country?: string;
  custom?: Record<string, string | number | boolean>;
}
```

Wrap the provider's SDK. Code calls `flagClient.isEnabled('new-checkout', ctx)` — your code never knows whether it's LaunchDarkly or Unleash.

Benefit: switch providers without touching feature code; test with an in-memory implementation.

## Pattern: release flag (the most common)

```typescript
// In handler
if (await flags.isEnabled('new-checkout', { userId, tenantId })) {
  return newCheckout(request);
}
return legacyCheckout(request);
```

Rules:
- **Owner field is mandatory** — who's responsible.
- **Expiry date is mandatory** — when this flag should be removed.
- **Auto-issue** when expiry passes.
- **Bias to defaults that make sense if the flag system fails.** New code should fail closed (default false); kill switches should fail open.

## Pattern: percentage rollout

Most providers do this for you:

```
Flag: new-checkout
Strategy: gradual rollout
  - 1% of users for 1 day → monitor errors, latency
  - 10% for 2 days → monitor
  - 50% for 2 days → monitor
  - 100% → full release
  - +7 days → remove flag
```

The targeting hash MUST be stable per user. Otherwise users flip in/out as they request and you can't measure consistently.

```typescript
// Stable hash
const hash = murmurhash(`${flagKey}:${userId}`);
const enabled = (hash % 100) < percentageRollout;
```

## Pattern: targeting rules

```yaml
flag: new-checkout
default: false
rules:
  - if: tenant_id IN ['internal-beta-tenants']
    then: true
  - if: country IN ['US', 'CA'] AND user_role == 'admin'
    then: true
  - if: percentageRollout(stable_hash) < 25
    then: true
```

First match wins. Default catches everyone else.

## Pattern: kill switch (ops flag)

```typescript
// Wrap expensive / external-dependency code
if (await flags.isEnabled('use-recommendations', ctx, { default: true })) {
  recs = await recommendationsService.get(userId);
} else {
  recs = []; // graceful degradation
}
```

When the recommendation service is on fire at 3 AM, the on-call flips `use-recommendations` to false. No deploy. The site keeps working without recs.

Kill-switch rules:
- Default = "on" (safe steady state)
- Flipping to "off" must be < 30s (provider sync time)
- Document each kill switch in the runbook
- Never let a kill switch quietly become permanent — review monthly

## Pattern: experiment flag (A/B)

```typescript
const variant = await flags.getVariant('pricing-page-test', { userId });
// variant ∈ ['control', 'variant-a', 'variant-b']

renderPricingPage({ layout: variant });
analytics.track('exposure', { experiment: 'pricing-page-test', variant, userId });
```

Critical: **always emit an "exposure" event** with the variant. Without it, you can't measure the experiment. Most flag providers emit this automatically.

Statistical rigor (briefly):
- Decide sample size BEFORE the test.
- Don't peek and stop early — inflated false positives.
- Use a proper analysis tool (provider's built-in, or downstream stats).

## Flag debt (the hard problem)

Every flag is a permanent branch in your code. Stale flags = dead branches = bugs.

### Cleanup workflow

1. **Tag flags at creation** with: type (release/experiment/ops/permission), owner, expiry.
2. **Automated audit** monthly: list flags past expiry, ping owner.
3. **Removal PR template**:
   - Remove flag check from code, keep only the "winning" branch
   - Delete the flag from provider (or archive)
   - Remove from `flag-keys.ts` constant file
4. **Block PRs that add flags without owner/expiry** via CI lint.

### Detection script (basic)

```python
# scripts/find-stale-flags.py
import json
from datetime import datetime

flags = provider.list_flags()
now = datetime.utcnow()
for f in flags:
    if f['type'] == 'release' and (now - f['created_at']).days > 30:
        print(f"STALE release flag: {f['key']} (owner: {f['owner']})")
```

Wire into a weekly Slack notification.

## Constants file pattern

Keep flag keys in one place to make grep/remove easy:

```typescript
// flag-keys.ts
export const FLAGS = {
  NEW_CHECKOUT: 'new-checkout',
  PRICING_TEST: 'pricing-page-test',
  USE_RECOMMENDATIONS: 'use-recommendations',  // KILL SWITCH
} as const;

// In code
if (await flags.isEnabled(FLAGS.NEW_CHECKOUT, ctx)) { ... }
```

Bonus: typo-safety, easy refactor, single source of cleanup truth.

## Testing with flags

### Unit tests

Use a deterministic in-memory client:

```typescript
class TestFlagClient implements FlagClient {
  constructor(private flags: Record<string, boolean | string>) {}
  async isEnabled(key: string) { return !!this.flags[key]; }
  async getVariant(key: string) { return String(this.flags[key] ?? 'control'); }
}

// In test
const client = new TestFlagClient({ 'new-checkout': true });
const result = await handler(request, client);
expect(result.path).toBe('new');
```

### E2E

Override flags per test via the provider's API or via a test-only header.

### Production

Test in production at low percentage. That's the whole point of flags.

## Frontend vs backend flags

- **Backend flags** are evaluated server-side. Source of truth for behavior. SDK calls a server.
- **Frontend flags** evaluate in the browser. Need a bootstrap with user context. Cache locally; refresh periodically.

For new flags affecting both: evaluate server-side and send the result to the frontend in initial response. Avoids race conditions and provider RTTs.

## Anti-patterns

- **Permanent "if (flag) { newCode } else { oldCode }"** — eventually the else-branch is wrong, and you don't know which.
- **Nested flag conditions** — `if (A && B && !C)` is a maintenance trap. Combine in the provider, not in code.
- **Flag for a refactor** that doesn't change behavior — flags add risk without benefit.
- **Targeting on email domains** without considering subdomains and aliases.
- **Forgetting to remove the flag** post-rollout — see "flag debt".
- **Different flag keys for same concept** in frontend and backend — they drift apart.
- **Storing flag state in localStorage** — users can edit. Use server-evaluated for anything security-sensitive.
- **No default value** — what if the provider is down? You need a fallback that's safe.
- **Treating flags like config** — config rarely changes; flags do. Keep them separate.

## Governance checklist for every new flag

Before merging the PR that adds a flag:
- [ ] Type assigned (release/experiment/ops/permission)
- [ ] Owner named
- [ ] Expiry / cleanup date set (or "permanent" for ops/permission)
- [ ] Default value is safe if provider is down
- [ ] Added to constants file
- [ ] Documented in the provider's description field (not just the codebase)
- [ ] If ops flag: added to runbook
- [ ] If experiment: success metric defined BEFORE shipping
