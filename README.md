# Essentials for Claude Code

**Plan → Spec → Beads → Execute.** Persistent task management that survives context compaction and session boundaries.

## The Problem

Claude Code is powerful, but without structure it can:

- Start coding before understanding the full picture
- Lose track of what's done when context gets long
- Say "done" when tests are still failing
- Hallucinate on large features that exceed context

**The Solution:** Break work into self-contained beads with full implementation details.

```bash
/essentials:proposal-creator "Add user authentication with JWT"
/essentials:beads-creator openspec/changes/user-auth/
/essentials:beads-loop           # Sequential execution
# OR
/essentials:beads-swarm          # Parallel execution
```

## Install

```bash
/plugin marketplace add carlonicora/essentials-claude-code
/plugin install essentials@essentials-claude-code
```

**Dependencies:**
| Tool | Install |
|------|---------|
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | Required for `/proposal-creator` |
| [Beads](https://github.com/steveyegge/beads) | `brew tap steveyegge/beads && brew install bd` |

## Commands

| Command                                       | Purpose                    | Output                   |
| --------------------------------------------- | -------------------------- | ------------------------ |
| `/essentials:proposal-creator [plan\|task]`   | Create OpenSpec proposal   | `openspec/changes/<id>/` |
| `/essentials:beads-creator <spec> [spec2...]` | Convert spec(s) to beads   | Beads database           |
| `/essentials:beads-loop [--step\|--auto]`     | Execute beads sequentially | Task completion          |
| `/essentials:beads-swarm [--workers N]`       | Execute beads in parallel  | Task completion          |
| `/essentials:cancel-loop`                     | Stop active loop           | Clean exit               |
| `/essentials:cancel-swarm`                    | Stop swarm workers         | Clean exit               |

## Workflow

```
PLANNING                              EXECUTION
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ 1. /proposal-creator <task>     │──▶│ 3. /beads-creator <spec>        │
│ 2. Validate spec before beads   │   │ 4. /beads-loop (sequential)     │
└─────────────────────────────────┘   │    OR /beads-swarm (parallel)   │
                                      └─────────────────────────────────┘
```

### Stage 1: Create Proposal

```bash
/proposal-creator "Add billing integration with Stripe"
```

Creates an OpenSpec proposal at `openspec/changes/<id>/` with:

- `proposal.md` - Overview and scope
- `design.md` - Reference implementation code
- `tasks.md` - Task breakdown with exit criteria

### Stage 2: Validate Spec

**Review before beads:** Read spec, verify `design.md` code is correct, check task breakdown. Skipping leads to wasted work.

### Stage 3: Import to Beads

```bash
# Single spec:
/beads-creator openspec/changes/billing/

# Multiple specs (from auto-decomposed proposal):
/beads-creator openspec/changes/billing-backend/ openspec/changes/billing-frontend/
```

**Auto-decomposition:** Beads >200 lines are automatically split—parent marked `decomposed`, child sub-beads created.

### Stage 4: Execute

**Sequential (loop):**

```bash
/beads-loop                      # Step mode (default) - pauses after each
/beads-loop --auto               # Auto mode - no pauses
/beads-loop --label openspec:billing
```

**Parallel (swarm):**

```bash
/beads-swarm                     # Default: 3 workers
/beads-swarm --workers 5         # More parallel workers
/beads-swarm --model haiku       # Faster model for simple beads
```

**Cancel execution:**

```bash
/cancel-loop                     # Stop loop
/cancel-swarm                    # Stop all swarm workers
```

## Loop vs Swarm

| Aspect          | Loop                            | Swarm                        |
| --------------- | ------------------------------- | ---------------------------- |
| **Concurrency** | 1 task at a time                | Up to N workers (default: 3) |
| **Visibility**  | Live conversation               | Check via `ctrl+t`           |
| **Best for**    | Interdependent tasks, debugging | Independent parallel phases  |
| **Control**     | Step mode pauses                | Workers run autonomously     |

**Choose Loop when:**

- Tasks depend heavily on each other
- You want to review each step
- Debugging issues

**Choose Swarm when:**

- Many independent tasks
- Want maximum speed
- Large refactoring with parallel phases

## Progress Visualization

Press `ctrl+t` at any time during execution to see:

- Active workers (swarm)
- Tasks in progress
- Completed tasks
- Pending tasks

## What are Beads?

Atomic, self-contained task units in a local graph database. Unlike session-scoped plans, beads **persist** across sessions.

| Component                | Purpose                             |
| ------------------------ | ----------------------------------- |
| Requirements             | Full requirements copied verbatim   |
| Reference Implementation | 20-400+ lines based on complexity   |
| Migration Pattern        | Exact before/after for file edits   |
| Exit Criteria            | Specific verification commands      |
| Dependencies             | `depends_on`/`blocks` relationships |

**Key insight:** When context compacts, `bd ready` always shows what's next. Each bead has everything needed—no reading other files.

### Essential `bd` Commands

| Command                               | Action                      |
| ------------------------------------- | --------------------------- |
| `bd ready`                            | List tasks with no blockers |
| `bd show <id>`                        | Show full task details      |
| `bd update <id> --status in_progress` | Start working on task       |
| `bd close <id> --reason "Done"`       | Complete task               |
| `bd list --status in_progress`        | Find current work           |

## The Self-Contained Bead Rule

Each bead must be implementable with ONLY its description.

| Bad             | Good                               |
| --------------- | ---------------------------------- |
| "See design.md" | FULL code (50-200+ lines) in bead  |
| "Run tests"     | `npm test -- stripe-price`         |
| "Update entity" | File + line numbers + before/after |

## Best Practices

1. **Validate specs before beads** — Editing specs is cheap; debugging bad beads is expensive
2. **Exit criteria are non-negotiable** — Not "tests pass" but exact commands: `npm test -- auth`
3. **Use step mode for complex tasks** — Prevents quality degradation
4. **Use swarm for independent tasks** — Maximizes parallelism
5. **Review beads** — `bd list -l "openspec:<name>"` then `bd show <id>` to verify code snippets

## Stealth Mode

For brownfield development, keep tracking files out of git:

```bash
bd init --stealth    # Adds .beads/ to .gitignore
```

## Context Recovery

If you lose track during execution:

```bash
bd ready                        # See what's next
bd list --status in_progress    # Find current work
bd show <id>                    # Full task details
```

## Resources

- [Beads GitHub](https://github.com/steveyegge/beads)
- [OpenSpec GitHub](https://github.com/Fission-AI/OpenSpec)
- [Installing bd](https://github.com/steveyegge/beads/blob/main/docs/INSTALLING.md)

## License

MIT
