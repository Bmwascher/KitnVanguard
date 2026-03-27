# KitnVanguard — Design Specification

## Purpose
A WoW 12.0 Midnight addon for coordinating dispel assignments on the
Lightblinded Vanguard encounter (Mythic difficulty, The Voidspire raid).

The boss casts Avenger's Shield (spell ID 1246502) which hits 8 players
(or all 20 during empowered casts) and applies a magic DoT debuff that
must be dispelled. This addon assigns each of 5 healers a specific
player to dispel based on a pre-configured priority list, and glows
that player's raid frame so the healer knows exactly who to dispel.

## Core Design Principle
All 5 healer clients must independently reach the SAME dispel assignment
without communicating. This is mandatory because SendAddonMessage is
blocked inside instances in WoW 12.0 Midnight.

The solution: deterministic sorting. Every client has the same priority
list, detects the same debuffs via UNIT_AURA, sorts them identically,
and each healer knows their number (1-5). Healer #3 always dispels
priority target #3. Pure math, no communication needed.

## Architecture

### Configuration (pre-instance)
- Heal lead creates a priority list: an ordered ranking of all 20 raid
  members from highest to lowest dispel priority
- Priority is based on class vulnerability (e.g., tanks and low-HP
  classes are higher priority than self-sustain classes)
- Heal lead exports this as a compact string
- Each healer imports the string and sets their healer number (1-5)
- Config persists in SavedVariables between sessions

### Priority List Format
- Ordered list of player names from priority 1 (most urgent) to 20 (least)
- When 8 players get debuffed, the addon finds which of them rank
  highest in the priority list
- Healer #1 dispels the highest priority debuffed player
- Healer #2 dispels the second highest, etc.
- Healers #1-5 each get one assignment
- The remaining 3 debuffed players are unassigned (handled by whoever
  is free, or by Mass Dispel)

### Empowered Cast Handling (all 20 debuffed)
- Same logic: sort all 20 by priority list
- Healers #1-5 each get their numbered target
- After dispelling, the addon could reassign the next undispelled target
  (stretch goal, not MVP)

### Detection System
- Register for UNIT_AURA event
- On UNIT_AURA: scan all raid members for aura with spell ID 1246502
- Build a list of currently debuffed players
- Sort that list by position in the priority list
- Assign healer #N to sorted position #N
- Trigger glow on the assigned player's raid frame
- When the debuff is dispelled (aura removed), remove the glow

### Raid Frame Glow System
This is the hardest engineering problem. Each raid frame addon creates
frames differently. The addon needs a frame finder module:

#### Supported addons (in priority order):
1. Blizzard Default — CompactRaidFrameContainer children, match by unit
2. ElvUI — ElvUF_ prefixed frames, match by unit attribute
3. Cell — Cell.unitButtons or Cell's frame API
4. VuhDo — Vd1H prefixed frames
5. Fallback — EnumerateFrames() scan for frames with matching unit

#### Glow implementation:
- Use LibCustomGlow or ActionButton_ShowOverlayGlow
- Glow color should be distinct and visible (bright yellow or addon-themed)
- Glow must be visible ON TOP of the raid frame regardless of addon
- Consider adding the player's name as text overlay on the glow for
  absolute clarity

#### Frame detection timing:
- Raid frames may not exist when the addon loads
- Must re-detect frames when raid roster changes
- Cache frame references but invalidate on GROUP_ROSTER_UPDATE

### Slash Commands
- /kv or /kitnvanguard — main command router
- /kv help — show command list
- /kv config — open config (GUI, stretch goal)
- /kv import <string> — import priority list from string
- /kv export — export current priority list as string
- /kv healer <1-5> — set which healer number you are
- /kv priority — print current priority list
- /kv test — simulate 8 random debuffs and show assignment
- /kv status — show current config and addon state
- /kv diag — full diagnostics

### Import/Export String Format
- Base64-encoded comma-separated player names in priority order
- Or a simpler format: pipe-delimited names
- Example: "Tankname|Healername|Meleename|..."
- Must be copy-pasteable in Discord without formatting issues
- Include a version prefix for future format changes

## 12.0 API Compliance

### Safe to use (verified):
- UNIT_AURA event — still fires in 12.0
- C_UnitAuras.GetAuraDataByIndex() — aura spell ID fields should be
  accessible for friendly player debuffs (need to verify in-game)
- UnitName("raidN") — player names are NOT secret (only creature names)
- Unit tokens (raid1-raid20) — always accessible
- CompactRaidFrameContainer — Blizzard frames still work normally

### Must be careful with:
- AuraData fields — some may be conditionally secret. Use issecretvalue()
  guard on any field before operating on it
- Duration/expiration times — may be secret in combat. For MVP we only
  need the boolean "has debuff or not", not the remaining duration
- Do NOT use COMBAT_LOG_EVENT_UNFILTERED — it is removed in 12.0

### Hard no:
- SendAddonMessage inside the instance — blocked
- Any math/comparison on potentially secret values
- string.format on potentially secret strings

## MVP Scope (build this first)
1. Slash command system (/kv import, /kv healer, /kv test)
2. Priority list storage in SavedVariables
3. Import/export as simple pipe-delimited string
4. UNIT_AURA debuff detection for spell ID 1246502
5. Deterministic priority sorting and healer assignment
6. Blizzard default raid frame glow (one addon first)
7. /kv test command to simulate and verify assignments

## Stretch Goals (after MVP works)
1. ElvUI frame detection and glow
2. Cell frame detection and glow
3. VuhDo frame detection and glow
4. GUI configuration panel (AceConfig)
5. Reassignment after first dispel wave (for empowered casts)
6. Sound alert when your target gets debuffed
7. Standalone alert frame as backup visual
8. Support for 6th healer (configurable healer count)

## Technical Details
- Author: Kitn (GitHub: Bmwascher)
- Interface: 120001
- SavedVariables: KitnVanguardDB
- No external library dependencies for MVP (no Ace3 required)
- Use LibCustomGlow if needed (embeddable, lightweight)
- Spell ID for Avenger's Shield debuff: 1246502
- Encounter: Lightblinded Vanguard (The Voidspire, Midnight Season 1)
