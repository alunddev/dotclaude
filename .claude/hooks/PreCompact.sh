#!/usr/bin/env bash
# PreCompact hook — runs just before Claude compacts the context.
# Use this to persist anything that would be expensive to reconstruct after compaction.

set -eu

STATE_DIR=".claude/state"
mkdir -p "$STATE_DIR"

ts=$(date +%Y%m%d-%H%M%S)
out="$STATE_DIR/precompact-$ts.txt"

{
  echo "Pre-compact snapshot at $ts"
  echo ""
  if [ -d .git ]; then
    echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    echo "HEAD:   $(git log -1 --oneline 2>/dev/null || echo none)"
    echo ""
    echo "Working tree:"
    git status --short 2>/dev/null || true
  fi
} > "$out"

# Keep only the 10 most recent snapshots
ls -1t "$STATE_DIR"/precompact-*.txt 2>/dev/null | tail -n +11 | xargs -r rm -f

echo "Saved pre-compact state to $out"
