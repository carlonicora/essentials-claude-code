# Spec-Driven Workflow with OpenSpec

Human validation between requirements and implementation. Catches misunderstandings early—cheaper than fixing code later.

---

## The 4-Stage Workflow

```
              PLANNING PHASE                          EXECUTION PHASE
┌─────────────────────────────────────────┐    ┌─────────────────────────┐
│  ANALYSIS → PLAN → SPEC & VALIDATION    │───▶│  /spec-loop <change-id> │
│                     ↓                   │    │  Work through tasks     │
│              "Is spec correct?"         │    │  until all complete     │
│               NO ←─┴─→ YES              │    └─────────────────────────┘
│               ↓        ↓                │
│            iterate   proceed            │
└─────────────────────────────────────────┘
```

### Stage 1: Analysis

```
ultrathink and traverse and analyse the code to thoroughly understand
the context before preparing a detailed plan. Ask clarifying questions before finalising.
```

### Stage 2: Plan Creation

```bash
/plan-creator Add user authentication with JWT tokens      # Feature
/bug-plan-creator "TypeError at auth.py:45" "Login fails"  # Bug
/code-quality-plan-creator src/auth.ts                     # Refactor
```

### Stage 3: Spec and Validation

```bash
/proposal-creator <plan-file>   # Recommended - converts plan to OpenSpec
/proposal-creator               # Or from current context
```

**Review before looping (do not skip):**
1. Read the generated specs—does it match your mental model?
2. Verify the code in `design.md` is correct and complete
3. Verify edge cases are covered
4. Iterate until satisfied—fix the spec before any code

Fixing a spec is cheap. Debugging bad generated code is expensive.

### Stage 4: Execution

```bash
/spec-loop <change-id>                       # Step mode (default) - pauses after each task
/spec-loop <change-id> --auto                # Auto mode - continuous execution
/spec-loop <change-id> --max-iterations 10   # Limit iterations (optional)
/cancel-spec-loop                            # Stop gracefully
```

**Step mode:** Hook triggers `AskUserQuestion` after each task with Continue/Stop/Pick options.

**Loop mechanism:** Stop hook checks `tasks.md` for uncompleted `- [ ]` tasks. State tracked in `.claude/spec-loop.local.md`.

**Recovery after cancellation:** State is preserved in `.claude/spec-loop.local.md`. Resume by running `/spec-loop <change-id>` again.

---

## OpenSpec Workflow

```bash
openspec init                                    # Initialize
/proposal-creator .claude/plans/feature-plan.md  # Create from plan
/spec-loop <change-id>                           # Implement
openspec archive <change-id>                     # Archive when complete
```

**Artifacts created:** Each file includes `## Plan Reference` with `**Source Plan**: <path>`:
- `proposal.md` — Overview, motivation
- `design.md` — Reference implementation (FULL code COPIED from plan)
- `tasks.md` — Tasks with exit criteria (EXACT commands COPIED from plan)
- `specs/` — Requirements with Given/When/Then scenarios

**Context recovery:** When context compacts, read `tasks.md` for status, then find `## Plan Reference` → `**Source Plan**` to recover full details.

---

## Auto-Decomposition & Scaling

If a plan exceeds thresholds (>2 subsystems or >2000 lines), `/proposal-creator` **automatically** decomposes into multiple linked proposals:

```bash
/proposal-creator .claude/plans/large-feature-plan.md

# Creates:
openspec/changes/add-auth-backend/    # Backend first
openspec/changes/add-auth-frontend/   # Depends on backend
openspec/changes/add-auth-tests/      # Depends on both
```

**Execute sequentially:**
```bash
/spec-loop add-auth-backend
/spec-loop add-auth-frontend
/spec-loop add-auth-tests
```

**Or convert all to beads** for cross-spec dependency tracking:
```bash
/beads-creator openspec/changes/add-auth-backend/ openspec/changes/add-auth-frontend/ openspec/changes/add-auth-tests/
/beads-loop
```

If implementation shows hallucinations or loses track, scale up to [WORKFLOW-BEADS.md](WORKFLOW-BEADS.md).

---

**Related:** [Simple workflow](WORKFLOW-SIMPLE.md) | [Beads workflow](WORKFLOW-BEADS.md) | [Main guide](README.md)
