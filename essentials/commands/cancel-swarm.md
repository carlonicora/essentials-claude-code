---
description: "Stop all active swarm workers"
allowed-tools: ["Bash", "Task", "TaskOutput"]
argument-hint: ""
---

# Cancel Swarm

Stop all active swarm workers across all swarm command types.

**Works with:** `/beads-swarm` (and future swarm commands)

## Instructions

### Step 1: Check Beads Status

```bash
bd list --status in_progress
```

This shows beads currently being worked on by swarm workers.

### Step 2: Report Status

**Important:** Swarm workers are independent background agents. Work already finished before cancellation is preserved.

Report current state:

```
===============================================================
SWARM CANCELLED
===============================================================

Workers Interrupted: N (may still be completing)

In-Progress Beads: M
  - <id>: <title>
  ...

Completed Beads: X
Pending Beads: Y

Note: Workers may complete their current task before stopping.
Check status in a moment with: bd list

===============================================================
```

### Step 3: Recovery Instructions

Provide recovery commands:

```
To check final status:
  bd list                         # See all beads
  bd ready                        # See what's ready next

To resume:
  /beads-loop [--label <label>]   # Sequential
  /beads-swarm [--label <label>]  # Parallel
```

## Task Preservation

- **Completed tasks**: Remain closed
- **In-progress tasks**: May complete (worker finishes) or remain in_progress
- **Pending tasks**: Remain pending

Swarm workers run independently. A worker that's mid-task when you cancel may:
1. Complete successfully (bead gets closed)
2. Get interrupted (bead remains in_progress)

Check `bd list` after a moment to see final state.

## Example Output

```
===============================================================
SWARM CANCELLED
===============================================================

Workers Interrupted: 3 (may still be completing)

In-Progress Beads: 3
  - task-004: Add login endpoint
  - task-005: Add logout endpoint
  - task-006: Add session management

Completed Beads: 3
Pending Beads: 2

Note: Workers may complete their current task before stopping.
Check status in a moment with: bd list

To resume:
  /beads-swarm

===============================================================
```

## Difference from Cancel Loop

| Aspect | `/cancel-loop` | `/cancel-swarm` |
|--------|----------------|-----------------|
| Stops | Single foreground agent | Multiple background workers |
| Immediate | Yes | Workers may finish current task |
| State | Deterministic | Check after moment |
