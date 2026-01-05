#!/bin/bash

# Spec Loop Setup Script
# Creates state file for OpenSpec change implementation loop

set -euo pipefail

# Parse arguments
CHANGE_ID=""
MAX_ITERATIONS=0
STEP_MODE=true  # Default to step mode for human control

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Spec Loop - Iterative OpenSpec change implementation

USAGE:
  /spec-loop <change-id> [OPTIONS]

ARGUMENTS:
  change-id    The OpenSpec change ID (folder name in openspec/changes/)

OPTIONS:
  --step                  Step mode (DEFAULT) - pause after each task for human control
  --auto                  Auto mode - continue without pausing
  --max-iterations <n>    Maximum iterations before auto-stop (default: unlimited)
  -h, --help              Show this help message

DESCRIPTION:
  Starts an implementation loop that:
  1. Reads the OpenSpec change (proposal.md, design.md, tasks.md)
  2. Creates todos from the tasks.md checklist
  3. Iteratively implements each task
  4. Updates tasks.md as each task completes
  5. Pauses for human decision (step mode) or auto-continues (auto mode)
  6. Loops until all tasks are marked [x]

  Step mode (default) pauses after each task, letting you:
  - Continue to the next task
  - Stop and start a fresh session
  - Review progress before continuing

  This prevents context compaction issues on large specs.

  The loop uses Claude's built-in TodoWrite tool for progress tracking.
  Progress is persisted in tasks.md for context recovery.

EXAMPLES:
  /spec-loop user-authentication
  /spec-loop billing-improvements --auto
  /spec-loop billing-improvements --max-iterations 20

STOPPING:
  - All tasks in tasks.md marked [x]
  - Max iterations reached (if set)
  - User says "stop" at pause prompt (step mode)
  - User runs /cancel-spec-loop

STEP MODE CONTROLS:
  After each task completes:
  - Say "continue" to proceed to next task
  - Say "stop" to end the loop
  - Start a fresh session anytime

MONITORING:
  # View current iteration:
  grep '^iteration:' .claude/spec-loop.local.md

  # View tasks status:
  grep -E '^\s*- \[[ x]\]' openspec/changes/<id>/tasks.md
HELP_EOF
      exit 0
      ;;
    --step)
      STEP_MODE=true
      shift
      ;;
    --auto)
      STEP_MODE=false
      shift
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --max-iterations requires a number argument" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations must be a positive integer, got: $2" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    *)
      # First positional argument is change ID
      if [[ -z "$CHANGE_ID" ]]; then
        CHANGE_ID="$1"
      else
        echo "Error: Unexpected argument: $1" >&2
        echo "Usage: /spec-loop <change-id> [--max-iterations N]" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate change ID
if [[ -z "$CHANGE_ID" ]]; then
  echo "Error: No change ID provided" >&2
  echo "" >&2
  echo "Usage: /spec-loop <change-id> [--max-iterations N]" >&2
  echo "" >&2
  echo "Available changes:" >&2
  if [[ -d "openspec/changes" ]]; then
    ls -1 openspec/changes/ 2>/dev/null || echo "  (no changes found)"
  else
    echo "  (openspec/changes directory does not exist)"
    echo "" >&2
    echo "Initialize OpenSpec first: openspec init" >&2
  fi
  exit 1
fi

# Determine change path
CHANGE_PATH="openspec/changes/$CHANGE_ID"

# Check if change exists
if [[ ! -d "$CHANGE_PATH" ]]; then
  echo "Error: Change not found: $CHANGE_PATH" >&2
  echo "" >&2
  echo "Available changes:" >&2
  if [[ -d "openspec/changes" ]]; then
    ls -1 openspec/changes/ 2>/dev/null || echo "  (no changes found)"
  else
    echo "  (openspec/changes directory does not exist)"
  fi
  exit 1
fi

# Check for required files
if [[ ! -f "$CHANGE_PATH/proposal.md" ]]; then
  echo "Error: proposal.md not found in $CHANGE_PATH" >&2
  exit 1
fi

