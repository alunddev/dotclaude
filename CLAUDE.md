# Project rules for Claude Code

This file is a portable template. Drop the entire `.claude/` directory and this `CLAUDE.md` into any project — they adapt to the stack via lockfile detection. Override per project by appending to `CLAUDE.local.md` (gitignored).

---

## 1. Delegate aggressively

You have 113 specialist agents in `.claude/agents/`. **Use them.** A handful of rules:

1. **Before doing anything non-trivial, ask: "Is there an agent for this?"** If yes, delegate via the `Agent` tool with `subagent_type: "<agent-name>"`. The full roster is in `.claude/agents/` — every `.md` filename (without extension) is a valid `subagent_type`.
2. **Language detection drives routing.** Editing a `.py` file → consider `python-pro`. A `.ts/.tsx` file → `typescript-pro` (or `react-specialist` for components). A `.go` file → `golang-pro`. And so on for every supported language (see §6).
3. **Multiple agents in parallel is normal.** A new feature can fan out to `backend-developer` + `frontend-developer` + `test-automator` running concurrently. Use multiple Agent calls in one message.
4. **Delegation cost is low; under-delegation cost is high.** A 100-line change that touches auth and DB should pull in `security-auditor` and `database-administrator` even if the change "seems simple". You can always merge their reports yourself.
5. **Trivial work doesn't need an agent.** A typo fix or a one-line variable rename does not need a specialist. Roughly: if the task takes you less than a minute and touches no business logic, do it inline.

**Auto-trigger rules (apply without being asked):**

| Situation | Agent to invoke | When |
|---|---|---|
| Any code change committed/staged | `code-reviewer` | After the change, before reporting "done" |
| Error, exception, failing test, or unexpected output | `debugger` | The moment it appears, before guessing at the cause |
| Stack trace, log dump, or production-incident triage | `error-detective` | Same |
| Touching auth, secrets, user input, crypto, HTTP boundaries, deps | `security-auditor` | Before the change is finalized |
| New endpoint/route/handler with no test | `test-automator` | Before merging |
| Latency, memory, CPU, throughput concerns | `performance-engineer` | At first sign |
| UI / frontend change | `accessibility-tester` | Before merging |
| API contract change (REST/GraphQL/gRPC) | `api-designer` + `api-documenter` | At design + at doc time |
| Schema change, migration, new index | `database-administrator` | Before applying |
| Slow query | `database-optimizer` | First |
| Dependency add / upgrade | `dependency-manager` + `security-auditor` | At the moment of change |
| Architectural decision or large refactor | `architect-reviewer` + `refactoring-specialist` | Before starting |
| Cross-cutting feature (touches >3 modules) | `context-manager` first, then specialists | Plan, then execute |
| Production incident | `devops-incident-responder` | Immediately |
| CI/CD or Dockerfile / k8s / terraform change | `devops-engineer` (+ relevant specialist) | At change time |
| Adding/editing public docs | `documentation-engineer` + `technical-writer` | Same |
| Onboarding a new codebase | `code-archaeologist` first, then `codebase-orchestrator` | First thing |
| Quick proof-of-concept ("spike", "POC", "try it") | `spike-engineer` | When idea-validation > correctness |
| Version bump / changelog / release | `release-coordinator` | At release time |

If a situation is ambiguous, prefer **delegating** over not. The cost of asking is low.

---

## 2. How agents, skills, and commands interact

- **Agents** = isolated specialists with their own context window. Spawn via `Agent` tool. Return a report; you synthesize.
- **Skills** = on-demand knowledge packs in `.claude/skills/`. Loaded by the model when relevant — no manual invocation. 35 skills cover API design, auth, testing patterns, K8s, observability, language idioms, etc.
- **Commands** = slash-prefixed entry points in `.claude/commands/`. User-typed (`/ship`, `/full-review`, etc.). You can also invoke them from instructions.

When in doubt: **agent for who, skill for what-knowledge, command for how-to-start.**

---

## 3. Working agreements

- **Edit, don't rewrite.** Prefer `Edit` over `Write` on existing files. Never recreate a file that exists.
- **Tests live next to code.** `foo.ts` → `foo.test.ts`. Python projects use the `tests/` mirror tree.
- **No comments unless WHY is non-obvious.** Self-documenting names beat comments. Don't narrate what the code does.
- **No dead scaffolding.** Don't add error handling, retries, abstractions, or feature flags for hypothetical needs. Validate only at system boundaries (HTTP input, external APIs, user input).
- **Conventional commits.** `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`, `perf:`, `build:`, `ci:`.
- **Small, reviewable units of work.** Aim for diffs under 400 lines when possible. Bigger = split.
- **Verify before reporting done.** Run the relevant test/lint/typecheck. If you can't, say so explicitly.

---

## 4. Safety rails (hard rules)

- **Never push to `main` / `master` / `trunk` directly.** Always work on a branch.
- **Never `git push --force` to a shared branch** without explicit user approval. `--force-with-lease` to your own branch is allowed.
- **Never `git reset --hard` on uncommitted work** without saving a stash first.
- **Never commit `.env*`, `*.pem`, `*.key`, `*credentials*`, `*secret*`, `*token*`.** Check before staging.
- **Never use `--no-verify`** unless the user explicitly asks. If a hook fails, fix the underlying issue.
- **Never modify CI/CD pipelines, GitHub Actions, or deploy scripts without confirmation** — they affect shared infra.
- **Never run destructive operations** (`rm -rf`, `DROP TABLE`, `kubectl delete`, infra teardown) without user approval, even if it "looks safe".

