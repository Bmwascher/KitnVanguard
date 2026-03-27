---
name: lua-quality
description: >
  Lua code quality for WoW addons using Luacheck linting and StyLua formatting.
  Use when checking code quality, fixing lint warnings, formatting code,
  or preparing code for commit/release.
  Triggers: lint, format, luacheck, stylua, quality, warning, unused variable,
  undefined global, code review, cleanup.
---

# Lua Code Quality

## Luacheck

Run all files: luacheck . --config .luacheckrc
Run single file: luacheck Core.lua --config .luacheckrc

## StyLua

Check formatting: stylua --check .
Auto-format: stylua .

## Common Luacheck Warnings and Fixes

| Warning | Meaning | Fix |
|---------|---------|-----|
| W111 | Setting undefined global | Add to globals in .luacheckrc or make local |
| W112 | Mutating undefined global | Same as above |
| W113 | Accessing undefined global | Add to read_globals in .luacheckrc |
| W211 | Unused local variable | Remove or prefix with _ |
| W212 | Unused argument | Prefix with _ (e.g. function(_, event)) |
| W311 | Value assigned but never used | Remove the assignment |
| W431 | Shadowing upvalue | Rename the inner variable |

## Workflow

1. Write or modify code
2. Run luacheck on the modified file
3. Fix any warnings
4. Run stylua to auto-format
5. Re-run luacheck to confirm zero warnings
6. Commit
