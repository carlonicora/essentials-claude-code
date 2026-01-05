#!/bin/bash

# Implement Loop Setup Script
# Creates state file for plan implementation loop

set -euo pipefail

# Parse arguments
PLAN_PATH=""
MAX_ITERATIONS=0
STEP_MODE=true  # Default to step mode for human control

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Implement Loop - Iterative plan implementation with todo tracking

USAGE:
  /implement-loop <plan_path> [OPTIONS]

ARGUMENTS:
  plan_path    Path to the plan file (e.g., .claude/plans/feature-abc123-plan.md)

OPTIONS:
  --step                  Step mode (DEFAULT) - pause after each todo for human control
  --auto                  Auto mode - continue without pausing
  --max-iterations <n>    Maximum iterations before auto-stop (default: unlimited)
  -h, --help              Show this help message

DESCRIPTION:
  Starts an implementation loop that:
  1. Reads the plan file and extracts implementation tasks
  2. Creates a todo list from the plan's file sections
  3. Iteratively implements each todo until all are complete
  4. Pauses for human decision (step mode) or auto-continues (auto mode)
  5. Uses the plan as reference on each iteration

  Step mode (default) pauses after each todo, letting you:
  - Continue to the next todo
  - Stop and start a fresh session
  - Review progress before continuing

  This prevents context compaction issues on large plans.

  The loop uses Claude's built-in TodoWrite tool for progress tracking.
  On context compaction, the plan file provides full context recovery.

EXAMPLES:
  /implement-loop .claude/plans/oauth2-auth-3k7f2-plan.md
  /implement-loop .claude/plans/fix-login-bug-9f2a1-plan.md --auto
  /implement-loop .claude/plans/fix-login-bug-9f2a1-plan.md --max-iterations 20

STOPPING:
  - All todos marked as 'completed'
  - Max iterations reached (if set)
  - User says "stop" at pause prompt (step mode)
  - User runs /cancel-implement

STEP MODE CONTROLS:
  After each todo completes:
  - Say "continue" to proceed to next todo
  - Say "stop" to end the loop
  - Start a fresh session anytime

MONITORING:
  # View current iteration:
  grep '^iteration:' .claude/implement-loop.local.md

  # View full state:
  cat .claude/implement-loop.local.md
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
      # First positional argument is plan path
      if [[ -z "$PLAN_PATH" ]]; then
        PLAN_PATH="$1"
      else
        echo "Error: Unexpected argument: $1" >&2
        echo "Usage: /implement-loop <plan_path> [--max-iterations N]" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate plan path
if [[ -z "$PLAN_PATH" ]]; then
  echo "Error: No plan path provided" >&2
  echo "" >&2
  echo "Usage: /implement-loop <plan_path> [--max-iterations N]" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  /implement-loop .claude/plans/oauth2-auth-3k7f2-plan.md" >&2
  echo "  /implement-loop .claude/plans/fix-bug-a1b2c-plan.md --max-iterations 30" >&2
  exit 1
fi

# Check if plan file exists
if [[ ! -f "$PLAN_PATH" ]]; then
  echo "Error: Plan file not found: $PLAN_PATH" >&2
  echo "" >&2
  echo "Available plans in .claude/plans/:" >&2
  if [[ -d ".claude/plans" ]]; then
    ls -1 .claude/plans/*.md 2>/dev/null || echo "  (no plan files found)"
  else
    echo "  (plans directory does not exist)"
  fi
  exit 1
fi

# Create state file
mkdir -p .claude

cat > .claude/implement-loop.local.md <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
plan_path: "$PLAN_PATH"
step_mode: $STEP_MODE
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
todos_created: false
---

## Implementation Loop State

Plan: $PLAN_PATH
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "Step (pause after each todo)"; else echo "Auto (continuous)"; fi)
Started: $(date)

### Progress
- Iteration: 1
- Todos Created: No (pending first iteration)
- Status: Starting

### Instructions

On each iteration:
1. If todos not created: Read plan, create todos with TodoWrite
2. Find next pending todo, mark as in_progress
3. Implement the change following the plan
4. Mark todo as completed when done
$(if [[ "$STEP_MODE" == "true" ]]; then echo "5. Wait for human to say 'continue' or 'stop'"; else echo "5. Auto-continue to next todo"; fi)
6. Repeat until all todos are completed

The loop will $(if [[ "$STEP_MODE" == "true" ]]; then echo "pause after each todo for your decision"; else echo "continue automatically"; fi).
EOF

# Output setup message
cat <<EOF
IMPLEMENT_LOOP_ACTIVE=true
PLAN_PATH=$PLAN_PATH
MAX_ITERATIONS=$MAX_ITERATIONS
STEP_MODE=$STEP_MODE
ITERATION=1

Implement loop activated.

Plan File: $PLAN_PATH
Mode: $(if [[ "$STEP_MODE" == "true" ]]; then echo "STEP (pause after each todo)"; else echo "AUTO (continuous)"; fi)
Max Iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)

$(if [[ "$STEP_MODE" == "true" ]]; then
cat <<'STEP_MSG'
Step mode enabled - pauses after each todo for your decision.
After each todo completes:
  - Say "continue" to proceed to next todo
  - Say "stop" to end the loop
  - Start a fresh session anytime
STEP_MSG
else
echo "The stop hook will keep you implementing until all todos are complete."
fi)
To cancel: /cancel-implement
EOF

# Output the plan path for the command to read
echo ""
echo "PLAN_TO_IMPLEMENT=$PLAN_PATH"
