# Agent Prompt Template

This template defines the standard structure for agent prompts in `essentials/agents/*.md`.

---

## Template Structure

```markdown
---
name: <agent-name>-default
description: |
  <One-paragraph description of what this agent does.>

  <Technical details about tools/capabilities used.>

  Examples:
  - User: "<example user request>"
    Assistant: "<example assistant response>"
  - User: "<example user request>"
    Assistant: "<example assistant response>"
model: <opus|sonnet|haiku>
color: <green|purple|orange|blue|cyan|yellow|red>
---

You are an expert <Role Title> who <core mission statement>. <Additional context about expertise and approach>.

## Core Principles

1. **<Principle 1 Name>** - <Brief description>
2. **<Principle 2 Name>** - <Brief description>
3. **<Principle 3 Name>** - <Brief description>
...
N. **No user interaction** - Never use AskUserQuestion, slash command handles all user interaction

## You Receive

From the slash command:
1. **<Input 1>**: <Description of input>
2. **<Input 2>**: <Description of input>

## First Action Requirement

**<First action the agent MUST take>.** This is mandatory before any analysis.

---

# PHASE 1: <PHASE NAME>

## Step 1: <Step Name>

<Step description>

```
<Code block, pseudocode, or tool usage example>
```

## Step 2: <Step Name>

<Step description>

---

# PHASE 2: <PHASE NAME>

## Step 1: <Step Name>

<Step description>

---

# PHASE N: <FINAL OUTPUT>

## Required Output Format

```
<Exact output format the agent must return>
```

---

# TOOLS REFERENCE

**LSP Tool Operations (if applicable):**
- `LSP(operation="documentSymbol", filePath, line, character)` - Get all symbols in a document
- `LSP(operation="goToDefinition", filePath, line, character)` - Find where a symbol is defined
- `LSP(operation="findReferences", filePath, line, character)` - Find all references to a symbol

**File Operations (Claude Code built-in):**
- `Read(file_path)` - Read file contents
- `Glob(pattern)` - Find files by pattern
- `Grep(pattern)` - Search file contents

---

# CRITICAL RULES

1. **<Rule 1>** - <Explanation>
2. **<Rule 2>** - <Explanation>
3. **<Rule 3>** - <Explanation>
...
N. **Minimal orchestrator output** - <Return format description>

---

# SELF-VERIFICATION CHECKLIST

**Phase 1 - <Phase Name>:**
- [ ] <Verification item 1>
- [ ] <Verification item 2>

**Phase 2 - <Phase Name>:**
- [ ] <Verification item 1>
- [ ] <Verification item 2>

**Output:**
- [ ] <Final verification item>
- [ ] Minimal output format used

---

## Tools Available

**Do NOT use:**
- `AskUserQuestion` - NEVER use this, slash command handles all user interaction

**DO use:**
- `<Tool 1>` - <Purpose>
- `<Tool 2>` - <Purpose>
```

---

## Section Requirements

### Frontmatter (Required)
- `name`: Agent identifier (kebab-case with `-default` suffix)
- `description`: Multi-line description with examples
- `model`: One of opus, sonnet, haiku
- `color`: Visual indicator color

### Mission Statement (Required)
- Single paragraph defining the agent's expert role
- Clear statement of core mission

### Core Principles (Required)
- Numbered list of guiding principles
- **Always end with**: "No user interaction" principle

### You Receive (Required)
- Numbered list of inputs from the orchestrating command
- Clear parameter names and descriptions

### First Action Requirement (Required)
- Bold statement of first mandatory action
- Prevents agents from skipping initial steps

### Phases (Required)
- Numbered phases (PHASE 1, PHASE 2, etc.)
- Each phase has numbered steps
- Use code blocks for examples
- Final phase defines output format

### Tools Reference (Conditional)
- Required if using LSP or specialized tools
- Document tool signatures and purposes

### Critical Rules (Required)
- Numbered list of rules
- End with output format rule

### Self-Verification Checklist (Required)
- Organized by phase
- Checkbox format for each item
- Helps ensure completeness

### Tools Available (Required)
- Explicit "Do NOT use" section (always includes AskUserQuestion)
- "DO use" section with allowed tools
