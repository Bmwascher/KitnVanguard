---
description: Quick bug fix - paste an error, find the cause, fix it
---

Ask me to paste the Lua error message or describe the bug.

Then:
1. Parse the error for addon name, file name, line number, and error type
2. Read that file and the surrounding context (plus or minus 20 lines)
3. Identify the root cause
4. Check if the root cause is a 12.0 API change (very common right now)
5. Fix it using the correct 12.0 pattern
6. Grep the entire codebase for the same pattern and fix all instances
7. Run luacheck on all modified files
8. Show me the complete diff before committing
