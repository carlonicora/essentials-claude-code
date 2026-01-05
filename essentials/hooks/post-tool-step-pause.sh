#!/bin/bash

# Post-Tool Step Pause Hook
# Enforces step mode pause after task completion in any loop
# Triggers after: Bash (bd close), TodoWrite (marking complete), Edit (tasks.md)

# Read hook input from stdin
HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Detect which loop is active and get its state
BEADS_STATE=".claude/beads-loop.local.md"
IMPLEMENT_STATE=".claude/implement-loop.local.md"
SPEC_STATE=".claude/spec-loop.local.md"

ACTIVE_LOOP=""
STATE_FILE=""

if [[ -f "$BEADS_STATE" ]]; then
  ACTIVE_LOOP="beads"
  STATE_FILE="$BEADS_STATE"
elif [[ -f "$IMPLEMENT_STATE" ]]; then
  ACTIVE_LOOP="implement"
  STATE_FILE="$IMPLEMENT_STATE"
elif [[ -f "$SPEC_STATE" ]]; then
  ACTIVE_LOOP="spec"
  STATE_FILE="$SPEC_STATE"
fi

# Exit if no active loop
if [[ -z "$ACTIVE_LOOP" ]]; then
  exit 0
fi

# Parse state file frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || echo "")
STEP_MODE=$(echo "$FRONTMATTER" | grep '^step_mode:' | sed 's/step_mode: *//' || echo "true")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "1")
LAST_PAUSE=$(echo "$FRONTMATTER" | grep '^last_pause_tool:' | sed 's/last_pause_tool: *//' || echo "")

# Exit if not in step mode
if [[ "$STEP_MODE" != "true" ]]; then
  exit 0
fi

# Detect task completion based on tool and loop type
TASK_COMPLETED=false
COMPLETION_TYPE=""

case "$TOOL_NAME" in
  Bash)
    TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

    # beads-loop: bd close
    if [[ "$ACTIVE_LOOP" == "beads" ]]; then
      if echo "$TOOL_INPUT" | grep -qE 'bd close'; then
        TASK_COMPLETED=true
        COMPLETION_TYPE="bead_closed"
      fi
    fi

    # Any loop: verification script (chained commands with test/lint/typecheck)
    if echo "$TOOL_INPUT" | grep -qE '(npm (run )?test|pytest|go test|cargo test).*(&&|;).*(lint|typecheck|tsc|eslint|ruff)'; then
      TASK_COMPLETED=true
      COMPLETION_TYPE="verification_ran"
    fi
    ;;

  TodoWrite)
    # implement-loop: Check if any todo was just marked completed
    if [[ "$ACTIVE_LOOP" == "implement" ]]; then
      TODOS=$(echo "$HOOK_INPUT" | jq -r '.tool_input.todos // []' 2>/dev/null)
      COMPLETED_COUNT=$(echo "$TODOS" | jq '[.[] | select(.status == "completed")] | length' 2>/dev/null || echo "0")

      if [[ "$COMPLETED_COUNT" -gt 0 ]]; then
        # Check if this is a new completion (not just reading existing todos)
        # We do this by checking if last_pause_tool was TodoWrite with same count
        TASK_COMPLETED=true
        COMPLETION_TYPE="todo_completed"
      fi
    fi
    ;;

  Edit)
    # spec-loop: Check if tasks.md was edited to mark task complete
    if [[ "$ACTIVE_LOOP" == "spec" ]]; then
      FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
      NEW_STRING=$(echo "$HOOK_INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null)

      if echo "$FILE_PATH" | grep -qE 'tasks\.md$'; then
        if echo "$NEW_STRING" | grep -qE '\[x\]|\[X\]'; then
          TASK_COMPLETED=true
          COMPLETION_TYPE="task_marked_complete"
        fi
      fi
    fi
    ;;
esac

# Exit if no task completion detected
if [[ "$TASK_COMPLETED" != "true" ]]; then
  exit 0
fi

# Prevent double-pause: Check if we just paused for the same completion
PAUSE_KEY="${TOOL_NAME}_${COMPLETION_TYPE}_${ITERATION}"
if [[ "$LAST_PAUSE" == "$PAUSE_KEY" ]]; then
  exit 0
fi

# Update state file with pause marker to prevent double-pause
sed -i.bak "s/^last_pause_tool:.*/last_pause_tool: $PAUSE_KEY/" "$STATE_FILE" 2>/dev/null || true
if ! grep -q '^last_pause_tool:' "$STATE_FILE" 2>/dev/null; then
  # Add the field if it doesn't exist (after the frontmatter opener)
  sed -i.bak "/^---$/a\\
last_pause_tool: $PAUSE_KEY" "$STATE_FILE" 2>/dev/null || true
fi
rm -f "${STATE_FILE}.bak" 2>/dev/null

# Get context based on loop type
case "$ACTIVE_LOOP" in
  beads)
    LABEL_FILTER=$(echo "$FRONTMATTER" | grep '^label_filter:' | sed 's/label_filter: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
    if [[ -n "$LABEL_FILTER" ]]; then
      READY_BEADS_JSON=$(bd ready -l "$LABEL_FILTER" --json 2>/dev/null || echo "[]")
    else
      READY_BEADS_JSON=$(bd ready --json 2>/dev/null || echo "[]")
    fi
    READY_COUNT=$(echo "$READY_BEADS_JSON" | jq 'length' 2>/dev/null || echo "0")
    READY_BEADS_LIST=$(echo "$READY_BEADS_JSON" | jq -r '.[] | "  - \(.id): \(.title // .description // "No title")[p\(.priority // 0)]"' 2>/dev/null || echo "  (none)")
    READY_IDS=$(echo "$READY_BEADS_JSON" | jq -r '[.[].id] | join(", ")' 2>/dev/null || echo "none")
    CONTEXT_MSG="Ready beads: $READY_COUNT"
    LOOP_NAME="Bead"
    CANCEL_CMD="/cancel-beads"
    USE_ASK_QUESTION=true
    ;;
  implement)
    CONTEXT_MSG="Check todos for remaining tasks"
    LOOP_NAME="Todo"
    CANCEL_CMD="/cancel-implement"
    USE_ASK_QUESTION=true
    PLAN_PATH=$(echo "$FRONTMATTER" | grep '^plan_path:' | sed 's/plan_path: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
    ;;
  spec)
    CHANGE_PATH=$(echo "$FRONTMATTER" | grep '^change_path:' | sed 's/change_path: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
    TASKS_FILE="$CHANGE_PATH/tasks.md"
    REMAINING_TASKS_LIST=$(grep -E '^\s*- \[ \]' "$TASKS_FILE" 2>/dev/null | sed 's/^\s*- \[ \] /  - /' | head -10 || echo "  (none)")
    REMAINING_COUNT=$(grep -cE '^\s*- \[ \]' "$TASKS_FILE" 2>/dev/null) || REMAINING_COUNT=0
    CONTEXT_MSG="Remaining tasks: $REMAINING_COUNT"
    LOOP_NAME="Task"
    CANCEL_CMD="/cancel-spec-loop"
    USE_ASK_QUESTION=true
    ;;
esac

# Output pause prompt based on loop type
if [[ "$USE_ASK_QUESTION" == "true" ]]; then
  case "$ACTIVE_LOOP" in
    beads)
      PAUSE_MSG="
