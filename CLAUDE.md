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
├── Core.lua                    # Initialization, SavedVariables, namespace
├── Modules/
│   ├── SlashCommands.lua       # /kv command router and all subcommands
│   ├── DebuffDetector.lua      # UNIT_AURA detection with collection window
│   ├── PriorityEngine.lua      # Two-pass healer assignment (self-dispel + priority)
│   ├── GlowManager.lua         # LibCustomGlow glow on raid frames (LibGetFrame)
│   ├── AlertFrame.lua           # Center-screen text + class icon alert
│   ├── Sync.lua                 # AceComm priority list sync on ready check
│   └── SettingsPanel.lua        # Blizzard addon settings integration
├── GUI/
│   ├── Theme.lua                # Dark theme colors and font helpers
│   ├── Widgets.lua              # Custom UI widgets (toggle, dropdown, slider, etc.)
│   └── ConfigFrame.lua          # Main config window with tabbed interface
├── Libs/                       # Embedded libraries (LibCustomGlow, LibGetFrame, AceComm, etc.)
├── Media/                      # Textures (collapse.tga, KitnCustomCrossv3.png)
├── .wow-api-reference/         # Symlink to Blizzard API docs
└── .claude/                    # Claude Code config
```

## IMPORTANT: Debug-First Workflow
NEVER guess at fixes or randomly edit code when something isn't working.
Always follow this sequence:

1. GATHER DATA FIRST — Create a small in-game debug macro or /run command
   to print the actual values, table structures, or event payloads involved.
   Paste the output back here before making any code changes.
2. DIAGNOSE — Analyze the debug output to identify the actual root cause.
   Many issues in 12.0 are caused by secret values or changed API behavior
   that can only be confirmed with real in-game data.
3. PROPOSE — Suggest a targeted fix based on the diagnosis. Explain WHY
   the fix works, not just what it changes.
4. IMPLEMENT — Only after the diagnosis is confirmed, make the minimal
   code change needed. Do not refactor unrelated code at the same time.
5. VERIFY — Run luacheck, then remind the user to /reload and test.

When the user reports "X isn't working," your FIRST response should be a
debug command to run in-game, NOT a code edit. The WoW runtime is the
source of truth — not assumptions about how APIs behave.

## CRITICAL: WoW 12.0 API Compliance
This addon runs INSIDE raid instances during COMBAT. Secret Values and
instance restrictions are directly relevant to every line of code.

BEFORE writing ANY code:
1. Read .claude/skills/wow-midnight-api/SKILL.md FIRST
2. Check .wow-api-reference/ for the specific API's SecretReturns fields
3. If uncertain, search warcraft.wiki.gg for the API function
4. NEVER assume an API works the same as pre-12.0
5. After writing combat code, run the api-validator agent

### VERIFIED IN-GAME (March 2026):
- C_UnitAuras.GetAuraDataByIndex() returns SECRET fields inside instances
  (spellId, name, isHarmful, dispelName, duration — all secret)
- UNIT_AURA event info.addedAuras table returns CLEAN non-secret values
  (spellId, name, dispelName, isHarmful — all readable)
- auraInstanceID is NOT secret in either path
- Player names via UnitName() are NOT secret for raid members
- The correct approach: use event payload (info.addedAuras) for detection,
  NEVER scan with GetAuraDataByIndex inside instances

### Specific to this addon:
- Spell ID 1246502 is confirmed as the Avenger's Shield DEBUFF (not just the cast)
- Debuff name: "Avenger's Shield", dispelName: "Magic", isHarmful: true
- Detection uses UNIT_AURA event payload (info.addedAuras), NOT GetAuraDataByIndex
- Tracks by auraInstanceID for removal detection via info.removedAuraInstanceIDs
- Do NOT use COMBAT_LOG_EVENT_UNFILTERED — it is removed in 12.0
- Do NOT use SendAddonMessage — blocked inside instances

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
- Core.lua: addon init, SavedVariables (deep merge), namespace, minimap button
- SlashCommands.lua: /kv router and all subcommands
- DebuffDetector.lua: UNIT_AURA detection, encounter scoping, healer list building
- PriorityEngine.lua: two-pass assignment (self-dispel + priority), dwarf deprioritization
- GlowManager.lua: LibCustomGlow glow on raid frames via LibGetFrame
- AlertFrame.lua: center-screen text alert with class icon and sound
- Sync.lua: AceComm priority list sync on ready check / pull timer
- SettingsPanel.lua: Blizzard addon settings integration
- GUI/ConfigFrame.lua: tabbed config GUI (General, Scan Priority, Glow, Text Alert)

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
