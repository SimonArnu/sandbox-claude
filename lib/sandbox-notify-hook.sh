#!/usr/bin/env bash
# ABOUTME: Claude Code hook that sends notifications to the host via sandbox-notify
# ABOUTME: Installed into containers by sandbox-start, triggered on Stop and AskUserQuestion events

INPUT=$(cat)
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
CONTAINER_NAME=$(hostname)
NOTIFY_URL="${SANDBOX_NOTIFY_URL:-http://10.100.0.1:9876}"
PROJECT=$(basename "$CWD" 2>/dev/null || echo "$CONTAINER_NAME")

case "$HOOK_EVENT" in
  Stop)
    curl -sf --max-time 2 "$NOTIFY_URL" -H "Content-Type: application/json" \
      -d "{\"title\": \"${CONTAINER_NAME}\", \"message\": \"Task complete in ${PROJECT}\"}" \
      >/dev/null 2>&1 || true
    ;;
  PreToolUse)
    TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
    if [[ "$TOOL" == "AskUserQuestion" ]]; then
      QUESTION=$(echo "$INPUT" | jq -r '.tool_input.question // "needs your input"')
      # Truncate long questions
      [[ ${#QUESTION} -gt 120 ]] && QUESTION="${QUESTION:0:117}..."
      curl -sf --max-time 2 "$NOTIFY_URL" -H "Content-Type: application/json" \
        -d "{\"title\": \"${CONTAINER_NAME} — Question\", \"message\": $(echo "$QUESTION" | jq -Rs .), \"urgency\": \"critical\", \"expire\": \"0\"}" \
        >/dev/null 2>&1 || true
    fi
    ;;
esac

# Pass through input unchanged
echo "$INPUT"