═══════════════════════════════════════════════════════════════
  ${LOOP_NAME^^} COMPLETED - Step Mode Pause
═══════════════════════════════════════════════════════════════

$CONTEXT_MSG
Iteration: $ITERATION

Use AskUserQuestion to let the user choose:

1. Continue (Recommended) - proceed to next highest priority bead
2. Stop - end the beads loop
3. Pick a specific bead from the ready list below
4. Feedback - free text for other actions

Ready beads:
$READY_BEADS_LIST

═══════════════════════════════════════════════════════════════"

      SYSTEM_MSG="Step pause | Iteration $ITERATION | Ready: $READY_COUNT

IMPORTANT: Use AskUserQuestion tool with options:
- Option 1: \"Continue\" (recommended)
- Option 2: \"Stop\"
- Options 3+: One per ready bead (id: title)
- \"Other\" is automatic for feedback

Ready IDs: $READY_IDS"
      ;;

    spec)
      PAUSE_MSG="
═══════════════════════════════════════════════════════════════
  ${LOOP_NAME^^} COMPLETED - Step Mode Pause
═══════════════════════════════════════════════════════════════

$CONTEXT_MSG
Iteration: $ITERATION

Use AskUserQuestion to let the user choose:

1. Continue (Recommended) - proceed to next task in order
2. Stop - end the spec loop
3. Pick a specific task from the remaining list below
4. Feedback - free text for other actions

Remaining tasks:
$REMAINING_TASKS_LIST

═══════════════════════════════════════════════════════════════"

      SYSTEM_MSG="Step pause | Iteration $ITERATION | Remaining: $REMAINING_COUNT

IMPORTANT: Use AskUserQuestion tool with options:
- Option 1: \"Continue\" (recommended) - next task in order
- Option 2: \"Stop\" - end the loop
- Options 3+: One per remaining task (show task description)
- \"Other\" is automatic for feedback"
      ;;

    implement)
      PAUSE_MSG="
═══════════════════════════════════════════════════════════════
  ${LOOP_NAME^^} COMPLETED - Step Mode Pause
═══════════════════════════════════════════════════════════════

$CONTEXT_MSG
Iteration: $ITERATION

Use AskUserQuestion to let the user choose:

1. Continue (Recommended) - proceed to next todo
2. Stop - end the implement loop
3. Feedback - free text for other actions

═══════════════════════════════════════════════════════════════"

      SYSTEM_MSG="Step pause | Iteration $ITERATION | Plan: $(basename "$PLAN_PATH")

IMPORTANT: Use AskUserQuestion tool with options:
- Option 1: \"Continue\" (recommended) - next pending todo
- Option 2: \"Stop\" - end the loop
- \"Other\" is automatic for feedback"
      ;;
  esac

  jq -n \
    --arg reason "$PAUSE_MSG" \
    --arg msg "$SYSTEM_MSG" \
    '{
      "decision": "block",
      "reason": $reason,
      "systemMessage": $msg
    }' 2>/dev/null || echo '{"decision":"block","reason":"Step mode pause. Say continue or stop."}'
else
  PAUSE_MSG="
═══════════════════════════════════════════════════════════════
  ${LOOP_NAME^^} COMPLETED - Step Mode Pause
═══════════════════════════════════════════════════════════════

$CONTEXT_MSG
Iteration: $ITERATION

What would you like to do?
  → Say \"continue\" to proceed to next ${LOOP_NAME,,}
  → Say \"stop\" to end the loop
  → Run \"$CANCEL_CMD\" to cancel
  → Or start a fresh session (progress is saved)

═══════════════════════════════════════════════════════════════"

  jq -n \
    --arg reason "$PAUSE_MSG" \
    '{
      "decision": "block",
      "reason": $reason
    }' 2>/dev/null || echo '{"decision":"block","reason":"Step mode pause. Say continue or stop."}'
fi

exit 0
