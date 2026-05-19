---
name: docker-patterns
description: Production-grade Docker patterns — multi-stage builds, image size optimization, security hardening, layer caching, compose for local dev. Use when authoring Dockerfiles, debugging slow builds, oversized images, or container security issues.
---

# Docker patterns

Practical Docker patterns that survive production. Focus on small images, fast builds, secure runtime, and predictable local dev.

## When to use this skill

- Authoring a new Dockerfile
- Debugging slow builds or oversized images
- Hardening containers for production
- Setting up `docker-compose.yml` for local dev
- Migrating from Docker Hub to a private/SHA-pinned registry

## Core principles

1. **One process per container** (with edge cases for sidecars).
2. **Smallest base image that works.** `alpine` < `slim` < full distro.
3. **Layer order = cache wins.** Most-stable layers first, most-volatile last.
4. **Never run as root in the final image.** Even if it "just works".
5. **Pin everything pinnable.** Base image SHA, app dependencies, build tools.

## Multi-stage build pattern

The single highest-impact pattern. Builder stage has all dev deps; final stage only has the artifact.

### Node.js / TypeScript

```dockerfile
# syntax=docker/dockerfile:1.7
FROM node:20.11-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

FROM node:20.11-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build

FROM node:20.11-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup -S app && adduser -S app -G app
COPY --from=deps  --chown=app:app /app/node_modules ./node_modules
COPY --from=build --chown=app:app /app/dist         ./dist
COPY --chown=app:app package.json ./
USER app
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

Key elements: separate `deps` stage for prod deps (cached when only source changes), separate `build` stage (has dev deps), final stage copies only what runtime needs.

### Python

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS build
WORKDIR /app
RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

FROM python:3.12-slim AS runtime
WORKDIR /app
RUN groupadd -r app && useradd -r -g app app
COPY --from=build --chown=app:app /app/.venv /app/.venv
COPY --chown=app:app . .
ENV PATH="/app/.venv/bin:$PATH"
USER app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Go (smallest possible)

```dockerfile
# syntax=docker/dockerfile:1.7
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/app ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```

Distroless + static binary = ~10MB image, zero shell, near-zero attack surface.

## Image size optimization

Order matters. Apply in this sequence:

1. **Use multi-stage.** Skip dev deps in final image.
2. **Pick the right base.** `alpine` for most things, `distroless` when possible, `slim` when alpine misses libs.
3. **Combine `RUN` commands** when they touch the same layer's data:
   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends \
       curl ca-certificates \
       && rm -rf /var/lib/apt/lists/*
   ```
4. **`.dockerignore` is mandatory.** Exclude `.git`, `node_modules`, `__pycache__`, `dist`, `.env*`, `*.log`, IDE files.
5. **Don't copy what you don't need.** `COPY package.json ./` instead of `COPY . .` when only deps are needed.

## Layer caching strategy

Docker rebuilds from the first changed layer downward. Order layers from least-volatile to most-volatile:

```dockerfile
# Stable (changes rarely)
FROM node:20-alpine
WORKDIR /app

# Less stable (changes when deps change)
COPY package.json package-lock.json ./
RUN npm ci

# Volatile (changes on every commit)
COPY . .
RUN npm run build
```

**Anti-pattern:**
```dockerfile
COPY . .          # ← invalidates everything below on ANY source change
RUN npm ci
RUN npm run build
```

## Security hardening

### Non-root user

Every production image MUST run as non-root:

```dockerfile
RUN addgroup -S app && adduser -S app -G app
USER app
```

For Python:
```dockerfile
RUN groupadd -r app && useradd -r -g app app
USER app
```

### Read-only root filesystem

In production runtime (k8s / compose):

```yaml
securityContext:
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 10001
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

App must write only to mounted `emptyDir` or volume.

### Pinned base images

Pin by SHA in production, not by tag:

```dockerfile
FROM node:20.11-alpine@sha256:abc123...
```

Tags are mutable; SHAs are immutable. Use Renovate / Dependabot to bump them.

### Scan before push

```bash
trivy image my-image:tag
grype my-image:tag
docker scout cves my-image:tag
```

Wire this into CI. Block on `CRITICAL` and `HIGH` CVEs in app dependencies.

## docker-compose.yml for local dev

```yaml
services:
  app:
    build:
      context: .
      target: build          # use the builder stage for hot-reload
    volumes:
      - .:/app
      - /app/node_modules    # named volume so host doesn't shadow it
    environment:
      DATABASE_URL: postgres://app:dev@db:5432/app
    ports: ["3000:3000"]
    depends_on:
      db: { condition: service_healthy }

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: app
    ports: ["5432:5432"]
    volumes: ["db_data:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "app"]
      interval: 2s
      timeout: 5s
      retries: 10

volumes:
  db_data:
```

Healthchecks on dependencies prevent the classic "app starts before DB" race.

## BuildKit features worth using

Enable BuildKit (`DOCKER_BUILDKIT=1` or `docker buildx`). Then:

- **Cache mounts** — speed up package managers:
  ```dockerfile
  RUN --mount=type=cache,target=/root/.npm npm ci
  ```
- **Secret mounts** — never bake secrets into layers:
  ```dockerfile
  RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
  ```
  Build with: `docker build --secret id=npmrc,src=$HOME/.npmrc .`
- **SSH mounts** for private git deps:
  ```dockerfile
  RUN --mount=type=ssh git clone git@github.com:org/private-repo.git
  ```

## Anti-patterns

- **`FROM node:latest`** — non-reproducible builds. Pin to a major+minor.
- **`COPY . .` before `npm ci`** — cache miss on every source change.
- **Building inside production base image** — bloats final image with build tools.
- **`USER root` in final image** — container escape becomes host root.
- **`apt-get install -y` without `--no-install-recommends`** — pulls in dozens of unneeded packages.
- **`ADD` for local files** — use `COPY`. `ADD` magic (tar extraction, URL fetch) bites you eventually.
- **Hardcoded ports/hosts** — use ENV vars.
- **Missing `EXPOSE`** — documentation matters even if not strictly required.
- **No `HEALTHCHECK`** — k8s and compose use it; orchestrators benefit.

## Debugging slow builds

```bash
# Show layer sizes
docker history my-image:tag

# Time each step
DOCKER_BUILDKIT=1 docker build --progress=plain .

# See what's in the build context
tar -tf <(docker build -f Dockerfile -t test .) | head -50
```

If the build context is huge: `.dockerignore` is missing or wrong.

## Image registry hygiene

- Tag releases with semver: `myapp:1.2.3` AND `myapp:latest` AND `myapp:1.2.3@sha256:...`
- Keep a `:nightly` for HEAD if you need it.
- Garbage collect old tags. Registry storage is real money at scale.
- Sign images (Cosign, Notary v2) for production deploys.
