---
description: Detect the project's stack from lockfiles + manifests and print a one-screen summary so Claude has fast context on a new project. VCS-agnostic.
argument-hint: ""
---

# /init-stack — Fast stack detection

Run this once when entering an unfamiliar project. It produces a compact summary of:

- Languages, package managers, frameworks
- Entry points, scripts, test commands
- Database, queue, cache (if config files present)
- Containerization + deployment hints
- Suggested agents to delegate to

## Procedure

1. **Detect package managers + languages** (in this order):
   - Node: `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `package-lock.json` → read `package.json` `scripts`
   - Python: `pyproject.toml`, `Pipfile`, `requirements*.txt`, `poetry.lock`, `uv.lock`
   - Go: `go.mod`
   - Rust: `Cargo.toml`
   - Java / Kotlin: `pom.xml`, `build.gradle`, `build.gradle.kts`
   - Ruby: `Gemfile`
   - PHP: `composer.json`
   - .NET: `*.csproj`, `*.sln`
   - Elixir: `mix.exs`
   - Swift: `Package.swift`, `*.xcodeproj`
   - Flutter / Dart: `pubspec.yaml`

2. **Detect frameworks** from key files:
   - `next.config.*` → Next.js
   - `nuxt.config.*` → Nuxt
   - `vite.config.*` → Vite
   - `astro.config.*` → Astro
   - `remix.config.*` → Remix
   - `angular.json` → Angular
   - `manage.py` → Django
   - `app.py` + `flask` import → Flask
   - `pyproject.toml` with `fastapi` → FastAPI
   - `config/application.rb` → Rails
   - `artisan` → Laravel
   - `bin/console` + `symfony` → Symfony
   - `Phoenix` in `mix.exs` → Phoenix
   - `pubspec.yaml` with `flutter:` → Flutter

3. **Detect infra**:
   - `Dockerfile`, `docker-compose.yml` / `compose.yaml`
   - `k8s/`, `kubernetes/`, `*.yaml` with `apiVersion: apps/v1`
   - `Chart.yaml` → Helm
   - `*.tf`, `terragrunt.hcl` → Terraform
   - `.github/workflows/` or `.gitlab-ci.yml` or `.circleci/config.yml`
   - `serverless.yml`, `vercel.json`, `netlify.toml`, `wrangler.toml`, `fly.toml`, `railway.json`

4. **Detect data**:
   - Search for connection strings in `docker-compose.yml` + env examples
   - Common: `postgres://`, `mysql://`, `mongodb://`, `redis://`, `rabbitmq://`, `kafka:`

5. **Print summary** in this format:
   ```
   📦 Stack
     Languages: <list>
     Package managers: <list>
     Frameworks: <list>

   🛠 Scripts
     install:   <command>
     dev:       <command>
     test:      <command>
     build:     <command>
     lint:      <command>

   🗄 Data
     <db>, <cache>, <queue> — or "none detected"

   🚢 Deploy
     <detected providers, or "no deploy config found">

   🤖 Suggested agents (high-confidence routing for this project):
     - <agent-1> — <reason>
     - <agent-2> — <reason>
     ...
   ```

6. **Save the summary** to `.claude/state/stack.md` (create dir if needed) so future sessions can reference it without re-running detection.

## Rules

- Read-only. No installs, no migrations, no destructive operations.
- If detection is ambiguous, list candidates rather than guessing.
- Do not invent scripts that aren't in the actual `package.json` / `pyproject.toml`. Quote what's there.
