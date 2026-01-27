---
description: "Gracefully stop any active loop"
allowed-tools: ["Bash"]
argument-hint: ""
---

# Cancel Loop

Gracefully stop any active loop while preserving progress.

**Works with:** `/beads-loop` (and future loop commands)

## Instructions

### Step 1: Check Beads Status

```bash
bd list --status in_progress
```

### Step 2: Report Status

Report current state:

```
===============================================================
LOOP CANCELLED
===============================================================

In-Progress Beads: N
  - <id>: <title>
  ...

Completed Beads: M
Pending Beads: P

Progress is preserved. Completed beads remain closed.
In-progress beads remain in_progress.

===============================================================
```

### Step 3: Recovery Instructions

Provide recovery commands:

```
To check current status:
  bd ready                        # See what's next
  bd list --status in_progress    # Find current work

To resume:
  /beads-loop [--label <label>]   # Sequential
  /beads-swarm [--label <label>]  # Parallel
```

## Data Preservation

- **Completed tasks**: Remain closed
- **In-progress tasks**: Remain in_progress
- **Pending tasks**: Remain pending

The beads database preserves all state. You can resume at any time.

## Example Output

```
===============================================================
LOOP CANCELLED
===============================================================

In-Progress Beads: 1
  - task-003: Add validation middleware

Completed Beads: 2
Pending Beads: 4

Progress is preserved. Completed beads remain closed.
In-progress beads remain in_progress.

To resume:
  /beads-loop
  /beads-swarm

===============================================================
```
