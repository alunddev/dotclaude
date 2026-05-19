---
description: Comprehensive project health check — dependencies, security, tests, types, build, dead code, doc coverage. Read-only, no fixes applied.
argument-hint: "[--fast]"
---

# /health-check — Project vitals

A read-only sweep of the project's health. Surfaces issues; does NOT fix them. Pairs well with `/tech-debt` and `/refactor-clean` for follow-up.

## Procedure

Run these checks in parallel where possible. For each, capture: pass/fail/skip, count, and a brief summary.

### Dependencies
- Check for outdated packages: `npm outdated` / `pnpm outdated` / `pip list --outdated` / `cargo outdated` / `go list -m -u all`
- Check for known vulnerabilities: `npm audit` / `pnpm audit` / `pip-audit` / `cargo audit` / `govulncheck`
- Detect unused deps: `depcheck` (Node), `vulture` (Python), language-specific tools

### Security
- Delegate to `security-auditor` with: "Surface security issues in the current codebase. Read-only audit. Focus on auth, input validation, secret handling, and dependency vulns."

### Tests
- Run the test suite once: detect via `/init-stack` if needed.
- Capture: pass count, fail count, skipped, coverage % (if a coverage tool is configured).
- Skip in `--fast` mode.

### Types
- Node + TypeScript: `tsc --noEmit`
- Python: `mypy .` or `pyright` if configured
- Report type errors count + first 5 errors.

### Lint
- Whatever the project uses (`eslint`, `ruff`, `golangci-lint`, `clippy`, etc.).
- Report error count + first 5 issues.

### Build
- Run the project's build command. Capture success/failure + duration.
- Skip in `--fast` mode.

### Dead code
- Delegate to `refactoring-specialist` for a quick scan: "Identify obvious dead code, unused exports, and unreachable branches. Read-only."

### Documentation
- Count public exports vs. documented exports (rough heuristic via JSDoc / docstrings).
- Check README freshness (last-modified vs. latest meaningful commit).

## Output format

Markdown report with sections matching the checks above. Each section:

```
### <Section name>
Status: ✅ / ⚠️ / ❌
Summary: <one line>
Details:
  - <key finding 1>
  - <key finding 2>
  ...
```

Top of report: scoreboard like `Health: 7/10 ✅ ⚠️ ⚠️ ✅ ✅ ❌ ✅ ⚠️ ✅ ✅` so the user can see status at a glance.

End the report with a prioritized "Top 3 things to fix" section.

## Rules

- **Read-only.** No installs, no auto-fixes, no formatting on disk.
- **Don't block on slow checks** if `--fast` is passed — skip build + full test suite.
- If a tool isn't installed (`npm audit` returns nothing because there's no `package.json`), mark **Skip** and move on. Don't error.
