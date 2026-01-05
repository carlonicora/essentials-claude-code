#!/bin/bash

# Beads Loop Stop Hook
# Prevents session exit when beads-loop is active

BEADS_STATE=".claude/beads-loop.local.md"

# Exit early if no active loop
if [[ ! -f "$BEADS_STATE" ]]; then
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
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$BEADS_STATE" 2>/dev/null || echo "")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "1")
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "0")
LABEL_FILTER=$(echo "$FRONTMATTER" | grep '^label_filter:' | sed 's/label_filter: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
STEP_MODE=$(echo "$FRONTMATTER" | grep '^step_mode:' | sed 's/step_mode: *//' || echo "true")

# Validate numeric fields
[[ ! "$ITERATION" =~ ^[0-9]+$ ]] && ITERATION=1
[[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] && MAX_ITERATIONS=0

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Beads loop: Max iterations ($MAX_ITERATIONS) reached."
  rm -f "$BEADS_STATE"
  exit 0
fi

# Check for completion signals
if check_completion_signals "all beads complete|no ready tasks|beads loop complete|all tasks complete"; then
  echo "Beads loop: Completion signal detected!"
  rm -f "$BEADS_STATE"
  exit 0
fi

# Check for stop signal
if check_completion_signals "^stop$|stopping beads|stop beads loop"; then
  echo "Beads loop: Stop signal detected. Ending loop."
  rm -f "$BEADS_STATE"
  exit 0
fi

# Check if there are ready tasks
if [[ -n "$LABEL_FILTER" ]]; then
  READY_COUNT=$(bd ready -l "$LABEL_FILTER" --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
else
  READY_COUNT=$(bd ready --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
fi

if [[ "$READY_COUNT" == "0" ]]; then
  echo "Beads loop: No ready tasks remaining. All beads complete!"

  # Remind about OpenSpec archive if applicable
  if [[ "$LABEL_FILTER" == openspec:* ]]; then
    CHANGE_NAME="${LABEL_FILTER#openspec:}"
    echo "To archive: openspec archive $CHANGE_NAME"
  fi

  rm -f "$BEADS_STATE"
  exit 0
fi

# Get last closed task for step mode display
LAST_CLOSED_TASK=""
LAST_CLOSE_REASON=""
if [[ "$STEP_MODE" == "true" ]]; then
  output=$(get_last_output)
  if [[ -n "$output" ]]; then
    # Try to extract bd close command from output
    close_match=$(echo "$output" | grep -oE 'bd close [a-zA-Z0-9_-]+' | tail -1 || echo "")
    if [[ -n "$close_match" ]]; then
      LAST_CLOSED_TASK=$(echo "$close_match" | sed 's/bd close //')
    fi
    # Try to extract close reason
    reason_match=$(echo "$output" | grep -oE '\-\-reason "[^"]*"' | tail -1 || echo "")
    if [[ -n "$reason_match" ]]; then
      LAST_CLOSE_REASON=$(echo "$reason_match" | sed 's/--reason "//' | sed 's/"$//')
    fi
  fi
fi

# Check for continue signal (step mode)
CONTINUE_DETECTED=false
if [[ "$STEP_MODE" == "true" ]]; then
  if check_completion_signals "^continue$|continue to next|proceed to next|next bead"; then
    CONTINUE_DETECTED=true
  fi
fi

# STEP MODE: Pause for human decision
if [[ "$STEP_MODE" == "true" ]] && [[ "$CONTINUE_DETECTED" == "false" ]] && [[ $ITERATION -gt 1 ]]; then
  LABEL_MSG=""
  if [[ -n "$LABEL_FILTER" ]]; then
    LABEL_MSG=" (label: $LABEL_FILTER)"
  fi

  # Get list of ready beads for selection
  if [[ -n "$LABEL_FILTER" ]]; then
    READY_BEADS_JSON=$(bd ready -l "$LABEL_FILTER" --json 2>/dev/null || echo "[]")
  else
    READY_BEADS_JSON=$(bd ready --json 2>/dev/null || echo "[]")
  fi

  # Format ready beads as a simple list (id: title)
  READY_BEADS_LIST=$(echo "$READY_BEADS_JSON" | jq -r '.[] | "  - \(.id): \(.title // .description // "No title")[p\(.priority // 0)]"' 2>/dev/null || echo "  (none)")

  PAUSE_PROMPT="===============================================================
BEAD COMPLETED${LAST_CLOSED_TASK:+: $LAST_CLOSED_TASK}
===============================================================
${LAST_CLOSE_REASON:+
Summary: $LAST_CLOSE_REASON}
Remaining: $READY_COUNT ready tasks$LABEL_MSG

Use AskUserQuestion to let the user choose:

1. Continue (Recommended) - proceed to next highest priority bead
2. Stop - end the beads loop
3. Pick a specific bead from the ready list below
4. Feedback - free text for other actions (e.g., work on non-ready bead)

Ready beads:
$READY_BEADS_LIST

==============================================================="

  SYSTEM_MSG="Beads loop paused | Iteration $ITERATION | Ready: $READY_COUNT$LABEL_MSG

IMPORTANT: Use AskUserQuestion tool with these options:
- Option 1: \"Continue\" (recommended) - work on next priority bead
- Option 2: \"Stop\" - end the loop
- Options 3+: One option per ready bead (show id and title)
- Last option: \"Other\" is automatic for feedback

Ready bead IDs: $(echo "$READY_BEADS_JSON" | jq -r '[.[].id] | join(", ")' 2>/dev/null || echo "none")"

  jq -n \
    --arg prompt "$PAUSE_PROMPT" \
    --arg msg "$SYSTEM_MSG" \
    '{
      "decision": "block",
      "reason": $prompt,
      "systemMessage": $msg
    }' 2>/dev/null || echo '{"decision":"block","reason":"Bead completed. Say continue or stop."}'

  exit 0
fi

# AUTO MODE or CONTINUE detected: Continue loop
NEXT_ITERATION=$((ITERATION + 1))

# Get in-progress task if any
if [[ -n "$LABEL_FILTER" ]]; then
  CURRENT_TASK=$(bd list -l "$LABEL_FILTER" --status in_progress --json 2>/dev/null | jq -r '.[0].id // ""' 2>/dev/null || echo "")
else
  CURRENT_TASK=$(bd list --status in_progress --json 2>/dev/null | jq -r '.[0].id // ""' 2>/dev/null || echo "")
fi

# Update state file
cat > "$BEADS_STATE" <<EOF
---
active: true
iteration: $NEXT_ITERATION
max_iterations: $MAX_ITERATIONS
label_filter: "$LABEL_FILTER"
step_mode: $STEP_MODE
started_at: "$(echo "$FRONTMATTER" | grep '^started_at:' | sed 's/started_at: *//' | sed 's/^"\(.*\)"$/\1/' || date -u +%Y-%m-%dT%H:%M:%SZ)"
current_task: "$CURRENT_TASK"
---

## Beads Loop State

Label: ${LABEL_FILTER:-"(all)"}
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "Step (pause after each bead)"; else echo "Auto (continuous)"; fi)
Ready: $READY_COUNT
Current: ${CURRENT_TASK:-"(none)"}
Iteration: $NEXT_ITERATION

### Instructions

1. Run \`bd ready\` to find tasks
2. Pick highest priority task
3. Run \`bd show <id>\` for details
4. Run \`bd update <id> --status in_progress\`
5. Implement the task
6. Run \`bd close <id> --reason "Done: <summary>"\`
7. If OpenSpec: edit tasks.md to mark [x]
$(if [[ "$STEP_MODE" == "true" ]]; then echo "8. Wait for human to say 'continue' or 'stop'"; else echo "8. Auto-continue to next task"; fi)
9. Repeat until no ready tasks

Say "All beads complete" when done.
EOF

LABEL_MSG=""
if [[ -n "$LABEL_FILTER" ]]; then
  LABEL_MSG=" (label: $LABEL_FILTER)"
fi

PROMPT="Continue executing beads.

Ready tasks: $READY_COUNT$LABEL_MSG
Current task: ${CURRENT_TASK:-"(none)"}
Iteration: $NEXT_ITERATION
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "Step (will pause after this bead)"; else echo "Auto"; fi)

Instructions:
1. Run \`bd ready\` to see available tasks
2. Pick highest priority task
3. Run \`bd show <id>\` for full context
4. Run \`bd update <id> --status in_progress\`
5. Implement the task
6. Run \`bd close <id> --reason \"Done: <summary>\"\`
7. **If OpenSpec**: Edit tasks.md to mark that task \`[x]\`
$(if [[ "$STEP_MODE" == "true" ]]; then echo "8. After closing, wait for human to say 'continue' or 'stop'"; else echo "8. Continue to next task"; fi)

When no ready tasks remain, say: \"All beads complete\""

jq -n \
  --arg prompt "$PROMPT" \
  --arg msg "Beads loop iteration $NEXT_ITERATION | Ready: $READY_COUNT$LABEL_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }' 2>/dev/null || echo '{"decision":"block","reason":"Continue beads execution"}'

exit 0
