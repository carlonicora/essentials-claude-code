# Beads Workflow for Large Plans

> **Don't start here.** This is the most token-expensive workflow. Use [WORKFLOW-SIMPLE.md](WORKFLOW-SIMPLE.md) first. Escalate to beads only when the simple workflow fails—AI hallucinates mid-task, loses track, or the feature spans multiple days.

[Beads](https://github.com/steveyegge/beads) provides persistent, structured memory that survives session boundaries and context compaction. Use for large features spanning multiple sessions, or when plans cause hallucinations mid-implementation.

---

## What are Beads?

Atomic, self-contained task units in a local graph database. Unlike plans (session-scoped) or specs (project-scoped), beads **persist** across sessions.

| Component | Purpose |
|-----------|---------|
| Requirements | Full requirements copied verbatim |
| Reference Implementation | 20-400+ lines based on complexity |
| Migration Pattern | Exact before/after for file edits |
| Exit Criteria | Specific verification commands |
| Dependencies | `depends_on`/`blocks` relationships |
| Labels | Link to specs (`openspec:feature-name`) |

**Key insight:** When context compacts, `bd ready` always shows what's next. Each bead has everything needed—no reading other files.

---

## Setup

**Install:** `brew tap steveyegge/beads && brew install bd` (or npm: `npm install -g @beads/bd`)

**Initialize:** `bd init --stealth` (keeps `.beads/` out of git, perfect for client projects)

**Essential commands:**
| Command | Action |
|---------|--------|
| `bd ready` | List tasks with no blockers |
| `bd create "Title" -p 0` | Create P0 task |
| `bd dep add <child> <parent>` | Link dependencies |
| `bd close <id> --reason "Done"` | Complete task |

---

## The 5-Stage Workflow

```
PLANNING (Human Control)                    EXECUTION (AI Autonomy)
┌────────────────────────────────────┐      ┌─────────────────────────────────┐
│ 1. Analysis: "ultrathink..."       │      │ 4. /beads-creator <spec>        │
│ 2. /plan-creator → /proposal-creator│─────▶│ 5. /beads-loop                  │
│ 3. Validate spec before proceeding │      │    bd ready → implement → close │
└────────────────────────────────────┘      └─────────────────────────────────┘
```

### Stages 1-3: Planning

```
ultrathink and traverse and analyse the code. Ask clarifying questions before finalising.
```

```bash
/plan-creator <task>                # Create plan
/proposal-creator <plan-path>       # Convert to OpenSpec
```

**Validate before beads:** Read spec, verify `design.md` code is correct, check task breakdown. Skipping leads to wasted work.

### Stage 4: Import to Beads

```bash
# Single spec:
/beads-creator openspec/changes/<name>/

# Multiple specs (from auto-decomposed proposal):
/beads-creator openspec/changes/<name-1>/ openspec/changes/<name-2>/
```

**Auto-decomposition:** Beads >200 lines are automatically split—parent marked `decomposed`, child sub-beads created with `--parent`. Multi-spec preserves cross-spec dependencies.

**Output shows execution order:**
```
EXECUTION ORDER (by priority):
  P0 (no blockers): task-001, task-002
  P1 (after P0): task-003, task-004
  P2 (after P1): task-005
```

**Review beads:** `bd list -l "openspec:<name>"` then `bd show <id>` — verify complete code snippets and exit criteria.

### Stage 5: Execute

```bash
/beads-loop --label openspec:<name>           # Step mode (default)
/beads-loop --auto --label openspec:<name>    # Auto mode
/cancel-beads                                  # Stop gracefully
```

**Step mode:** After each bead, outputs execution status then pauses:
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

**Loop mechanism:** Stop hook checks `bd ready` for remaining tasks. If ready beads exist, loop continues. State tracked in `.claude/beads-loop.local.md`.

**Loop cycle:** `bd ready` → pick highest priority → implement → `bd close` → (if OpenSpec: mark tasks.md) → repeat until no ready beads.

---

## The Self-Contained Bead Rule

Each bead must be implementable with ONLY its description. The Context Chain section is for disaster recovery only.

| Bad | Good |
|-----|------|
| "See design.md" | FULL code (50-200+ lines) in bead |
| "Run tests" | `npm test -- stripe-price` |
| "Update entity" | File + line numbers + before/after |

```bash
bd create "Add fields to entity.ts" -t task -p 2 -l "openspec:billing" -d "
## Context Chain (disaster recovery ONLY)
**Spec Reference**: openspec/changes/billing/
**Plan Reference**: .claude/plans/billing-plan.md

## Requirements
<COPY full text from spec - not a reference>

## Reference Implementation
EDIT: path/to/file.ts
**BEFORE** (line 25): <code>
**AFTER**: <code>

## Exit Criteria
npm test -- stripe-price && npm run typecheck
"
```

The `## Context Chain` section is for disaster recovery only—normally the bead description has everything needed.

---

## When to Use What

| Situation | Tool |
|-----------|------|
| New feature | OpenSpec first |
| Spec approved | OpenSpec + Beads |
| Bug fix, small task | `bd create` directly |
| Found during work | `bd create --discovered-from <parent>` |

---

## Land the Plane Protocol

Work is NOT complete until `git push` succeeds.

```bash
bd close <id> --reason "Completed"
git pull --rebase && bd sync && git add -A && git commit -m "chore: session end" && git push
bd ready && git status    # Must be clean
```

---

## Configuration

```bash
bd setup claude    # Install hooks for Claude Code
bd setup cursor    # Cursor IDE rules
```

**Protected branches:** `bd init --branch beads-sync` + `bd daemon --start --auto-commit`

**Labels:** `openspec:<name>`, `spec:<name>`, `discovered`, `tech-debt`, `blocked-external`

---

## Resources

- [Beads GitHub](https://github.com/steveyegge/beads)
- [Installing bd](https://github.com/steveyegge/beads/blob/main/docs/INSTALLING.md)
- [Protected Branches](https://github.com/steveyegge/beads/blob/main/docs/PROTECTED_BRANCHES.md)

**Related:** [Simple workflow](WORKFLOW-SIMPLE.md) | [Spec workflow](WORKFLOW-SPEC.md) | [Main guide](README.md)
