#!/usr/bin/env bash
# SessionStart hook — surface project state + delegation reminder.
# Output goes into the conversation as context for Claude at session start.

set -eu

CLAUDE_DIR=".claude"

echo "=== Claude Code session start ==="
echo "CWD:  $(pwd)"
echo "Date: $(date -Iseconds)"
echo ""

# VCS status (git or jj or none)
if [ -d .git ]; then
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
  head=$(git log -1 --oneline 2>/dev/null || echo 'no commits')
  modified=$(git status --porcelain 2>/dev/null | wc -l)
  echo "--- Git ---"
  echo "Branch:   $branch"
  echo "HEAD:     $head"
  echo "Modified: $modified file(s)"
  if [ "$modified" -gt 0 ] && [ "$modified" -lt 30 ]; then
    echo ""
    git status --short
  fi
elif [ -d .jj ]; then
  echo "--- jj repo detected ---"
else
  echo "--- no VCS detected ---"
fi
echo ""

# Stack signals — lockfiles + manifests
echo "--- Stack signals ---"
[ -f package.json ]      && echo "node          (package.json)"
[ -f pnpm-lock.yaml ]    && echo "  pkg-mgr:    pnpm"
[ -f yarn.lock ]         && echo "  pkg-mgr:    yarn"
[ -f package-lock.json ] && echo "  pkg-mgr:    npm"
[ -f bun.lockb ]         && echo "  pkg-mgr:    bun"
[ -f tsconfig.json ]     && echo "  ts:         typescript"
{ [ -f next.config.js ] || [ -f next.config.mjs ] || [ -f next.config.ts ]; } && echo "  framework:  next.js"
{ [ -f vite.config.js ] || [ -f vite.config.ts ]; } && echo "  framework:  vite"
{ [ -f nuxt.config.js ] || [ -f nuxt.config.ts ]; } && echo "  framework:  nuxt"
[ -f angular.json ]      && echo "  framework:  angular"
[ -f astro.config.mjs ]  && echo "  framework:  astro"
[ -f remix.config.js ]   && echo "  framework:  remix"

[ -f pyproject.toml ]    && echo "python        (pyproject.toml)"
[ -f requirements.txt ]  && echo "python        (requirements.txt)"
[ -f Pipfile ]           && echo "python        (pipenv)"
[ -f poetry.lock ]       && echo "  pkg-mgr:    poetry"
[ -f uv.lock ]           && echo "  pkg-mgr:    uv"
[ -f manage.py ]         && echo "  framework:  django"

[ -f go.mod ]            && echo "go            (go.mod)"
[ -f Cargo.toml ]        && echo "rust          (Cargo.toml)"
[ -f pom.xml ]           && echo "java          (maven)"
{ [ -f build.gradle ] || [ -f build.gradle.kts ]; } && echo "java/kotlin   (gradle)"
[ -f Gemfile ]           && echo "ruby          (Gemfile)"
[ -f composer.json ]     && echo "php           (composer)"
[ -f mix.exs ]           && echo "elixir        (mix)"
[ -f pubspec.yaml ]      && echo "dart/flutter  (pubspec.yaml)"
[ -f Package.swift ]     && echo "swift         (Package.swift)"
ls *.csproj 2>/dev/null  && echo "  .NET project file detected"

# Infra
[ -f Dockerfile ]                                && echo "docker        (Dockerfile)"
{ [ -f docker-compose.yml ] || [ -f compose.yaml ]; } && echo "  compose"
[ -f Chart.yaml ]                                && echo "k8s           (helm chart)"
{ [ -d k8s ] || [ -d kubernetes ]; }             && echo "k8s           (manifests dir)"
{ [ -f main.tf ] || [ -d terraform ]; }          && echo "terraform"
[ -d .github/workflows ]                         && echo "ci            (github actions)"
[ -f .gitlab-ci.yml ]                            && echo "ci            (gitlab)"
{ [ -f vercel.json ] || [ -f netlify.toml ]; }   && echo "deploy        (vercel/netlify)"
[ -f wrangler.toml ]                             && echo "deploy        (cloudflare workers)"
[ -f fly.toml ]                                  && echo "deploy        (fly.io)"
echo ""

# Claude assets
if [ -d "$CLAUDE_DIR/agents" ]; then
  n_agents=$(ls "$CLAUDE_DIR/agents"/*.md 2>/dev/null | wc -l)
  n_skills=$(ls -d "$CLAUDE_DIR/skills"/*/ 2>/dev/null | wc -l)
  n_cmds=$(ls "$CLAUDE_DIR/commands"/*.md 2>/dev/null | wc -l)
  echo "--- Claude assets ---"
  echo "Agents:   $n_agents in .claude/agents/"
  echo "Skills:   $n_skills in .claude/skills/"
  echo "Commands: $n_cmds in .claude/commands/"
  echo ""
  echo "🤖 DELEGATION REMINDER"
  echo "   Before doing non-trivial work, check .claude/agents/ and delegate."
  echo "   See CLAUDE.md §1 for the auto-trigger table."
fi

# Prior stack summary
if [ -f "$CLAUDE_DIR/state/stack.md" ]; then
  echo ""
  echo "--- Cached stack summary (.claude/state/stack.md) ---"
  head -40 "$CLAUDE_DIR/state/stack.md"
fi

echo ""
echo "=== End session-start ==="
