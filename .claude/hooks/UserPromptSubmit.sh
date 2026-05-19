#!/usr/bin/env bash
# UserPromptSubmit hook — fires when the user sends a message.
# Reads the prompt from stdin (JSON), and can output additional context to inject.
#
# We use this to inject a one-line delegation hint based on keyword matching
# in the user's prompt. Cheap, deterministic, low-noise.

set -eu

# Read the user prompt (Claude Code passes JSON on stdin)
input=$(cat)

# Extract the prompt text (basic jq-free extraction)
prompt=$(printf '%s' "$input" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"prompt"[[:space:]]*:[[:space:]]*"//; s/"$//')

# If we couldn't parse, exit silently
[ -z "$prompt" ] && exit 0

# Lowercase for matching
lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')

# Match keywords → suggest a routing
suggest=""
case "$lower" in
  *"refactor"*)         suggest="refactoring-specialist (then code-reviewer after)" ;;
  *"deploy"*|*"ship"*|*"release"*) suggest="release-coordinator + devops-engineer" ;;
  *"slow"*|*"latency"*|*"perf"*)   suggest="performance-engineer" ;;
  *"error"*|*"crash"*|*"exception"*|*"stack trace"*) suggest="debugger + error-detective" ;;
  *"security"*|*"auth"*|*"login"*|*"token"*|*"jwt"*) suggest="security-auditor" ;;
  *"migrate"*|*"migration"*|*"schema"*)              suggest="database-administrator + legacy-modernizer" ;;
  *"refactoring"*|*"clean up"*|*"tech debt"*)        suggest="refactoring-specialist" ;;
  *"design"*"api"*|*"endpoint"*|*"route"*)           suggest="api-designer + backend-developer" ;;
  *"test"*|*"coverage"*)                              suggest="test-automator + qa-expert" ;;
  *"docker"*)                                         suggest="docker-expert" ;;
  *"kubernetes"*|*"k8s"*|*"kubectl"*|*"helm"*)        suggest="kubernetes-specialist" ;;
  *"terraform"*|*"iac"*)                              suggest="terraform-engineer" ;;
  *"spike"*|*"poc"*|*"prototype"*|*"try it"*)         suggest="spike-engineer" ;;
  *"legacy"*|*"old code"*|*"unfamiliar"*)             suggest="code-archaeologist (read-only) or legacy-modernizer" ;;
  *"onboard"*|*"new project"*|*"new codebase"*)       suggest="code-archaeologist → context-manager" ;;
  *"incident"*|*"outage"*|*"production down"*)        suggest="devops-incident-responder (IMMEDIATELY)" ;;
  *"changelog"*|*"version bump"*|*"semver"*)          suggest="release-coordinator" ;;
esac

if [ -n "$suggest" ]; then
  # Output goes to Claude as additional context
  echo "💡 Routing hint: Consider delegating to → $suggest"
fi

exit 0
