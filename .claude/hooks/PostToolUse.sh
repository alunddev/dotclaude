#!/usr/bin/env bash
# PostToolUse hook — fires after each tool call. Not registered in settings.json
# by default (too chatty for most workflows). Register it under "hooks.PostToolUse"
# if you want auto-format-on-edit or similar deterministic post-actions.
#
# CLAUDE_TOOL_NAME and CLAUDE_TOOL_INPUT are exported by the harness.

set -eu

case "${CLAUDE_TOOL_NAME:-}" in
  Edit|Write)
    # Example: auto-format the edited file if a formatter is configured.
    # Customize per project — left commented so it doesn't fire unexpectedly.
    #
    # file=$(echo "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty')
    # case "$file" in
    #   *.ts|*.tsx|*.js|*.jsx) npx prettier --write "$file" 2>/dev/null || true ;;
    #   *.py) black "$file" 2>/dev/null || true ;;
    #   *.go) gofmt -w "$file" 2>/dev/null || true ;;
    # esac
    :
    ;;
esac
