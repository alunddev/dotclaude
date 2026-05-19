#!/usr/bin/env bash
# .claude/setup.sh — initialize the .claude/ folder for the current project.
# Idempotent: safe to run multiple times.
#
# Usage:
#   bash .claude/setup.sh           # full init
#   bash .claude/setup.sh --check   # validation only, no changes

set -eu

MODE="${1:-init}"
CLAUDE_DIR=".claude"
errors=0
warnings=0

red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

err()  { red   "  ❌ $*"; errors=$((errors+1)); }
ok()   { green "  ✓  $*"; }
warn() { yellow "  ⚠  $*"; warnings=$((warnings+1)); }

bold "Claude Code project setup"
echo ""

# --- 1) Required files present ---
echo "1. Required files"
[ -d "$CLAUDE_DIR" ]                || err "$CLAUDE_DIR/ directory not found — copy it from the source project"
[ -f "CLAUDE.md" ]                  || err "CLAUDE.md not found in project root"
[ -f "$CLAUDE_DIR/settings.json" ]  || err "$CLAUDE_DIR/settings.json not found"
[ -f "$CLAUDE_DIR/statusline" ]     || warn "$CLAUDE_DIR/statusline not found (statusline will use default)"
[ "$errors" -gt 0 ] && { echo ""; red "Fatal — required files missing. Aborting."; exit 1; }
ok "all required files present"
echo ""

# --- 2) settings.json validity ---
echo "2. settings.json"
if python3 -c "import json; json.load(open('$CLAUDE_DIR/settings.json'))" 2>/dev/null; then
  ok "valid JSON"
  mode=$(python3 -c "import json; print(json.load(open('$CLAUDE_DIR/settings.json'))['permissions'].get('defaultMode', 'default'))")
  ok "permission mode: $mode"
else
  err "settings.json is not valid JSON"
fi
echo ""

# --- 3) Hooks executable ---
echo "3. Hooks"
if [ "$MODE" != "--check" ]; then
  find "$CLAUDE_DIR/hooks" -name '*.sh' -type f -exec chmod +x {} \; 2>/dev/null
  [ -f "$CLAUDE_DIR/statusline" ] && chmod +x "$CLAUDE_DIR/statusline"
fi
for h in "$CLAUDE_DIR/hooks/"*.sh; do
  [ -f "$h" ] || continue
  if [ -x "$h" ]; then
    ok "executable: $(basename $h)"
  else
    err "not executable: $(basename $h)"
  fi
done
echo ""

# --- 4) State directories ---
echo "4. State directories"
if [ "$MODE" != "--check" ]; then
  mkdir -p "$CLAUDE_DIR/state"
  ok "created $CLAUDE_DIR/state/"
else
  [ -d "$CLAUDE_DIR/state" ] && ok "$CLAUDE_DIR/state/ exists" || warn "$CLAUDE_DIR/state/ missing (will be created on first run)"
fi
echo ""

# --- 5) Agents integrity ---
echo "5. Agents"
n_agents=$(ls "$CLAUDE_DIR/agents/"*.md 2>/dev/null | wc -l)
ok "agents found: $n_agents"
broken=0
for f in "$CLAUDE_DIR/agents/"*.md; do
  [ -f "$f" ] || continue
  grep -q "^name:" "$f" && grep -q "^description:" "$f" && grep -q "^model:" "$f" || { err "broken frontmatter: $(basename $f)"; broken=$((broken+1)); }
done
[ "$broken" -eq 0 ] && ok "all frontmatters valid"
echo ""

# --- 6) Subagent refs in commands resolve ---
echo "6. Command → agent references"
agents_set=$(ls "$CLAUDE_DIR/agents/" 2>/dev/null | sed 's/.md$//' | sort -u)
missing=""
for r in $(grep -h -oE 'subagent_type: "[a-z-]+"' "$CLAUDE_DIR/commands/"*.md 2>/dev/null | sed 's/subagent_type: "//;s/"//' | sort -u); do
  [ "$r" = "general-purpose" ] && continue
  echo "$agents_set" | grep -q "^${r}$" || missing="$missing $r"
done
if [ -z "$missing" ]; then
  ok "all subagent refs resolve"
else
  err "missing agents:$missing"
fi
echo ""

# --- 7) Skills integrity ---
echo "7. Skills"
n_skills=$(ls -d "$CLAUDE_DIR/skills/"*/ 2>/dev/null | wc -l)
ok "skills found: $n_skills"
broken=0
for d in "$CLAUDE_DIR/skills/"*/; do
  [ -d "$d" ] || continue
  [ -f "$d/SKILL.md" ] || { err "missing SKILL.md: $(basename $d)"; broken=$((broken+1)); continue; }
  grep -q "^name:" "$d/SKILL.md" && grep -q "^description:" "$d/SKILL.md" || { err "broken frontmatter: $(basename $d)"; broken=$((broken+1)); }
done
[ "$broken" -eq 0 ] && ok "all skills valid"
echo ""

# --- 8) Optional: .mcp.json ---
echo "8. MCP servers"
if [ -f ".mcp.json" ]; then
  if python3 -c "import json; json.load(open('.mcp.json'))" 2>/dev/null; then
    n_mcps=$(python3 -c "import json; print(len(json.load(open('.mcp.json'))['mcpServers']))")
    ok ".mcp.json valid — $n_mcps servers configured"
    if ! command -v npx >/dev/null 2>&1; then
      warn "npx not found — MCP servers require Node.js"
    fi
  else
    err ".mcp.json is not valid JSON"
  fi
else
  warn ".mcp.json not found (MCP servers disabled — optional)"
fi
echo ""

# --- 9) .gitignore covers personal state ---
echo "9. .gitignore"
if [ -f ".gitignore" ]; then
  if grep -q "$CLAUDE_DIR/state" .gitignore && grep -q "$CLAUDE_DIR/settings.local.json" .gitignore; then
    ok "covers $CLAUDE_DIR/state/ and settings.local.json"
  else
    warn ".gitignore should include: $CLAUDE_DIR/state/, $CLAUDE_DIR/settings.local.json, CLAUDE.local.md"
  fi
else
  warn ".gitignore not found (consider creating one)"
fi
echo ""

# --- Summary ---
bold "Summary"
if [ "$errors" -eq 0 ]; then
  green "✅ Setup complete. $warnings warning(s)."
else
  red   "❌ Setup found $errors error(s), $warnings warning(s). Fix before using Claude Code."
  exit 1
fi
