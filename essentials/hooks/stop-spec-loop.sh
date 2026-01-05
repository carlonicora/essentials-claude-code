#!/bin/bash

# Spec Loop Stop Hook
# Prevents session exit when spec-loop is active

SPEC_STATE=".claude/spec-loop.local.md"

# Exit early if no active loop
if [[ ! -f "$SPEC_STATE" ]]; then
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
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$SPEC_STATE" 2>/dev/null || echo "")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "1")
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "0")
CHANGE_ID=$(echo "$FRONTMATTER" | grep '^change_id:' | sed 's/change_id: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
CHANGE_PATH=$(echo "$FRONTMATTER" | grep '^change_path:' | sed 's/change_path: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
STEP_MODE=$(echo "$FRONTMATTER" | grep '^step_mode:' | sed 's/step_mode: *//' || echo "true")

# Validate numeric fields
[[ ! "$ITERATION" =~ ^[0-9]+$ ]] && ITERATION=1
[[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] && MAX_ITERATIONS=0

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Spec loop: Max iterations ($MAX_ITERATIONS) reached."
  rm -f "$SPEC_STATE"
  exit 0
fi

# Check change path exists
if [[ -z "$CHANGE_PATH" ]] || [[ ! -d "$CHANGE_PATH" ]]; then
  echo "Spec loop: Change directory not found, ending loop" >&2
  rm -f "$SPEC_STATE"
  exit 0
fi

TASKS_FILE="$CHANGE_PATH/tasks.md"
if [[ ! -f "$TASKS_FILE" ]]; then
  echo "Spec loop: tasks.md not found, ending loop" >&2
  rm -f "$SPEC_STATE"
  exit 0
fi

# Check for completion signals
if check_completion_signals "all spec tasks complete|all tasks complete|spec loop complete|implementation complete"; then
  echo "Spec loop: Completion signal detected!"
  rm -f "$SPEC_STATE"
  exit 0
fi

# Check for stop signal
if check_completion_signals "^stop$|stopping spec|stop spec loop"; then
  echo "Spec loop: Stop signal detected. Ending loop."
  rm -f "$SPEC_STATE"
  exit 0
fi

# Count remaining tasks
# Note: grep -c exits with 1 when no matches but still outputs "0"
# Using || assignment outside $() to avoid "0\n0" concatenation bug
TOTAL_TASKS=$(grep -cE '^\s*- \[[ x]\]' "$TASKS_FILE" 2>/dev/null) || TOTAL_TASKS=0
COMPLETED_TASKS=$(grep -cE '^\s*- \[x\]' "$TASKS_FILE" 2>/dev/null) || COMPLETED_TASKS=0
REMAINING_TASKS=$((TOTAL_TASKS - COMPLETED_TASKS))

if [[ "$REMAINING_TASKS" -eq 0 ]] && [[ "$TOTAL_TASKS" -gt 0 ]]; then
  echo "Spec loop: All tasks complete! ($COMPLETED_TASKS/$TOTAL_TASKS)"
  echo "To archive: openspec archive $CHANGE_ID"
  rm -f "$SPEC_STATE"
  exit 0
fi

# Check for continue signal (step mode)
CONTINUE_DETECTED=false
if [[ "$STEP_MODE" == "true" ]]; then
  if check_completion_signals "^continue$|continue to next|proceed to next|next task"; then
    CONTINUE_DETECTED=true
  fi
fi

# STEP MODE: Pause for human decision
if [[ "$STEP_MODE" == "true" ]] && [[ "$CONTINUE_DETECTED" == "false" ]] && [[ $ITERATION -gt 1 ]]; then
  # Extract remaining uncompleted tasks from tasks.md
  REMAINING_TASKS_LIST=$(grep -E '^\s*- \[ \]' "$TASKS_FILE" 2>/dev/null | sed 's/^\s*- \[ \] /  - /' | head -10 || echo "  (none)")
  TASK_COUNT=$(echo "$REMAINING_TASKS_LIST" | grep -c '^ ' 2>/dev/null || echo "0")

  PAUSE_PROMPT="===============================================================
TASK COMPLETED - Iteration $ITERATION
===============================================================

Change: $CHANGE_ID
Progress: $COMPLETED_TASKS/$TOTAL_TASKS complete ($REMAINING_TASKS remaining)

Use AskUserQuestion to let the user choose:

1. Continue (Recommended) - proceed to next task in order
2. Stop - end the spec loop
3. Pick a specific task from the remaining list below
4. Feedback - free text for other actions

Remaining tasks:
$REMAINING_TASKS_LIST

==============================================================="

  SYSTEM_MSG="Spec loop paused | Iteration $ITERATION | $CHANGE_ID: $COMPLETED_TASKS/$TOTAL_TASKS

IMPORTANT: Use AskUserQuestion tool with options:
- Option 1: \"Continue\" (recommended) - next task in order
- Option 2: \"Stop\" - end the loop
- Options 3+: One per remaining task (show task description)
- \"Other\" is automatic for feedback

Remaining: $REMAINING_TASKS tasks in $CHANGE_PATH/tasks.md"

  jq -n \
    --arg prompt "$PAUSE_PROMPT" \
    --arg msg "$SYSTEM_MSG" \
    '{
      "decision": "block",
      "reason": $prompt,
      "systemMessage": $msg
    }' 2>/dev/null || echo '{"decision":"block","reason":"Task completed. Say continue or stop."}'

  exit 0
fi

# AUTO MODE or CONTINUE detected: Continue loop
NEXT_ITERATION=$((ITERATION + 1))

# Update state file
cat > "$SPEC_STATE" <<EOF
---
active: true
iteration: $NEXT_ITERATION
max_iterations: $MAX_ITERATIONS
change_id: "$CHANGE_ID"
change_path: "$CHANGE_PATH"
step_mode: $STEP_MODE
started_at: "$(echo "$FRONTMATTER" | grep '^started_at:' | sed 's/started_at: *//' | sed 's/^"\(.*\)"$/\1/' || date -u +%Y-%m-%dT%H:%M:%SZ)"
---

## Spec Loop State

Change: $CHANGE_ID
Path: $CHANGE_PATH
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "Step (pause after each task)"; else echo "Auto (continuous)"; fi)
Tasks: $COMPLETED_TASKS/$TOTAL_TASKS complete
Iteration: $NEXT_ITERATION

### Instructions

1. Check todo status
2. Find next uncompleted task
3. Implement following proposal/design
4. Mark todo completed
5. Update tasks.md: change \`- [ ]\` to \`- [x]\`
$(if [[ "$STEP_MODE" == "true" ]]; then echo "6. Wait for human to say 'continue' or 'stop'"; else echo "6. Auto-continue to next task"; fi)
7. Repeat until all tasks marked [x]

Say "All spec tasks complete" when done.
EOF

PROMPT="Continue implementing the OpenSpec change.

Change: $CHANGE_ID
Path: $CHANGE_PATH
Tasks: $COMPLETED_TASKS/$TOTAL_TASKS complete ($REMAINING_TASKS remaining)
Iteration: $NEXT_ITERATION
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "Step (will pause after this task)"; else echo "Auto"; fi)

Key files:
- $CHANGE_PATH/proposal.md
- $CHANGE_PATH/design.md
- $CHANGE_PATH/tasks.md

Instructions:
1. Check your todo list
2. Find next pending/in_progress todo
3. Implement the change
4. Mark todo completed
5. Edit tasks.md: change \`- [ ]\` to \`- [x]\`
$(if [[ "$STEP_MODE" == "true" ]]; then echo "6. After completing, wait for human to say 'continue' or 'stop'"; else echo "6. Continue to next task"; fi)

When all tasks marked [x], say: \"All spec tasks complete\""

jq -n \
  --arg prompt "$PROMPT" \
  --arg msg "Spec loop iteration $NEXT_ITERATION | $CHANGE_ID: $COMPLETED_TASKS/$TOTAL_TASKS tasks" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }' 2>/dev/null || echo '{"decision":"block","reason":"Continue spec implementation"}'

exit 0
