# KitnVanguard — WoW Addon Project

## Project Overview
KitnVanguard is a World of Warcraft addon for coordinating dispel assignments
on the Lightblinded Vanguard encounter (Mythic, The Voidspire, Midnight S1).
Author: Kitn (GitHub: Bmwascher)

The addon assigns each of 5 healers a specific player to dispel when
Avenger's Shield (spell ID 1246502) applies debuffs to 8 (or all 20) players.
All healer clients independently compute the same assignment using a shared
priority list — no addon communication is used inside instances.

Read @KitnVanguard_SPEC.md for the full design specification.

## Repository Structure
```
KitnVanguard/
├── KitnVanguard.toc           # Addon manifest
├── Core.lua                    # Initialization, event handling, config
├── Modules/
│   ├── SlashCommands.lua       # /kv command router and all subcommands
│   ├── DebuffDetector.lua      # UNIT_AURA scanning for spell 1246502
│   ├── PriorityEngine.lua      # Deterministic sort and healer assignment
│   ├── FrameFinder.lua         # Raid frame detection (Blizzard/ElvUI/Cell/VuhDo)
│   └── GlowManager.lua        # Apply and remove glow on raid frames
├── Libs/                       # Embedded libraries (LibCustomGlow if needed)
├── .wow-api-reference/         # Symlink to Blizzard API docs
└── .claude/                    # Claude Code config
```

## CRITICAL: WoW 12.0 API Compliance
This addon runs INSIDE raid instances during COMBAT. Secret Values and
instance restrictions are directly relevant to every line of code.

BEFORE writing ANY code:
1. Read .claude/skills/wow-midnight-api/SKILL.md FIRST
2. Check .wow-api-reference/ for the specific API's SecretReturns fields
3. If uncertain, search warcraft.wiki.gg for the API function
4. NEVER assume an API works the same as pre-12.0
5. After writing combat code, run the api-validator agent

### Specific to this addon:
- Player names (UnitName for raid members) are NOT secret — safe to use
- UNIT_AURA event still fires in 12.0 — this is our detection mechanism
- Aura spell IDs should be accessible for friendly player debuffs
- Use issecretvalue() guard on ANY AuraData field before operating on it
- Do NOT use COMBAT_LOG_EVENT_UNFILTERED — it is removed
- Do NOT use SendAddonMessage — blocked inside instances
- Do NOT perform math on health/power values — not needed for this addon
- Duration/expiration fields in AuraData MAY be secret — we only need
  the boolean "has debuff or not" for MVP, not remaining duration

warcraft.wiki.gg is the authoritative community reference (current as of 12.0.1).

## Code Style
- Lua 5.1 (WoW embedded runtime)
- Local variables preferred over globals
- All addon globals prefixed with KitnVanguard or KITNVANGUARD
- camelCase for local functions, PascalCase for module-level functions
- Print messages: |cff00ccffKitnVanguard:|r for info, |cffff6060KitnVanguard:|r for errors
- Defensive nil checks on ALL WoW API returns
- Keep functions short and focused
- Comment non-obvious WoW API usage
- Use full braces and clear formatting
- Every module uses the shared namespace: local ADDON_NAME, ns = ...

## WoW-Specific Rules
- NEVER call protected functions outside secure handlers
- ALWAYS check InCombatLockdown() before modifying secure frames
- Use C_Timer.After(0, func) for next-frame execution, not OnUpdate polling
- SavedVariables: KitnVanguardDB (declared in .toc AND initialized in Core.lua)
- The FrameFinder module must handle frames not existing yet (lazy detection)
- Glow application must not taint raid frames — use overlay frames if needed

## Module Responsibilities
- Core.lua: addon init, SavedVariables, namespace setup, nothing else
- SlashCommands.lua: /kv router, import/export, healer number, test, diag
- DebuffDetector.lua: UNIT_AURA registration, scan for spell 1246502, callbacks
- PriorityEngine.lua: sort debuffed players by priority list, compute assignments
- FrameFinder.lua: detect raid frame addon, find unit frames, cache references
- GlowManager.lua: apply/remove glow overlays, manage glow lifecycle

## Verification After Code Changes
After modifying any .lua file:
1. Run luacheck on the modified file: luacheck <file> --config .luacheckrc
2. Run /api-validate to check 12.0 compliance
3. Remind the user to /reload in WoW and check BugSack for errors
4. Test with /kv test to simulate debuff assignments

## Git Workflow
- NEVER commit directly to main for feature work — use a branch
- Commit messages: lowercase, imperative mood
- One logical change per commit

## Reference Files
See @KitnVanguard_SPEC.md for complete design specification
See @.wow-api-reference/ for Blizzard API documentation