if [[ ! -f "$CHANGE_PATH/tasks.md" ]]; then
  echo "Error: tasks.md not found in $CHANGE_PATH" >&2
  echo "" >&2
  echo "The change needs a tasks.md file with a task checklist." >&2
  exit 1
fi

# Count tasks
# Note: grep -c exits with 1 when no matches but still outputs "0"
# Using || assignment outside $() to avoid "0\n0" concatenation bug
TOTAL_TASKS=$(grep -cE '^\s*- \[[ x]\]' "$CHANGE_PATH/tasks.md" 2>/dev/null) || TOTAL_TASKS=0
COMPLETED_TASKS=$(grep -cE '^\s*- \[x\]' "$CHANGE_PATH/tasks.md" 2>/dev/null) || COMPLETED_TASKS=0
REMAINING_TASKS=$((TOTAL_TASKS - COMPLETED_TASKS))

if [[ "$TOTAL_TASKS" -eq 0 ]]; then
  echo "Warning: No tasks found in $CHANGE_PATH/tasks.md" >&2
  echo "Expected format: - [ ] Task description" >&2
fi

if [[ "$REMAINING_TASKS" -eq 0 ]] && [[ "$TOTAL_TASKS" -gt 0 ]]; then
  echo "All tasks already complete in $CHANGE_PATH/tasks.md" >&2
  echo "" >&2
  echo "To archive this change: openspec archive $CHANGE_ID" >&2
  exit 0
fi

# Create state file
mkdir -p .claude

cat > .claude/spec-loop.local.md <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
change_id: "$CHANGE_ID"
change_path: "$CHANGE_PATH"
step_mode: $STEP_MODE
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
todos_created: false
---

## Spec Loop State

Change: $CHANGE_ID
Path: $CHANGE_PATH
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "Step (pause after each task)"; else echo "Auto (continuous)"; fi)
Started: $(date)

### Progress
- Iteration: 1
- Total Tasks: $TOTAL_TASKS
- Completed: $COMPLETED_TASKS
- Remaining: $REMAINING_TASKS
- Status: Starting

### Instructions

On each iteration:
1. If todos not created: Read tasks.md, create todos with TodoWrite
2. Find next uncompleted task, mark as in_progress
3. Implement the change following the proposal/design
4. Mark todo as completed when done
5. Update tasks.md to mark the task [x]
$(if [[ "$STEP_MODE" == "true" ]]; then echo "6. Wait for human to say 'continue' or 'stop'"; else echo "6. Auto-continue to next task"; fi)
7. Repeat until all tasks are marked [x]

The loop will $(if [[ "$STEP_MODE" == "true" ]]; then echo "pause after each task for your decision"; else echo "continue automatically"; fi).
EOF

# Output setup message
cat <<EOF
SPEC_LOOP_ACTIVE=true
CHANGE_ID=$CHANGE_ID
CHANGE_PATH=$CHANGE_PATH
MAX_ITERATIONS=$MAX_ITERATIONS
STEP_MODE=$STEP_MODE
ITERATION=1
TOTAL_TASKS=$TOTAL_TASKS
COMPLETED_TASKS=$COMPLETED_TASKS
REMAINING_TASKS=$REMAINING_TASKS

Spec loop activated.

Change: $CHANGE_ID
Path: $CHANGE_PATH
Tasks: $COMPLETED_TASKS/$TOTAL_TASKS complete ($REMAINING_TASKS remaining)
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "STEP (pause after each task)"; else echo "AUTO (continuous)"; fi)
Max Iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)

$(if [[ "$STEP_MODE" == "true" ]]; then
cat <<'STEP_MSG'
Step mode enabled - pauses after each task for your decision.
After each task completes:
  - Say "continue" to proceed to next task
  - Say "stop" to end the loop
  - Start a fresh session anytime
STEP_MSG
else
echo "The stop hook will keep you implementing until all tasks are marked [x]."
fi)
To cancel: /cancel-spec-loop
EOF

# Output the change path for the command to read
echo ""
echo "CHANGE_TO_IMPLEMENT=$CHANGE_PATH"