---

## 5. Deployment, without GitHub assumptions

This setup does **not** require a GitHub remote, the `gh` CLI, or any specific Git host. Deployment paths Claude should consider in order:

1. **Local-first**: `/ship` runs install → lint → typecheck → test → build locally. That's the contract.
2. **Direct provider**: Vercel CLI (`vercel deploy`), Netlify CLI (`netlify deploy`), `gcloud app deploy`, `aws ecs update-service`, `flyctl deploy`, `railway up`, `wrangler deploy`. Use whichever the project is set up for.
3. **Container**: `docker build` + push to whatever registry the project uses.
4. **K8s**: `kubectl apply`, Helm, or whatever GitOps tool is wired up.

If none of the above is configured, **ask the user how they deploy** rather than assuming. Don't introduce GitHub Actions just because you don't see another mechanism.

---

## 6. Stack support — agents available

The agent roster covers any modern stack you'll work in. Non-exhaustive list of what to reach for:

- **Web frontend**: `react-specialist`, `vue-expert`, `angular-architect`, `nextjs-developer`, `frontend-developer`, `ui-designer`, `ui-ux-tester`, `accessibility-tester`, `design-bridge`
- **Web backend**: `backend-architect`, `backend-developer`, `node-specialist`, `django-developer`, `fastapi-developer`, `rails-expert`, `laravel-specialist`, `symfony-specialist`, `spring-boot-engineer`, `dotnet-core-expert`, `php-pro`, `graphql-architect`, `microservices-architect`, `websocket-engineer`
- **Languages**: `typescript-pro`, `javascript-pro`, `python-pro`, `golang-pro`, `rust-engineer`, `java-architect`, `kotlin-specialist`, `swift-expert`, `cpp-pro`, `csharp-developer`, `php-pro`, `elixir-expert`, `sql-pro`
- **Mobile**: `mobile-developer`, `flutter-expert`, `expo-react-native-expert`, `swift-expert` (iOS), `kotlin-specialist` (Android), `electron-pro` (desktop)
- **DevOps / Infra**: `devops-engineer`, `cloud-architect`, `platform-engineer`, `sre-engineer`, `docker-expert`, `kubernetes-specialist`, `terraform-engineer`, `deployment-engineer`, `network-engineer`, `devops-incident-responder`
- **Data / AI**: `data-engineer`, `data-analyst`, `data-scientist`, `ml-engineer`, `mlops-engineer`, `machine-learning-engineer`, `nlp-engineer`, `ai-engineer`, `llm-architect`, `prompt-engineer`, `vector-database-engineer`
- **Databases**: `database-administrator`, `database-optimizer`, `postgres-pro`, `sql-pro`
- **Quality / Security**: `code-reviewer`, `qa-expert`, `test-automator`, `debugger`, `error-detective`, `performance-engineer`, `chaos-engineer`, `security-auditor`, `security-engineer`, `penetration-tester`, `compliance-auditor`
- **Specialized**: `game-developer`, `unity-developer`, `embedded-systems`, `iot-engineer`, `blockchain-developer`, `payment-integration`, `fintech-engineer`, `wordpress-master`, `seo-specialist`
- **DX / Meta**: `architect-reviewer`, `refactoring-specialist`, `legacy-modernizer`, `code-archaeologist`, `release-coordinator`, `spike-engineer`, `dx-optimizer`, `build-engineer`, `dependency-manager`, `monorepo-architect`, `git-workflow-manager`, `cli-developer`, `tooling-engineer`, `documentation-engineer`, `technical-writer`, `readme-generator`, `api-documenter`, `mcp-developer`
- **Orchestration**: `multi-agent-coordinator`, `agent-organizer`, `codebase-orchestrator`, `workflow-orchestrator`, `context-manager`, `task-distributor`, `error-coordinator`, `knowledge-synthesizer`, `performance-monitor`
- **Research**: `research-analyst`, `search-specialist`
- **Business-adjacent**: `product-manager`, `scrum-master`, `license-engineer`

Don't memorize this list. The `.claude/agents/` directory is the source of truth — `ls .claude/agents` to refresh.

---

## 7. Slash commands available

- `/ship` — local build + lint + typecheck + test + build gate (VCS-agnostic)
- `/full-review` — multi-agent comprehensive review of pending changes
- `/feature-dev` — orchestrated full-feature pipeline (requirements → tests → impl → review → QA)
- `/git-workflow` — branch + commit + (optional) PR with quality gates
- `/pr-enhance` — improve a PR description from diffs
- `/refactor-clean` — targeted refactor with safety checks
- `/tech-debt` — surface and prioritize tech debt
- `/tdd-cycle` — red → green → refactor with agent support
- `/security-sast` — SAST scan
- `/security-deps` — dependency vulnerability scan
- `/error-analysis` — root-cause analysis on traces/logs
- `/onboard` — onboard a new contributor / new project

---

## 8. Path-scoped rules

`.claude/rules/` holds per-path rules that load only when matching files are touched. See `.claude/rules/api.md` for an example. Add more `*.md` files there with a `globs:` frontmatter to scope them.

---

## 9. Per-project overrides

Append to `CLAUDE.local.md` (gitignored) for project-specific overrides. This template stays clean and copy-paste-able across projects.
