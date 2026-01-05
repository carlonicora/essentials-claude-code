# Simple Workflow: Plan + Implement

Single-session features, bug fixes, and refactoring. For larger work: [WORKFLOW-BEADS.md](WORKFLOW-BEADS.md). For validation before coding: [WORKFLOW-SPEC.md](WORKFLOW-SPEC.md).

## Overview

```
PLANNING                                EXECUTION
┌───────────────────────────────┐       ┌───────────────────────────────┐
│ 1. Analysis: "ultrathink..."  │       │ /implement-loop plan.md       │
│ 2. /plan-creator <task>       │──────▶│   • Create todos from plan    │
│    Output: .claude/plans/...  │       │   • Implement each todo       │
└───────────────────────────────┘       │   • Run exit criteria         │
                                        │   • Repeat until all pass     │
                                        └───────────────────────────────┘
```

**What is a Plan?** File in `.claude/plans/` with:
- **Reference Implementation** — Complete, copy-paste-ready code (50-200+ lines)
- **Migration Patterns** — Exact before/after code with line numbers
- **Exit Criteria** — Specific verification commands (`npm test -- auth`, not "run tests")

The plan is the **source of truth**. When context compacts, the loop re-reads it.

---

## Stage 1: Planning

Start with deep analysis:
```
ultrathink and traverse and analyse the code to thoroughly understand
the context before preparing a detailed plan. Ask clarifying questions before finalising.
```

Then create the plan:
```bash
/plan-creator Add user authentication with JWT tokens       # Feature
/bug-plan-creator "TypeError at auth.py:45" "Login fails"   # Bug
/code-quality-plan-creator src/auth.ts src/api.ts           # Quality
```

**Review before looping:**
- [ ] Architecture makes sense
- [ ] Reference code is correct
- [ ] Exit criteria are exact commands
- [ ] File paths match your code

Fixing a plan is cheap. Debugging bad generated code is expensive.

---

## Stage 2: Execution

```bash
/implement-loop .claude/plans/user-authentication-3k7f2-plan.md
```

**Modes:**
| Mode | Command | Behavior |
|------|---------|----------|
| Step (default) | `/implement-loop plan.md` | Pauses after each todo |
| Auto | `/implement-loop plan.md --auto` | Runs continuously |
| Cancel | `/cancel-implement` | Stops, preserves progress |

**Step mode:** Hook triggers `AskUserQuestion` after each todo. You'll see:
```
Continue implementation? [Continue] / [Stop]
```
Select **Continue** to proceed to the next todo, or **Stop** to end the loop gracefully (preserves progress).

**Auto-decomposition:** After reading plan, agent assesses complexity. If >5 files, >500 lines, or >2 subsystems → auto-creates grouped sub-todos via `TodoWrite`.

**Loop mechanism:** Stop hook in `hooks.json` intercepts exit attempts, checks transcript for completion signals (`exit criteria passed`). State tracked in `.claude/implement-loop.local.md`.

**Exit vs Stop:** The loop *exits* automatically when all exit criteria pass. User-initiated *Stop* (via step mode or `/cancel-implement`) ends the loop early but preserves all progress.

---

## Tips

1. **Invest in planning** — Quality prompts yield quality plans
2. **Be specific about done** — Exit criteria = exact commands, not descriptions
3. **Watch for hallucinations** — Sign the plan may exceed context (scale up to beads)

---

## Context Recovery

When context compacts mid-loop:
1. Re-read the plan file (path in `.claude/implement-loop.local.md`)
2. Check todo list status to see completed/pending items
3. Continue with the next pending todo
