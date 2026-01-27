---
description: "Execute beads iteratively until all tasks complete"
argument-hint: "[--step|--auto] [--label <label>] [--max-iterations N]"
allowed-tools: ["Read", "TodoWrite", "Bash", "Edit", "AskUserQuestion"]
hide-from-slash-command-tool: "true"
---

# Beads Loop Command

Execute beads iteratively until all ready tasks are complete. Uses Claude Code's native task tracking for progress visualization.

**IMPORTANT**: This command runs in step mode by default, pausing after each bead for human control. Use `--auto` to skip pauses.

## Why Beads Loop?

Beads loop provides iterative execution of self-contained tasks with built-in progress tracking and human oversight:

- **Step Mode Control** - Pauses after each bead to prevent context compaction and quality degradation on large task sets
- **Priority-Based Execution** - Follows `bd ready` priority order to handle dependencies correctly
- **Context Recovery** - Easy commands to recover state if you lose track during execution
- **Native Progress** - Press `ctrl+t` to see visual progress at any time

## Workflow Integration

This command is the final stage after:
1. `/plan-creator`, `/bug-plan-creator`, or `/code-quality-plan-creator` - Create architectural plan
2. `/proposal-creator` - Create OpenSpec proposal
3. Validation - Review and approve spec
4. `/beads-creator` - Convert spec to self-contained beads
5. **`/beads-loop`** - Execute beads iteratively (sequential)

For parallel execution, use `/beads-swarm` instead.

## Arguments

The command accepts the following flags:
- `--step`: Run in step mode (default) - pauses after each bead for confirmation
- `--auto`: Run in auto mode - skips pauses but still follows priority order
- `--label <label>`: Filter beads by label (e.g., `--label openspec:my-change`)
- `--max-iterations N`: Maximum number of beads to execute before stopping

## Instructions

You are now in **beads loop mode**. Execute all ready beads until complete.

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for flags:
- Check for `--step` or `--auto` (default: step)
- Check for `--label <value>`
- Check for `--max-iterations <N>`

### Step 2: Find Ready Work

```bash
bd ready
```

Or with label filter:
```bash
bd ready -l "<label>"
```

Shows tasks with no blockers, sorted by priority.

### Step 3: Pick a Task

Select the highest priority ready task. Note its ID.

### Step 4: Read Task Details

```bash
bd show <id>
```

The task description should be self-contained with requirements, acceptance criteria, and files to modify.

### Step 5: Start Working

```bash
bd update <id> --status in_progress
```

### Step 6: Implement the Task

Follow the task description:
1. Read the files mentioned
2. Make the required changes
3. Run any tests/verification in acceptance criteria

### Step 7: Complete the Task

```bash
bd close <id> --reason "Done: <brief summary>"
```

### Step 8: Update OpenSpec (if applicable)

**IMPORTANT**: If working on an OpenSpec change (label starts with `openspec:`):

Edit `openspec/changes/<name>/tasks.md` to mark that task complete:

```markdown
# Before
- [ ] Task description here

# After
- [x] Task description here
```

### Step 9: Repeat or Pause

**In step mode:** Use AskUserQuestion to pause for human control.

**In auto mode:** Continue to next ready bead immediately.

### Completion

When no ready tasks remain, say: **"All beads complete"**

## Step Mode (Default)

Step mode pauses after each bead for human control. This prevents context compaction and quality degradation on large task sets.

**After completing each bead, you MUST:**

1. Run `bd ready` to get updated task list with priorities
2. Show execution order in the pause message
3. Use AskUserQuestion to let user confirm or pick

**Before pausing, output execution status:**
```
===============================================================
BEAD COMPLETED: <bead-id>
===============================================================

Progress: N/M beads complete

EXECUTION ORDER (remaining):
  Next → <bead-id>: <title> (P0)
  Then → <bead-id>: <title> (P0)
  Then → <bead-id>: <title> (P1, blocked until P0 done)
===============================================================
```

**Then use AskUserQuestion:**

The options MUST include:
1. **Continue (Recommended)** - proceed to next in execution order
2. **Stop** - end the beads loop
3. **One option per ready bead** - let user pick a specific bead by ID
4. *(Other is automatic for feedback)*

Example with 2 ready beads:
```
Use AskUserQuestion with:
- question: "Bead complete. Next: my-bead-id-1 (Create user auth). Continue?"
- header: "Next step"
- options:
  - label: "Continue (Recommended)"
    description: "Proceed to my-bead-id-1: Create user authentication module"
  - label: "Stop"
    description: "End the beads loop here"
  - label: "my-bead-id-2"
    description: "Skip to: Add validation middleware"
```

Based on the response:
- **Continue**: Proceed to next in execution order (respects `bd ready` priority)
- **Stop**: End the loop and report progress
- **Specific bead ID**: Work on that bead next (skip priority order)
- **Other/feedback**: Handle user's custom input

**Auto mode** (`--auto` flag): Skips pauses but still follows `bd ready` priority order.

## Context Recovery

If you lose track:

```bash
bd ready                        # See what's next
bd list --status in_progress    # Find current work
bd show <id>                    # Full task details
```

## Progress Visualization

Press `ctrl+t` at any time to see visual progress of all tasks.

## Stealth Mode

For brownfield development, beads should run in stealth mode to avoid committing tracking files:

```bash
bd init --stealth    # First time only - adds .beads/ to .gitignore
```

Stealth mode keeps all beads functionality but doesn't pollute the repo.

## Git Policy

**NEVER push to git.** Do not run `git push`, `bd sync`, or any command that pushes to remote. The user will push manually when ready.

## Error Handling

| Scenario | Action |
|----------|--------|
| No ready tasks found | Check if all tasks are complete or blocked; run `bd list` to see status |
| Lost track of current work | Run `bd list --status in_progress` to find in-progress tasks |
| Task has unmet dependencies | Task won't appear in `bd ready`; complete blocking tasks first |
| Max iterations reached | Loop stops automatically; resume with `/beads-loop` to continue |
| Context compaction needed | Use step mode to pause after each bead; reduces context buildup |

## Stopping

- Say "All beads complete" when done
- Run `/cancel-loop` to stop early
- Max iterations reached (if set)
- In step mode: select "Stop" at the pause prompt

## Example Usage

```bash
# Run in default step mode (pauses after each bead)
/beads-loop

# Run in auto mode (no pauses)
/beads-loop --auto

# Run only beads with a specific label
/beads-loop --label openspec:add-auth

# Limit to 5 iterations
/beads-loop --max-iterations 5

# Combine flags
/beads-loop --auto --label openspec:refactor --max-iterations 10
```
