---
name: oauth-oidc-implementation
description: OAuth 2.0 + OpenID Connect implementation patterns — Authorization Code with PKCE, refresh tokens, token storage, state validation, scope design, common attacks and how to defend. Distinct from generic auth-implementation-patterns. Use when integrating "Sign in with X" or building an OAuth provider.
---

# OAuth 2.0 + OIDC implementation

OAuth is delegation of authorization. OIDC is identity on top of OAuth. Most teams need OIDC and call it OAuth.

## When to use this skill

- Integrating "Sign in with Google/GitHub/Apple/etc."
- Building an OAuth provider for your own API
- Implementing service-to-service auth via client credentials
- Hardening an existing OAuth flow (PKCE, state, refresh rotation)
- Debugging redirect/callback/token issues

## Pick the right flow (decision tree)

| Scenario | Flow |
|---|---|
| User signing in on a web app you control | **Authorization Code + PKCE** |
| User signing in on a mobile/SPA app (no backend secret) | **Authorization Code + PKCE** |
| Server-to-server, no user | **Client Credentials** |
| Limited-input device (TV, CLI) | **Device Authorization** |
| Existing trusted session, want a token | **Token Exchange** (RFC 8693) |

**Do NOT use** in modern apps:
- **Implicit Flow** — deprecated, leaks tokens in URLs
- **Resource Owner Password Credentials** — defeats the point of OAuth
- **Authorization Code without PKCE** — vulnerable to authorization code interception

## Authorization Code + PKCE (the modern default)

### Step-by-step

```
1. Client generates:
     code_verifier  = random string, 43-128 chars, [A-Za-z0-9-._~]
     code_challenge = base64url(sha256(code_verifier))
     state          = random nonce (stored in session)

2. Client redirects user to:
     https://provider/authorize?
       response_type=code&
       client_id=CLIENT_ID&
       redirect_uri=https://app.example.com/callback&
       scope=openid+profile+email&
       state=STATE&
       code_challenge=CHALLENGE&
       code_challenge_method=S256

3. User authenticates with provider.

4. Provider redirects back:
     https://app.example.com/callback?code=AUTH_CODE&state=STATE

5. Client validates:
     - state matches the session value (CSRF defense)
     - code is present

6. Client exchanges code (server-side, NOT in browser):
     POST https://provider/token
     Body: grant_type=authorization_code&
           code=AUTH_CODE&
           redirect_uri=https://app.example.com/callback&
           client_id=CLIENT_ID&
           code_verifier=VERIFIER

7. Provider returns:
     {
       "access_token": "...",
       "refresh_token": "...",
       "id_token": "...",       (if OIDC)
       "token_type": "Bearer",
       "expires_in": 3600
     }
```

### Critical: validate state

```python
# /authorize handler
state = secrets.token_urlsafe(32)
session['oauth_state'] = state
session['oauth_state_expires'] = time.time() + 600
# ... redirect ...

# /callback handler
returned_state = request.args.get('state')
expected = session.pop('oauth_state', None)
if not expected or returned_state != expected:
    abort(400, "Invalid state")
if time.time() > session.pop('oauth_state_expires', 0):
    abort(400, "State expired")
```

Without this check, an attacker can complete the OAuth flow against your app from a victim's browser.

### Critical: validate ID token (OIDC)

```python
import jwt
from jwt import PyJWKClient

JWKS_URL = "https://provider/.well-known/jwks.json"
jwks = PyJWKClient(JWKS_URL)

def verify_id_token(id_token):
    signing_key = jwks.get_signing_key_from_jwt(id_token).key
    payload = jwt.decode(
        id_token,
        signing_key,
        algorithms=["RS256"],  # explicit allowlist
        audience=CLIENT_ID,
        issuer="https://provider",
        options={"require": ["exp", "iat", "sub", "aud", "iss"]},
    )
    return payload
```

**Pitfalls**:
- Specify `algorithms` explicitly. The `alg: none` attack is still real.
- Validate `aud` (audience) is your client_id.
- Validate `iss` (issuer) is the expected provider.
- Validate `exp` (expiration).
- For replay: validate `nonce` matches the one you sent in `/authorize`.

## Token storage

### Web app (server-side session)

Best for traditional web apps: store tokens in the server-side session, send the user only an opaque session cookie. The browser never sees the access token.

```python
session['access_token'] = tokens['access_token']
session['refresh_token'] = tokens['refresh_token']
session['expires_at'] = time.time() + tokens['expires_in']
```

### SPA (single-page app)

This is harder. Options:

1. **BFF (Backend-for-Frontend)**: SPA has a backend that holds tokens; SPA uses session cookies. Strongly recommended.
2. **In-memory only**: store access token in JS memory; refresh via httpOnly cookie. Loses on tab close.
3. **Secure httpOnly + Secure + SameSite=strict cookie**: works but limits cross-domain use.

