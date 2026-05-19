---
description: Rules for any code touching auth, secrets, crypto, user-input parsing, or network boundaries.
globs: ["**/auth/**", "**/security/**", "**/crypto/**", "**/*.auth.*", "**/middleware/**", "**/permissions/**", "**/*permission*", "**/*secret*", "**/*token*"]
---

# Security-sensitive code rules

## Required

- **All user input is treated as hostile.** Validate type, shape, length, character class — at the boundary, before the value reaches business logic.
- **Output encoding by context.** Don't apply HTML escaping to JSON output, or SQL escaping to URL params. Encode for the destination.
- **Parameterized queries always.** No string concatenation into SQL. Ever. Even for "trusted" inputs.
- **Authn ≠ Authz.** Two distinct checks. Knowing who the user is doesn't mean they can do this thing.
- **Authz at the resource, not the route.** Don't just check "is user logged in" — check "does THIS user own/can-access THIS resource".
- **Tokens have scope, expiry, and rotation.** No eternal API keys. No `God-mode` tokens that can do everything.
- **Audit logs are immutable.** Write-once, append-only. The same code that does the action can't edit the audit record afterwards.

## Crypto

- **Use the standard library or a vetted package.** Don't implement AES yourself. Don't roll your own JWT verification — use a library that handles `alg: none` and key-confusion correctly.
- **Random for security uses CSPRNG.** `crypto.randomBytes`, `secrets` (Python), `crypto/rand` (Go). Never `Math.random()` or non-crypto RNGs for tokens, IDs, salts.
- **Passwords use a slow KDF with salt.** Argon2id, bcrypt, scrypt. Not plain SHA-256, not MD5, not "we hash it".
- **Key rotation is a documented procedure.** You'll need to rotate when (not if) something leaks.

## Secrets handling

- **Secrets enter the process via env or secret manager.** Never via code, never via config files in the repo.
- **Secrets are not logged.** Build redaction into the logging layer — don't rely on developers remembering.
- **`.env*` is in `.gitignore`.** Verify before staging a new file.
- **Pre-commit hook scans for secrets.** `gitleaks`, `trufflehog`, etc. Don't trust eyeballs.

## Network boundaries

- **HTTPS only externally.** No mixed content. HSTS enabled for HTTPS services.
- **CORS is restrictive.** Whitelist exact origins, not `*` (unless truly public).
- **SSRF defense.** When the app makes outbound requests on behalf of a user, restrict targets — no `http://169.254.169.254/`, no `http://localhost/`.
- **Rate-limit by actor, not just by IP.** IP-only rate-limiting is bypassed by anyone with a few proxies.

## Don't

- Don't disable certificate verification in production code (`rejectUnauthorized: false`, `verify=False`, `-k`). Even temporarily.
- Don't store sensitive data in localStorage / sessionStorage — accessible to any script.
- Don't put auth tokens in URLs. They leak to logs, referrers, analytics.
- Don't roll your own SSO. Use OAuth2/OIDC libraries from a serious vendor.
- Don't display raw error messages to end users on auth endpoints. "Invalid credentials" — not "user found but password wrong" (enumeration leak).
