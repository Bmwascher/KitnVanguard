# Changelog

## [1.0.2] - 2026-04-26
### Added
- 12.0.5 (patch) interface support
- Minimap button toggle in Advanced settings (next to Addon Enabled)

## [1.0.0] - 2026-03-30
### Added
- Automated dispel assignment for Mythic raid encounters
- Detects harmful dispellable auras during boss encounters via UNIT_AURA
- Two-pass healer assignment: self-dispel priority, then sorted targets
- Dwarf/Dark Iron deprioritization (Stoneform self-cleanse)
- Warlock support as backup dispellers (Imp Singe Magic)
- Raid frame glow via LibCustomGlow (Pixel, Button, AutoCast, Proc types)
- Center-screen text alert with class icon and sound notification
- Priority list from raid scan (configurable role + class sort order)
- AceComm sync: leader broadcasts priority list on ready check / pull timer
- Addon presence detection (/kv who)
- GUI config with 4 tabs: General, Scan Priority, Raid Frame Glow, Text Alert
- Blizzard addon settings panel integration
- Minimap button (LibDBIcon)
- Cross-realm name support
- Reconnect/mid-fight join detection
- Configurable reassignment after dispel (toggle)
