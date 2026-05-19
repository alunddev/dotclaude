#!/usr/bin/env bash
# Notification hook — fires when Claude wants the user's attention
# (e.g. permission prompt arrived, waiting for input, finished a long task).
#
# Sends a desktop notification using `notify-send` on Linux (most common).
# Silently degrades to no-op if no notifier is installed.

set -eu

# Read JSON event from stdin
input=$(cat 2>/dev/null || true)

# Extract message field if present (basic, no jq)
msg=$(printf '%s' "$input" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"message"[[:space:]]*:[[:space:]]*"//; s/"$//')

# Fallback to generic message if parsing failed
[ -z "$msg" ] && msg="Claude Code needs your attention"

# Pick a notifier
if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "Claude Code" -i terminal "Claude Code" "$msg" 2>/dev/null || true
elif command -v osascript >/dev/null 2>&1; then
  # macOS fallback
  osascript -e "display notification \"$msg\" with title \"Claude Code\"" 2>/dev/null || true
fi

# Optional terminal bell (uncomment to enable)
# printf '\a'

exit 0
