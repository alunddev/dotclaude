---
description: Local pre-ship gate — install, lint, typecheck, test, and build. Stops on first failure with the offending command so you can fix and re-run.
argument-hint: "[--skip-build] [--skip-tests]"
---

# /ship — Local pre-push gate

Run the standard build → lint → typecheck → test → build pipeline locally before pushing. Detect the package manager from lockfiles; fall back to common defaults if none match.

## Procedure

1. **Detect stack** in this order, first match wins:
   - `pnpm-lock.yaml` → use `pnpm`
   - `yarn.lock` → use `yarn`
   - `bun.lockb` → use `bun`
   - `package-lock.json` → use `npm`
   - `pyproject.toml` with `[tool.poetry]` → use `poetry`
   - `pyproject.toml` with `[tool.uv]` or `uv.lock` → use `uv`
   - `requirements.txt` → use `pip`
   - `go.mod` → use `go`
   - `Cargo.toml` → use `cargo`

2. **Run gates in order, stop on first failure.** For Node toolchains:
   - install: `<pm> install --frozen-lockfile` (or `--immutable` for yarn)
   - lint: `<pm> run lint` (skip if no `lint` script)
   - typecheck: `<pm> run typecheck` or `tsc --noEmit` (skip if neither)
   - test: `<pm> test` (respect `--skip-tests`)
   - build: `<pm> run build` (respect `--skip-build`)

   For Python:
   - lint: `ruff check .` if available, else `flake8`
   - typecheck: `mypy .` if configured
   - test: `pytest -q`

   For Go: `go vet ./...`, `go test ./...`, `go build ./...`
   For Rust: `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`, `cargo build`

3. **On failure**, output:
   ```
   ❌ /ship failed at: <stage>
   Command: <full command>
   Exit code: <code>
   First 30 lines of output:
   <output>
   ```
   Stop. Do not continue to later stages. Do not auto-fix unless the user asks.

4. **On success**, output a one-line summary:
   ```
   ✅ /ship passed — install ✓ lint ✓ types ✓ tests ✓ build ✓
   ```

## Arguments

- `--skip-build` — skip the final build stage (useful for fast iteration).
- `--skip-tests` — skip the test stage (use sparingly).

## Notes

- Do NOT push to the remote unless the user explicitly asks.
- Do NOT modify code to make a failing gate pass — surface the failure and let the user decide.
- If multiple lockfiles exist (monorepo), assume the root workspace's package manager.