**Do NOT** store tokens in `localStorage` / `sessionStorage`. XSS bypasses them trivially.

### Mobile / native

Use platform keychain:
- iOS: Keychain Services (`SecItemAdd`)
- Android: EncryptedSharedPreferences or Android Keystore

## Refresh token rotation

Each use of a refresh token returns a new refresh token; the old one is invalidated.

```python
@app.route('/refresh')
def refresh():
    old_rt = session['refresh_token']
    resp = requests.post(PROVIDER_TOKEN_URL, data={
        'grant_type': 'refresh_token',
        'refresh_token': old_rt,
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET,
    })
    new_tokens = resp.json()
    session['access_token']  = new_tokens['access_token']
    session['refresh_token'] = new_tokens['refresh_token']  # rotated
    session['expires_at']    = time.time() + new_tokens['expires_in']
```

If a rotated refresh token is reused → the provider treats it as theft and revokes the whole family. This is the right behavior.

## Scopes

Design scopes to be **fine-grained** but **groupable**.

- Too coarse: `read`, `write` — gives everything.
- Too fine: `read_user_email`, `read_user_name`, ... — UX nightmare.
- Right: `profile`, `email`, `orders:read`, `orders:write`, `payments:read`.

Default to **least-privilege**: request only the scopes you need now. You can request more later via incremental authorization.

## Client Credentials (service-to-service)

```python
resp = requests.post(PROVIDER_TOKEN_URL, data={
    'grant_type': 'client_credentials',
    'client_id': SVC_CLIENT_ID,
    'client_secret': SVC_CLIENT_SECRET,
    'scope': 'orders:read',
})
```

**Note**: no user, no refresh token (request a new access token before each expiry). Use a short-TTL cache to avoid hammering the token endpoint.

## Common attacks and defenses

| Attack | Defense |
|---|---|
| CSRF on authorize endpoint | `state` parameter, validated |
| Authorization code interception | PKCE (code_verifier) |
| Replay of `code` | One-time use enforced by provider |
| Token leakage via referrer | Use POST or fragment, not query string |
| Open redirect via `redirect_uri` | Strict allowlist on provider side; never wildcard |
| Mixed-up provider attack | Always validate `iss` in ID token |
| `alg: none` JWT attack | Explicit algorithm allowlist on verify |
| XSS steals tokens | httpOnly cookies, BFF pattern, never localStorage |
| Refresh token theft | Rotation + family revocation |
| Privilege escalation via scope manipulation | Server validates granted scopes, not client claims |

## Redirect URIs (the most-forgotten attack surface)

- Allowlist exact URIs (with path), not just origins.
- Disallow wildcards (`*.example.com` is dangerous).
- HTTPS only in production. `http://localhost` for dev only.
- Reject `redirect_uri` mismatch loudly — don't fall back to a default.

## Discovery (OIDC)

Most providers expose `/.well-known/openid-configuration`. Fetch it once, cache, and use:

```json
{
  "issuer": "https://provider",
  "authorization_endpoint": "https://provider/authorize",
  "token_endpoint": "https://provider/token",
  "userinfo_endpoint": "https://provider/userinfo",
  "jwks_uri": "https://provider/.well-known/jwks.json",
  "response_types_supported": ["code", "id_token", ...],
  "subject_types_supported": ["public"],
  "id_token_signing_alg_values_supported": ["RS256", ...]
}
```

Don't hardcode endpoints; discovery makes provider changes painless.

## If you're building an OAuth provider

Don't roll your own. Use:
- **Ory Hydra** (Go, open source, self-hosted)
- **Keycloak** (Java, full IdM)
- **Auth0** / **Okta** / **Clerk** / **Stytch** (managed)
- **Authentik** / **Authelia** (lightweight self-hosted)

The spec is hundreds of pages. The edge cases are dozens of CVEs. Use a proven implementation.

## Anti-patterns

- **Implicit flow for new apps** — deprecated for 5+ years; still seen in old tutorials.
- **Skipping PKCE because "we have a secret"** — PKCE is also a defense against code injection, not just for public clients.
- **Storing client secrets in mobile/SPA code** — not secret anymore.
- **Using OAuth as authentication without OIDC** — access tokens are for resource access, not identity. Always use ID tokens for "who is the user".
- **Validating ID token without `aud` check** — token issued for another app accepted as yours.
- **`Bearer` tokens in URLs** — leaked to logs, analytics, referrer headers.
- **Long-lived access tokens** — keep < 1h, refresh as needed.
- **Trusting the `email` claim without `email_verified: true`** — anyone can claim any email at registration.
