---
description: Comprehensive codebase audit (structure, lint, API compliance, quality)
---

Perform a full audit in this order:

1. Structure: Read the .toc. Verify every listed file exists.
   Check for .lua files NOT in the .toc (missing from load order).

2. Lint: Run luacheck on all addon .lua files (not Libs/).
   Report any warnings or errors.

3. API compliance: Use the api-validator agent to check all code
   against 12.0 Midnight restrictions.

4. SavedVariables: Verify all SV tables in the .toc are properly
   initialized with defaults in the Lua code.

5. Slash commands: Verify all Commands[] entries have corresponding
   entries in the help command output.

6. Code review: Use the code-reviewer agent for quality check.

Present a unified report with all findings, prioritized by severity.
