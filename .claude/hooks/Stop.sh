#!/usr/bin/env bash
# Stop hook — fires when Claude finishes responding (end of turn).
# Use to persist session summaries for later resume.

set -eu

STATE_DIR=".claude/state"
mkdir -p "$STATE_DIR"

ts=$(date +%Y-%m-%d)
log="$STATE_DIR/sessions-${ts}.log"

# Append a minimal end-of-turn line: timestamp + git head + dirty file count
{
  printf '%s' "$(date -Iseconds)  "
  if [ -d .git ]; then
    head=$(git log -1 --oneline 2>/dev/null || echo no-commits)
    modified=$(git status --porcelain 2>/dev/null | wc -l)
    printf 'HEAD=%s  modified=%s' "$head" "$modified"
  else
    printf 'no-vcs'
  fi
  echo ""
} >> "$log"

# Rotate: keep the last 30 days
find "$STATE_DIR" -name 'sessions-*.log' -type f -mtime +30 -delete 2>/dev/null || true

exit 0
