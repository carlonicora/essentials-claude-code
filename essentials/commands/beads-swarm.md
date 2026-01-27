---
description: "Execute beads using parallel worker agents"
argument-hint: "[--label <label>] [--workers N] [--model MODEL]"
allowed-tools: ["Task", "TaskOutput", "Bash", "Read"]
hide-from-slash-command-tool: "true"
---

# Beads Swarm Command

Execute beads tasks using parallel worker agents. All workers complete → done.

**Key difference from `/beads-loop`:** Swarm spawns multiple background agents that work simultaneously on independent beads, maximizing parallelism while respecting dependencies.

## Why Beads Swarm?

Use swarm when you have **independent beads** that can be worked on simultaneously:

| Aspect | Loop | Swarm |
|--------|------|-------|
| **Concurrency** | 1 task at a time | Up to N workers (default: 3) |
| **Visibility** | Live conversation context | Check via `ctrl+t` or `bd list` |
| **Best for** | Interdependent tasks, debugging | Independent parallel phases |
| **Control** | Step mode pauses | Workers run autonomously |

## Workflow Integration

This command is the final stage after:
1. `/plan-creator`, `/bug-plan-creator`, or `/code-quality-plan-creator` - Create architectural plan
2. `/proposal-creator` - Create OpenSpec proposal
3. Validation - Review and approve spec
4. `/beads-creator` - Convert spec to self-contained beads
5. **`/beads-swarm`** - Execute beads in parallel

For sequential execution with step mode, use `/beads-loop` instead.

## Arguments

- `--label <label>`: Filter beads by label (e.g., `--label openspec:my-change`)
- `--workers N`: Maximum concurrent workers (default: 3)
- `--model MODEL`: Worker model - `haiku`, `sonnet`, or `opus` (default: sonnet)

## Instructions

You are now in **beads swarm mode**. Coordinate parallel execution of beads.

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for flags:
- `--label <value>` (optional)
- `--workers <N>` (default: 3)
- `--model <MODEL>` (default: sonnet)

### Step 2: Retrieve Beads

```bash
bd list --json
```

Or with label filter:
```bash
bd list --json -l "<label>"
```

Parse the JSON to build a task graph with dependencies.

### Step 3: Build Dependency Graph

From the beads JSON, extract:
- `id`: Bead identifier
- `title` or `description`: Task name
- `depends_on`: Array of blocking bead IDs
- `status`: pending, in_progress, completed

**Important:** A bead is "ready" when:
- Status is `pending`
- All beads in `depends_on` have status `completed`

### Step 4: Spawn Workers

For each ready bead (up to `--workers` limit):

1. Mark bead as in_progress:
   ```bash
   bd update <id> --status in_progress
   ```

2. Launch worker agent using Task tool:
   ```
   Use Task tool with:
   - subagent_type: "general-purpose"
   - model: <selected model>
   - run_in_background: true
   - prompt: |
       Execute this bead task:

       Bead ID: <id>
       Title: <title>

       ## Task Description
       <full bead description from bd show>

       ## Instructions
       1. Read the files mentioned
       2. Make the required changes
       3. Run verification commands in exit criteria
       4. Report success or failure

       When complete, output: "BEAD COMPLETE: <id>"
       If blocked, output: "BEAD BLOCKED: <id> - <reason>"
   ```

3. Track worker assignment: `worker_id → bead_id`

### Step 5: Monitor Completion

Wait for workers to complete using TaskOutput:

1. Poll each running worker with `TaskOutput(task_id, block=false)`
2. When worker completes:
   - Parse output for "BEAD COMPLETE" or "BEAD BLOCKED"
   - If complete: `bd close <id> --reason "Done"`
   - If blocked: Report issue, mark as blocked
3. Update dependency graph (remove completed from blockedBy lists)
4. Identify newly unblocked beads
5. Spawn replacement workers for new ready beads

### Step 6: Continue Until Done

Repeat step 5 until:
- All beads are completed, OR
- No more work can be done (all remaining are blocked)

### Step 7: Report Results

```
===============================================================
BEADS SWARM COMPLETE
===============================================================

Workers Used: N (max: M)
Model: <model>

Results:
  Completed: X beads
  Blocked: Y beads (if any)

Execution Time: ~Z minutes

## Completed Beads
- <id>: <title>
- <id>: <title>
...

## Blocked Beads (if any)
- <id>: <title> - <reason>

===============================================================
```

If OpenSpec label detected, remind to update tasks.md:
```
Note: Don't forget to update openspec/changes/<name>/tasks.md
to mark completed tasks with [x].
```

## Progress Visualization

Press `ctrl+t` at any time to see:
- Number of active workers
- Tasks in progress
- Completed tasks
- Pending tasks

## Dependency Handling

The swarm respects bead dependencies:

```
Bead A (no deps) ──┐
                   ├──▶ Bead C (depends on A, B)
Bead B (no deps) ──┘

Timeline:
  t=0: Spawn workers for A, B (both ready)
  t=X: A completes
  t=Y: B completes
  t=Y: C becomes ready, spawn worker for C
  t=Z: C completes
  Done!
```

## Git Policy

**NEVER push to git.** Do not run `git push`, `bd sync`, or any command that pushes to remote. The user will push manually when ready.

## Error Handling

| Scenario | Action |
|----------|--------|
| Worker fails | Mark bead as blocked, report error, continue with others |
| All beads blocked | Stop swarm, report blocking issues |
| Circular dependency | Detect and report, cannot proceed |
| Max workers busy | Queue ready beads, spawn when workers free up |

## Stopping

- Say "All beads complete" when done
- Run `/cancel-swarm` to stop all workers
- Workers already running may complete before stopping

## Example Usage

```bash
# Default: 3 workers with sonnet
/beads-swarm

# Filter by label
/beads-swarm --label openspec:add-auth

# More workers for large parallel phases
/beads-swarm --workers 5

# Use faster model for simple beads
/beads-swarm --model haiku

# Combine flags
/beads-swarm --label openspec:refactor --workers 4 --model opus
```

## When to Use Loop vs Swarm

| Situation | Use |
|-----------|-----|
| Tasks depend heavily on each other | `/beads-loop` |
| Want to review each step | `/beads-loop --step` |
| Many independent tasks | `/beads-swarm` |
| Want maximum speed | `/beads-swarm` |
| Debugging issues | `/beads-loop` |
| Large refactoring with phases | `/beads-swarm` |
