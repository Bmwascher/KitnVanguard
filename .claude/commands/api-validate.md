---
description: Validate all Lua code against WoW 12.0 Midnight API restrictions
---

Use the api-validator agent to scan all .lua files in this addon
(excluding the Libs/ directory and .wow-api-reference/).

Check every WoW API call against the Secret Values rules and report
any violations. If you find an API you are uncertain about, search
warcraft.wiki.gg for its documentation before flagging it.

After the scan, present a summary of findings sorted by severity.
