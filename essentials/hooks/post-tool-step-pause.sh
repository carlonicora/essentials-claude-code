#!/bin/bash

# Post-Tool Step Pause Hook for Beads Loop
# Triggers after: Bash (bd close) to pause for user confirmation

# Read hook input from stdin
HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Only proceed if this is a Bash tool call
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# Check if beads loop is active
BEADS_STATE=".claude/beads-loop.local.md"

if [[ ! -f "$BEADS_STATE" ]]; then
  exit 0
fi

# Parse state file frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$BEADS_STATE" 2>/dev/null || echo "")
STEP_MODE=$(echo "$FRONTMATTER" | grep '^step_mode:' | sed 's/step_mode: *//' || echo "true")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "1")
LAST_PAUSE=$(echo "$FRONTMATTER" | grep '^last_pause_tool:' | sed 's/last_pause_tool: *//' || echo "")

# Exit if not in step mode
if [[ "$STEP_MODE" != "true" ]]; then
  exit 0
fi

# Check if this is a bd close command
TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

if ! echo "$TOOL_INPUT" | grep -qE 'bd close'; then
  exit 0
fi

# Prevent double-pause
PAUSE_KEY="Bash_bead_closed_${ITERATION}"
if [[ "$LAST_PAUSE" == "$PAUSE_KEY" ]]; then
  exit 0
fi

# Update state file with pause marker
sed -i.bak "s/^last_pause_tool:.*/last_pause_tool: $PAUSE_KEY/" "$BEADS_STATE" 2>/dev/null || true
if ! grep -q '^last_pause_tool:' "$BEADS_STATE" 2>/dev/null; then
  sed -i.bak "/^---$/a\\
last_pause_tool: $PAUSE_KEY" "$BEADS_STATE" 2>/dev/null || true
fi
rm -f "${BEADS_STATE}.bak" 2>/dev/null

# Get ready beads for context
LABEL_FILTER=$(echo "$FRONTMATTER" | grep '^label_filter:' | sed 's/label_filter: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
if [[ -n "$LABEL_FILTER" ]]; then
  READY_BEADS_JSON=$(bd ready -l "$LABEL_FILTER" --json 2>/dev/null || echo "[]")
else
  READY_BEADS_JSON=$(bd ready --json 2>/dev/null || echo "[]")
fi
READY_COUNT=$(echo "$READY_BEADS_JSON" | jq 'length' 2>/dev/null || echo "0")
READY_BEADS_LIST=$(echo "$READY_BEADS_JSON" | jq -r '.[] | "  - \(.id): \(.title // .description // "No title")[p\(.priority // 0)]"' 2>/dev/null || echo "  (none)")
READY_IDS=$(echo "$READY_BEADS_JSON" | jq -r '[.[].id] | join(", ")' 2>/dev/null || echo "none")

# Output pause prompt
PAUSE_MSG="
═══════════════════════════════════════════════════════════════
  BEAD COMPLETED - Step Mode Pause
═══════════════════════════════════════════════════════════════

Ready beads: $READY_COUNT
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

jq -n \
  --arg reason "$PAUSE_MSG" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $reason,
    "systemMessage": $msg
  }' 2>/dev/null || echo '{"decision":"block","reason":"Step mode pause. Say continue or stop."}'

exit 0
