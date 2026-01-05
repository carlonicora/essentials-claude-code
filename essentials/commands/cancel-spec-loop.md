---
description: "Cancel active spec loop"
allowed-tools: ["Bash"]
---

# Cancel Spec Loop

Gracefully stop the active spec loop while preserving progress.

## Instructions

1. Check if `.claude/spec-loop.local.md` exists
2. If it exists:
   - Read change ID from the file
   - Remove the file: `rm .claude/spec-loop.local.md`
   - Report: "Cancelled spec loop for change: [change-id]"
   - Note: "Progress preserved in: openspec/changes/[change-id]/tasks.md"
   - Note: "Resume later with: /spec-loop [change-id]"
3. If it doesn't exist:
   - Say "No active spec loop found."

## After Cancellation

Your task progress is preserved in `tasks.md`:
- Completed tasks remain marked `[x]`
- Uncompleted tasks remain `[ ]`

To resume later:
```bash
/spec-loop <change-id>
```

The loop will pick up where you left off.
