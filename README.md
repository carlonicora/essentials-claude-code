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
/proposal-creator "Add user authentication with JWT"
/beads-creator openspec/changes/user-auth/
/beads-loop
# Loop continues until no ready beads remain
```

## Install

```bash
/plugin marketplace add GantisStorm/essentials-claude-code
/plugin install essentials@essentials-claude-code
```

**Dependencies:**
| Tool | Install |
|------|---------|
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | Required for `/proposal-creator` |
| [Beads](https://github.com/steveyegge/beads) | `brew tap steveyegge/beads && brew install bd` |

## Commands

| Command | Purpose | Output |
|---------|---------|--------|
| `/proposal-creator [plan\|task]` | Create OpenSpec proposal | `openspec/changes/<id>/` |
| `/beads-creator <spec> [spec2...]` | Convert spec(s) to beads | Beads database |
| `/beads-loop [--step\|--auto]` | Execute beads iteratively | Task completion |
| `/cancel-beads` | Stop beads loop gracefully | Clean exit |

## Workflow

```
PLANNING                              EXECUTION
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ 1. /proposal-creator <task>     │──▶│ 3. /beads-creator <spec>        │
│ 2. Validate spec before beads   │   │ 4. /beads-loop                  │
└─────────────────────────────────┘   │    bd ready → implement → close │
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

```bash
/beads-loop                                    # Step mode (default)
/beads-loop --auto                             # Auto mode
/beads-loop --label openspec:billing           # Filter by label
/beads-loop --max-iterations 5                 # Limit iterations
/cancel-beads                                  # Stop gracefully
```

**Step mode:** Pauses after each bead for human control:
```
===============================================================
BEAD COMPLETED: task-001
===============================================================
Progress: 1/5 beads complete

EXECUTION ORDER (remaining):
  Next → task-002: Add validation (P0)
  Then → task-003: Write tests (P1, blocked until P0 done)
===============================================================
```

## What are Beads?

Atomic, self-contained task units in a local graph database. Unlike session-scoped plans, beads **persist** across sessions.

| Component | Purpose |
|-----------|---------|
| Requirements | Full requirements copied verbatim |
| Reference Implementation | 20-400+ lines based on complexity |
| Migration Pattern | Exact before/after for file edits |
| Exit Criteria | Specific verification commands |
| Dependencies | `depends_on`/`blocks` relationships |

**Key insight:** When context compacts, `bd ready` always shows what's next. Each bead has everything needed—no reading other files.

### Essential `bd` Commands

| Command | Action |
|---------|--------|
| `bd ready` | List tasks with no blockers |
| `bd show <id>` | Show full task details |
| `bd update <id> --status in_progress` | Start working on task |
| `bd close <id> --reason "Done"` | Complete task |
| `bd list --status in_progress` | Find current work |

## The Self-Contained Bead Rule

Each bead must be implementable with ONLY its description.

| Bad | Good |
|-----|------|
| "See design.md" | FULL code (50-200+ lines) in bead |
| "Run tests" | `npm test -- stripe-price` |
| "Update entity" | File + line numbers + before/after |

## How Loops Work

Based on [Ralph Wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) stop-hook pattern.

1. Setup script creates state file (`.claude/beads-loop.local.md`)
2. Stop hooks intercept exit attempts
3. Hook checks `bd ready` for remaining tasks
4. Not complete → block with continue prompt. Complete → allow exit.

**Recovery:** State file + bead descriptions enable resume after context compaction or new session.

## Best Practices

1. **Validate specs before beads** — Editing specs is cheap; debugging bad beads is expensive
2. **Exit criteria are non-negotiable** — Not "tests pass" but exact commands: `npm test -- auth`
3. **Use step mode** — Prevents context compaction and quality degradation on large task sets
4. **Review beads** — `bd list -l "openspec:<name>"` then `bd show <id>` to verify code snippets

## Stealth Mode

For brownfield development, keep tracking files out of git:

```bash
bd init --stealth    # Adds .beads/ to .gitignore
```

## Resources

- [Beads GitHub](https://github.com/steveyegge/beads)
- [OpenSpec GitHub](https://github.com/Fission-AI/OpenSpec)
- [Installing bd](https://github.com/steveyegge/beads/blob/main/docs/INSTALLING.md)

## License

MIT
