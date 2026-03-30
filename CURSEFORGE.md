<!-- CurseForge-compatible version of README.md (simplified markdown, no backticks/tables) -->

# KitnVanguard

Dispel assignment coordinator for the **Lightblinded Vanguard** encounter (Mythic, The Voidspire) in World of Warcraft 12.0 Midnight.

## What It Does

When **Avenger's Shield** hits 8 (or all 20) raid members with a dispellable magic debuff, KitnVanguard automatically assigns each healer a specific target to dispel. Every healer running the addon independently computes the same assignments — no addon communication needed during combat.

*   Detects harmful dispellable auras during the encounter
*   Assigns healers to targets using a priority-sorted list
*   Glows the assigned target's raid frame
*   Shows a center-screen text alert with class icon and character name
*   Plays a sound notification

## Quick Start

1.  **Install** the addon
2.  **Join your raid** — no configuration needed for healers
3.  **Raid leader runs** /kv scan to build the priority list
4.  **Ready check** automatically syncs the priority list to all KitnVanguard users
5.  **Pull Lightblinded Vanguard** — assignments appear automatically when Avenger's Shield lands

That's it. Healers don't need to configure anything.

## How It Works

All healer clients independently reach the same dispel assignment using deterministic sorting:

1.  Encounter start builds a healer list sorted by raid index
2.  Aura detection collects harmful dispellable auras in a 0.2s window
3.  Debuffed players are sorted by priority (role, class, raid index — dwarves last)
4.  **Two-pass assignment** — healers who are debuffed self-dispel first, then remaining healers get the next priority targets
5.  Each healer sees their assigned target glowed and announced

## Features

**Auto-detection** — Healer position detected automatically from raid roster

**Priority scan** — Configurable role order and class order for dispel priority

**Raid frame glow** — LibCustomGlow with 4 glow types (Pixel, Button, AutoCast, Proc)

**Text alert** — Center-screen display with class icon and configurable position, font, and color

**Sound alert** — LibSharedMedia-powered sound selection with channel control

**Sync system** — AceComm broadcast on ready check and pull timer

**Dwarf handling** — Dwarves and Dark Iron deprioritized (can Stoneform self-cleanse)

**Warlock support** — Optional backup dispellers via Imp Singe Magic

**Reassign toggle** — Glow follows next target after dispel, or stays until wave ends

**Cross-realm** — Full Name-Realm support

**Reconnect safe** — Detects active encounters on reconnect

## Commands

*   **/kv config** — Open settings GUI
*   **/kv scan** — Build priority list from raid roster
*   **/kv sync** — Sync priority list to raid (leader/assist)
*   **/kv who** — Show who has KitnVanguard installed
*   **/kv status** — Show addon status
*   **/kv clear** — Clear glow overlays
*   **/kv help** — Show all commands

## Configuration

Open settings with /kv config or the minimap button. Four tabs:

*   **General** — Priority list, scan button, dispel behavior, advanced settings
*   **Scan Priority** — Customize role order and class order for the priority scan
*   **Raid Frame Glow** — Glow type, color, animation settings
*   **Text Alert** — Alert text, font, color, position, sound

## Why KitnVanguard?

If you've been using the **M33kAuras / NorthernSky Assignment WeakAura** for Vanguard dispel assignments, KitnVanguard is a standalone addon replacement that does the same thing with a simpler experience:

*   **No WeakAura import required** — install the addon and go
*   **Built-in GUI** — configure everything logically and visually instead of editing WA code
*   **Auto-sync on ready check** — priority list shared to all healers automatically
*   **Same proven detection logic** — based on the same UNIT_AURA + collection window pattern
*   **Smarter priority system** — the WA sorts purely by raid index. KitnVanguard lets you control dispel priority at three levels:
    *   **Role-based** — Choose which roles get dispelled first (default: Healers > DPS > Tanks)
    *   **Class-based** — Within each role, prioritize squishier classes (default: cloth > mail > leather > plate)
    *   **Individual player** — Fine-tune the final list with per-player reordering via the GUI

**Important:** All healers in your raid should use the **same** dispel assignment system — either all on KitnVanguard or all on the M33kAuras WeakAura. Mixing both will cause conflicting assignments because the two systems use different priority sort orders. If you're switching to KitnVanguard, make sure all healers disable the WA dispel assignment first.

## Credits

*   **Reloe** — Dispel assignment WeakAura code used as reference for the detection and assignment logic
*   **NorthernSkyRaidTools** — Communication and sync patterns referenced for the AceComm implementation

## Author

**Bitebtw** (GitHub: Bmwascher)
