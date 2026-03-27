---
description: Prepare and execute an addon release (version bump, changelog, tag)
---

1. Read the current version from the .toc file
2. Read CHANGELOG.md for context on what has changed
3. Run /api-validate to verify API compliance before release
4. Run luacheck to verify zero warnings
5. Ask me: What version number? What changed in this release?
6. Update the .toc version line (## Version: X.Y.Z)
7. Add the new CHANGELOG.md entry with today's date
8. Show me the complete diff for review
9. After my approval: commit, tag, and push

Commit message format: Release vX.Y.Z: brief description
Tag format: vX.Y.Z
Push both main branch and the tag.
