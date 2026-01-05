#!/bin/bash

# Implement Loop Stop Hook
# Prevents session exit when implement-loop is active

IMPLEMENT_STATE=".claude/implement-loop.local.md"

# Exit early if no active loop
if [[ ! -f "$IMPLEMENT_STATE" ]]; then
  exit 0
fi

# Read hook input from stdin
HOOK_INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path' 2>/dev/null || echo "")

# Get last assistant output from transcript
get_last_output() {
  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    local last_line=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || echo "")
    if [[ -n "$last_line" ]]; then
      echo "$last_line" | jq -r '
        .message.content |
        if type == "array" then
          map(select(.type == "text")) |
          map(.text) |
          join("\n")
        else
          ""
        end
      ' 2>/dev/null || echo ""
    fi
  fi
}

# Check for completion signals in output
check_completion_signals() {
  local signals="$1"
  local output=$(get_last_output)
  if [[ -n "$output" ]] && echo "$output" | grep -qiE "$signals"; then
    return 0
  fi
  return 1
}

# Parse markdown frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$IMPLEMENT_STATE" 2>/dev/null || echo "")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "1")
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "0")
PLAN_PATH=$(echo "$FRONTMATTER" | grep '^plan_path:' | sed 's/plan_path: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
STEP_MODE=$(echo "$FRONTMATTER" | grep '^step_mode:' | sed 's/step_mode: *//' || echo "true")

# Validate numeric fields
[[ ! "$ITERATION" =~ ^[0-9]+$ ]] && ITERATION=1
[[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] && MAX_ITERATIONS=0

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Implement loop: Max iterations ($MAX_ITERATIONS) reached."
  rm -f "$IMPLEMENT_STATE"
  exit 0
fi

# Check plan exists
if [[ -z "$PLAN_PATH" ]] || [[ ! -f "$PLAN_PATH" ]]; then
  echo "Implement loop: Plan file not found, ending loop" >&2
  rm -f "$IMPLEMENT_STATE"
  exit 0
fi

# Check for completion signals
if check_completion_signals "exit criteria.*passed|implementation complete|all todos.*completed|all tasks.*completed|verification.*passed"; then
  echo "Implement loop: Completion signal detected!"
  rm -f "$IMPLEMENT_STATE"
  exit 0
fi

# Check for stop signal
if check_completion_signals "^stop$|stopping implement|stop implement loop"; then
  echo "Implement loop: Stop signal detected. Ending loop."
  rm -f "$IMPLEMENT_STATE"
  exit 0
fi

# Check for continue signal (step mode)
CONTINUE_DETECTED=false
if [[ "$STEP_MODE" == "true" ]]; then
  if check_completion_signals "^continue$|continue to next|proceed to next|next todo"; then
    CONTINUE_DETECTED=true
  fi
fi

# STEP MODE: Pause for human decision
if [[ "$STEP_MODE" == "true" ]] && [[ "$CONTINUE_DETECTED" == "false" ]] && [[ $ITERATION -gt 1 ]]; then
  PLAN_NAME=$(basename "$PLAN_PATH")

  PAUSE_PROMPT="===============================================================
TODO COMPLETED - Iteration $ITERATION
===============================================================

Plan: $PLAN_NAME

Use AskUserQuestion to let the user choose:

1. Continue (Recommended) - proceed to next todo
2. Stop - end the implement loop
3. Feedback - free text for other actions

==============================================================="

  SYSTEM_MSG="Implement loop paused | Iteration $ITERATION | Plan: $PLAN_NAME

IMPORTANT: Use AskUserQuestion tool with options:
- Option 1: \"Continue\" (recommended) - next pending todo
- Option 2: \"Stop\" - end the loop
- \"Other\" is automatic for feedback"

  jq -n \
    --arg prompt "$PAUSE_PROMPT" \
    --arg msg "$SYSTEM_MSG" \
    '{
      "decision": "block",
      "reason": $prompt,
      "systemMessage": $msg
    }' 2>/dev/null || echo '{"decision":"block","reason":"Todo completed. Say continue or stop."}'

  exit 0
fi

# AUTO MODE or CONTINUE detected: Continue loop
NEXT_ITERATION=$((ITERATION + 1))

# Update state file
cat > "$IMPLEMENT_STATE" <<EOF
---
active: true
iteration: $NEXT_ITERATION
max_iterations: $MAX_ITERATIONS
plan_path: "$PLAN_PATH"
step_mode: $STEP_MODE
started_at: "$(echo "$FRONTMATTER" | grep '^started_at:' | sed 's/started_at: *//' | sed 's/^"\(.*\)"$/\1/' || date -u +%Y-%m-%dT%H:%M:%SZ)"
---

## Implementation Loop State

Plan: $PLAN_PATH
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "Step (pause after each todo)"; else echo "Auto (continuous)"; fi)
Iteration: $NEXT_ITERATION

### Instructions

1. Check todo status
2. Find next pending todo, mark as in_progress
3. Implement following the plan
4. Mark todo as completed
$(if [[ "$STEP_MODE" == "true" ]]; then echo "5. Wait for human to say 'continue' or 'stop'"; else echo "5. Auto-continue to next todo"; fi)
6. Repeat until all todos completed

Say "Exit criteria passed" when done.
EOF

PROMPT="Continue implementing the plan.

Plan file: $PLAN_PATH
Iteration: $NEXT_ITERATION
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "Step (will pause after this todo)"; else echo "Auto"; fi)

Instructions:
1. Check your todo list
2. Find next pending/in_progress todo
3. Implement the change
4. Mark todo completed
$(if [[ "$STEP_MODE" == "true" ]]; then echo "5. After completing, wait for human to say 'continue' or 'stop'"; else echo "5. Continue to next todo"; fi)

When complete, say: \"Exit criteria passed - implementation complete\""

jq -n \
  --arg prompt "$PROMPT" \
  --arg msg "Implement loop iteration $NEXT_ITERATION | Plan: $PLAN_PATH" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }' 2>/dev/null || echo '{"decision":"block","reason":"Continue implementation"}'

exit 0
