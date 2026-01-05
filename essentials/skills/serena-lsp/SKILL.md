---
name: serena-lsp
description: LSP-powered code navigation for understanding architecture. Use when exploring codebase structure, finding symbol definitions, discovering class methods, or analyzing code architecture without editing.
---

# Serena LSP - Read-Only Code Navigation

Fast, LSP-powered code navigation for understanding architecture without editing.

## Available Tools (9 Read-Only)

**Symbol Navigation (4):**
- `get_symbols_overview` - Get class/function hierarchy
- `find_symbol` - Find symbols by name with LSP kind filtering
- `find_referencing_symbols` - Find all uses of a symbol
- `search_for_pattern` - Regex search in code

**File Operations (3):**
- `read_file` - Read file contents
- `list_dir` - List directories
- `find_file` - Find files by pattern

**Project (2):**
- `activate_project` - Activate project
- `get_current_config` - View config

## When to Use Serena

**Use Serena for:**
- Understanding class/service structure
- Finding symbol definitions and references
- Exploring codebase architecture
- Discovering methods in a class
- Searching for code patterns

**Don't use Serena for:**
- Reading single files (use `Read`)
- Making changes (use `Edit`)
- Searching 2-3 files (use `Grep`)
- Simple text searches (use `Grep`)

## Quick Start

**Step 1: Get file overview**
```
get_symbols_overview(relative_path="src/services/auth.service.ts", depth=1)
```
Returns: Class + methods + interfaces

**Step 2: Find specific symbol**
```
find_symbol(name_path_pattern="AuthService", relative_path="src/services", include_kinds=[5])
```
Returns: Class location with all method locations

**Step 3: Find all references**
```
find_referencing_symbols(name_path="AuthService/login", relative_path="src/services/auth.service.ts")
```
Returns: All references with code snippets

**Step 4: Search for patterns**
```
search_for_pattern(substring_pattern="useState", restrict_search_to_code_files=true, relative_path="src/components")
```
Returns: Files with exact line numbers

## LSP Symbol Kinds (for filtering)

**Common kinds:**
- `5` = Class
- `6` = Method
- `11` = Interface
- `12` = Function
- `13` = Variable

**Example:** Find only classes named "Service"
```
find_symbol(name_path_pattern="Service", include_kinds=[5])
```

## Common Workflows

**1. Explore a new service**
```
get_symbols_overview(relative_path="src/services/auth.service.ts", depth=1)
find_symbol(name_path_pattern="AuthService/login", include_body=true)
find_referencing_symbols(name_path="AuthService/login", relative_path="src/services/auth.service.ts")
```

**2. Find all services**
```
find_symbol(name_path_pattern="Service", relative_path="src/services", include_kinds=[5])
```

**3. Find React hooks usage**
```
search_for_pattern(substring_pattern="useState|useEffect", relative_path="src")
```

**4. Explore component structure**
```
get_symbols_overview(relative_path="src/components/LoginForm.tsx", depth=2)
```

## Name Path Format

**Symbol paths within a file:**
- Function: `myFunction`
- Class method: `MyClass/myMethod`
- Nested: `OuterClass/InnerClass`

**Search patterns:**
- `"login"` - Any symbol named "login"
- `"AuthService/login"` - Symbols with this path suffix
- `"/AuthService/login"` - Exact match only

## Best Practices

1. **Scope searches** - Always use `relative_path` parameter
2. **Start with overview** - Use `get_symbols_overview` first
3. **Filter by kind** - Use `include_kinds=[5]` for classes only
4. **Use right tool** - Read for files, Grep for text, Serena for symbols
