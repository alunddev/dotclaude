# `.claude/` — autonomous Claude Code config

Portable, copy-paste-able config for full-stack development with Claude Code. Drop this directory + `CLAUDE.md` + `.mcp.json` into any project root.

## Layout

```
.claude/
├── settings.json          Permissions, hook registry, default mode
├── statusline             Bash script — branch + stack in status bar
├── README.md              This file
├── hooks/                 Deterministic event handlers
│   ├── SessionStart.sh    Stack detection + delegation reminder at session start
│   ├── PreCompact.sh      Snapshot before context compaction
│   ├── PostToolUse.sh     (disabled by default — auto-format template)
│   ├── UserPromptSubmit.sh Routing-hint injection based on prompt keywords
│   ├── Stop.sh            Per-turn session log → .claude/state/sessions-*.log
│   └── Notification.sh    Desktop notification on attention requests
├── commands/              Slash commands (/ship, /full-review, /feature-dev, etc.)
├── skills/                On-demand knowledge packs (35 skills)
├── agents/                Specialist subagents (116 agents, 65 with auto-trigger)
├── output-styles/         Response style profiles (terse / code-only / paranoid / teacher)
├── rules/                 Path-scoped rules (api, backend, frontend, mobile, infra, data, security, tests)
├── plugins/               Reserved for first-class plugins (2026+)
└── state/                 Per-project runtime state (gitignored)
```

## First-time setup in a new project

```bash
# 1. Copy this directory + CLAUDE.md + .mcp.json + .gitignore into your project root
cp -r /path/to/.claude .
cp /path/to/CLAUDE.md .
cp /path/to/.mcp.json .
# Merge .gitignore manually if you already have one

# 2. Run the setup script
bash .claude/setup.sh

# 3. Open Claude Code — the SessionStart hook auto-detects the stack
claude
```

## How auto-invocation works

Three reinforcing mechanisms make Claude delegate aggressively without prompting:

1. **`CLAUDE.md` §1** — explicit routing table mapping situations to agents
2. **Agent descriptions with `Use PROACTIVELY when ...`** — 65 of 116 agents have this trigger pattern
3. **`UserPromptSubmit` hook** — injects a one-line routing hint based on keyword matching in your prompt

The hook is conservative (only suggests, doesn't force) so it doesn't fight with Claude's own judgment.

## How no-prompts works

`settings.json` sets `"defaultMode": "bypassPermissions"`. Claude doesn't ask before running tools. **Destructive operations still hard-block** via the `deny` list (63 rules covering `rm -rf /`, `git push --force`, `terraform destroy`, dropping DBs, package publishing, etc.).

To temporarily re-enable prompts for a sensitive session: `claude --permission-mode default` or edit `defaultMode` in settings.

## How GitHub-independence works

- `/ship` detects the package manager from lockfiles — runs local install/lint/typecheck/test/build, no `gh` CLI.
- `release-coordinator` agent generates changelogs from `git log`, creates tags locally, stops before pushing.
- No command depends on `gh`, `github.com`, or a remote being configured.
- If you later add GitHub, nothing here needs to change.

## How MCPs work

`.mcp.json` configures 6 MCP servers that auto-start when Claude Code launches:

- **filesystem** — read/write outside the workspace (under `~`)
- **fetch** — HTTP content extraction (docs, APIs)
- **sequential-thinking** — structured multi-step reasoning
- **sqlite** — local DB at `.claude/state/local.db`
- **puppeteer** — headless browser for E2E / scraping
- **memory** — cross-session knowledge graph

All six install via `npx -y …` on first use. Comment out any you don't want.

## Customization patterns

- **Per-project rules** — append to `CLAUDE.local.md` (gitignored). Don't edit the shared `CLAUDE.md` unless the rule should apply everywhere.
- **Per-directory rules** — add `.claude/rules/<name>.md` with `globs:` frontmatter scoping the paths.
- **Override the agents you use** — copy the agent's `.md` to project-specific `.claude/agents/` (already covered).
- **Switch output style** — `/output-style terse` or `code-only` / `paranoid` / `teacher`.

## What this is NOT

- Not a plugin marketplace. Plugins go in `plugins/` once you adopt them.
- Not a Claude.ai feature config — these files are for Claude Code CLI only.
- Not a substitute for project-specific docs. Your README still matters.

## Validation

After any edit:

```bash
bash .claude/setup.sh --check
```

This validates: settings.json is parseable, hooks are executable, no broken subagent refs, no skill frontmatter issues.

## Counts (current)

- 116 agents, 65 with PROACTIVELY auto-trigger
- 45 skills (1.2 MB on disk)
- 15 slash commands
- 6 hooks (5 active, 1 optional)
- 8 path-scoped rules
- 4 output styles
- 6 MCP servers
