---
name: wow-addon-libraries
description: >
  Reference of established WoW addon libraries that should be used instead
  of hand-rolling solutions. MUST be consulted before building: frame detection,
  glow effects, config panels, saved variables, slash commands, data broker
  plugins, media handling, unit frames, action bars, aura tracking, range
  checking, dispel detection, or any common addon subsystem.
  Triggers: library, lib, LibStub, frame detection, glow, config panel,
  options panel, saved variables, profiles, slash command, data broker,
  minimap icon, media, statusbar texture, font, sound, unit frame, oUF,
  action bar, LibActionButton, aura, range check, dispel, nameplate,
  embed, dependency, external, pkgmeta, callback, event, serialize,
  compress, localization, tooltip, dropdown, scroll, tab, AceGUI.
---

# WoW Addon Libraries — Use These Instead of Hand-Rolling

## RULE: Always check this list before building a subsystem from scratch.

If a battle-tested library exists for what you are about to build, USE IT.
Hand-rolled solutions are more fragile, harder to maintain, and will break
across WoW patches. Libraries are maintained by the community and handle
edge cases you will not anticipate.

---

## How to Embed Libraries

### In .toc (load order matters — libraries load FIRST):
```
# Libraries
Libs\LibStub\LibStub.lua
Libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
Libs\LibGetFrame-1.0\LibGetFrame-1.0.lua
```

### In .pkgmeta (auto-pulled during release builds):
```yaml
externals:
  Libs/LibStub:
    url: https://repos.wowace.com/wow/libstub/trunk
    tag: latest
  Libs/LibGetFrame-1.0:
    url: https://github.com/mrbuds/LibGetFrame
```

### For local development:
Clone libraries into Libs/ manually and remove their .git folders:
```
cd Libs
git clone https://github.com/author/LibName.git LibName-1.0
Remove-Item LibName-1.0\.git -Recurse -Force
```

### In .luacheckrc:
Add "LibStub" and any library globals to read_globals.

---

## Foundation Libraries (almost every addon needs these)

### LibStub
**What:** Library versioning and loading system. The standard way to load libraries.
**Use instead of:** Manual version checking or global namespace registration.
**Source:** https://repos.wowace.com/wow/libstub/trunk
**Usage:**
```lua
local LGF = LibStub("LibGetFrame-1.0")
local LCG = LibStub("LibCustomGlow-1.0")
```

### CallbackHandler-1.0
**What:** Event/callback system for libraries to fire custom events.
**Use instead of:** Hand-rolled callback tables or observer patterns.
**Source:** https://repos.wowace.com/wow/callbackhandler/trunk/CallbackHandler-1.0
**Note:** Required dependency for many libraries. Usually bundled with them.

---

## Frame Detection and Glows

### LibGetFrame-1.0
**What:** Finds unit frames from ANY raid frame addon — Blizzard, ElvUI, Cell,
VuhDo, Danders, Grid2, Healbot, and 20+ others. Auto-detects which addon
is active.
**Use instead of:** Hand-coded frame detection for specific addons.
**Source:** https://github.com/mrbuds/LibGetFrame
**Key APIs:**
```lua
local LGF = LibStub("LibGetFrame-1.0")
local frame = LGF.GetUnitFrame("raid5")          -- Find frame for unit
local frame = LGF.GetUnitFrame("raid5", {        -- With options
    ignorePlayerFrame = true,
    ignoreTargetFrame = true,
    returnAll = false,
})
-- Callback when frames change
LGF.RegisterCallback("MyAddon", "FRAME_UNIT_UPDATE", function(event, frame, unit)
    -- Frame was created or unit changed
end)
LGF.RegisterCallback("MyAddon", "FRAME_UNIT_REMOVED", function(event, frame, unit)
    -- Frame was removed
end)
```
**Supports:** CompactRaidFrame, ElvUI (oUF-based), Cell, VuhDo, Grid2, Healbot,
Shadowed Unit Frames, Pitbull, Danders, and many more.

### LibCustomGlow-1.0
**What:** Adds glow effects to any frame. Multiple glow styles available.
**Use instead of:** Manual overlay textures, animation groups, or border effects.
**Source:** https://github.com/Stanzilla/LibCustomGlow
**Key APIs:**
```lua
local LCG = LibStub("LibCustomGlow-1.0")

-- Pixel glow (rotating dashed border)
LCG.PixelGlow_Start(frame, {0.95, 0.95, 0.32, 1}, 8, 0.25, nil, nil, 0, 0, false, "MyAddonKey")
LCG.PixelGlow_Stop(frame, "MyAddonKey")

-- Button glow (Blizzard proc-style glow)
LCG.ButtonGlow_Start(frame, {1, 1, 0, 1}, 0.125)
LCG.ButtonGlow_Stop(frame)

-- Autocast glow (spinning sparkles)
LCG.AutoCastGlow_Start(frame, {0.95, 0.95, 0.32, 1}, 4, 0.125)
LCG.AutoCastGlow_Stop(frame)

-- Proc glow (retail spell activation overlay)
LCG.ProcGlow_Start(frame, {color = {0.95, 0.95, 0.32, 1}})
LCG.ProcGlow_Stop(frame)
```
**Tip:** Always use a unique key string (your addon name) with PixelGlow to
prevent conflicts with other addons' glows on the same frame.
**Note:** Add Masque to OptionalDeps in .toc for skinning compatibility.

---

## Ace3 Framework (config, saved variables, slash commands)

### AceAddon-3.0
**What:** Addon lifecycle framework with module support.
**Use instead of:** Manual ADDON_LOADED/PLAYER_LOGIN event handling.
**When to use:** When your addon has multiple modules that need coordinated init/enable/disable.
**When to skip:** Simple single-file addons — raw event handling is fine.

### AceDB-3.0
**What:** Saved variables with profile support (per-character, per-class, per-spec, default).
**Use instead of:** Manual SavedVariables initialization and defaults merging.
**Usage:**
```lua
local defaults = { profile = { enabled = true, scale = 1.0 } }
function MyAddon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MyAddonDB", defaults, true)
    -- self.db.profile.enabled is now available with defaults applied
end
```

### AceConfig-3.0 + AceConfigDialog-3.0
**What:** Options table system that auto-generates config panels.
**Use instead of:** Hand-coded config frames with manual widget layout.
**Usage:**
```lua
local options = {
    type = "group",
    args = {
        enabled = {
            type = "toggle", name = "Enable", order = 1,
            get = function() return db.profile.enabled end,
            set = function(_, v) db.profile.enabled = v end,
        },
    },
}
LibStub("AceConfig-3.0"):RegisterOptionsTable("MyAddon", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MyAddon", "MyAddon")
```

### AceDBOptions-3.0
**What:** Auto-generates a profile management panel for AceDB. Gives users
copy/delete/reset profile controls with zero UI code from you.
**Use instead of:** Building your own profile selection dropdown.
**Pairs with:** AceDB-3.0 (required) and AceConfigDialog-3.0 (to display it).
**Usage:**
```lua
local profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
LibStub("AceConfig-3.0"):RegisterOptionsTable("MyAddonProfiles", profileOptions)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MyAddonProfiles", "Profiles", "MyAddon")
```

### AceGUI-3.0
**What:** Widget toolkit that AceConfigDialog uses under the hood. Provides
buttons, dropdowns, sliders, editboxes, tabs, scroll frames, and more.
**Use instead of:** Manual CreateFrame widget building for config UIs.
**When to use directly:** When AceConfig's declarative options table is too
limiting and you need a fully custom layout with specific widget placement.
**When to skip:** If AceConfig-3.0 options tables give you enough control.
**Source:** Part of Ace3.
**Usage:**
```lua
local AceGUI = LibStub("AceGUI-3.0")
local frame = AceGUI:Create("Frame")
frame:SetTitle("My Custom Panel")
local btn = AceGUI:Create("Button")
btn:SetText("Click Me")
btn:SetCallback("OnClick", function() print("Clicked!") end)
frame:AddChild(btn)
```

### AceConsole-3.0
**What:** Slash command registration and chat output helpers.
**Use instead of:** Manual SLASH_MYADDON1 / SlashCmdList registration.
**When to skip:** If you already have a clean slash command router, no need to add Ace3 just for this.

### AceEvent-3.0
**What:** Event registration mixin with auto-unregister on disable.
**Use instead of:** Manual frame:RegisterEvent / UnregisterEvent.
**Usage:**
```lua
function MyAddon:OnEnable()
    self:RegisterEvent("UNIT_AURA")
end
function MyAddon:UNIT_AURA(event, unit, info)
    -- Handle event
end
```

### AceTimer-3.0
**What:** Repeating and one-shot timer management with auto-cancel on disable.
**Use instead of:** Manual C_Timer management with tracking tables.

### AceComm-3.0
**What:** Addon communication with automatic message chunking for long messages.
**WARNING 12.0:** SendAddonMessage is BLOCKED inside instances. AceComm will
fail silently inside dungeons and raids. Only usable in open world / cities.

### AceSerializer-3.0
**What:** Serialize Lua tables to strings for transmission or storage.
**Use instead of:** Manual table-to-string conversion.
**Pairs with:** AceComm for sending tables between clients, or for import/export strings.

**Ace3 source for .pkgmeta:**
```yaml
externals:
  Libs/AceAddon-3.0:
    url: https://repos.wowace.com/wow/ace3/trunk/AceAddon-3.0
  Libs/AceDB-3.0:
    url: https://repos.wowace.com/wow/ace3/trunk/AceDB-3.0
  Libs/AceDBOptions-3.0:
    url: https://repos.wowace.com/wow/ace3/trunk/AceDBOptions-3.0
  Libs/AceConfig-3.0:
    url: https://repos.wowace.com/wow/ace3/trunk/AceConfig-3.0
  Libs/AceConfigDialog-3.0:
    url: https://repos.wowace.com/wow/ace3/trunk/AceConfigDialog-3.0
  Libs/AceConsole-3.0:
    url: https://repos.wowace.com/wow/ace3/trunk/AceConsole-3.0
  Libs/AceEvent-3.0:
    url: https://repos.wowace.com/wow/ace3/trunk/AceEvent-3.0
  Libs/AceGUI-3.0:
    url: https://repos.wowace.com/wow/ace3/trunk/AceGUI-3.0
  Libs/AceGUI-3.0-SharedMediaWidgets:
    url: https://repos.wowace.com/wow/ace-gui-3-0-shared-media-widgets/trunk
```

---

## UI and Media

### LibSharedMedia-3.0
**What:** Shared registry for fonts, statusbar textures, sounds, and borders.
**Use instead of:** Hardcoding texture paths. Lets users pick from all installed media.
**Source:** https://repos.wowace.com/wow/libsharedmedia-3-0/trunk/LibSharedMedia-3.0
**Usage:**
```lua
local LSM = LibStub("LibSharedMedia-3.0")
local texture = LSM:Fetch("statusbar", "Smooth")
myBar:SetStatusBarTexture(texture)
```

### LibDataBroker-1.1
**What:** Standard data display protocol — your addon publishes data, broker
display addons (ChocolateBar, Bazooka, TitanPanel) show it.
**Use instead of:** Custom minimap buttons or info panels.
**Source:** https://github.com/tekkub/libdatabroker-1-1

### LibDBIcon-1.0
**What:** Creates a minimap icon for your addon using LibDataBroker.
**Use instead of:** Manual minimap button creation and dragging math.
**Source:** https://repos.wowace.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0

### AceGUI-3.0-SharedMediaWidgets
**What:** Adds LibSharedMedia dropdown widgets to AceGUI/AceConfig panels.
Lets users pick fonts, statusbar textures, sounds, and borders from a
visual dropdown showing all installed media.
**Use instead of:** Plain text input fields for media names.
**Pairs with:** LibSharedMedia-3.0 (required), AceGUI-3.0, AceConfig-3.0.
**Source:** https://repos.wowace.com/wow/ace-gui-3-0-shared-media-widgets/trunk
**Usage:** Just embed it — AceConfig automatically uses the widgets when your
options table has a `dialogControl = "LSM30_Statusbar"` field:
```lua
barTexture = {
    type = "select", name = "Bar Texture",
    dialogControl = "LSM30_Statusbar",
    values = LSM:HashTable("statusbar"),
    get = function() return db.profile.barTexture end,
    set = function(_, v) db.profile.barTexture = v end,
}
```

### LibSimpleSticky
**What:** Frame snapping and docking. Makes frames snap to screen edges and
to each other when dragged near them, like Edit Mode behavior.
**Use instead of:** Manual snap-to-edge math in OnDragStop scripts.
**Source:** https://repos.wowace.com/wow/libsimplesticky/trunk
**Usage:**
```lua
local LSS = LibStub("LibSimpleSticky-1.0")
frame:SetScript("OnDragStop", function(self)
    LSS:StopMoving(self, 10)  -- 10px snap distance
end)
```

---

## Combat and Unit Data

### LibDispel
**What:** Detects which debuff types the current player can dispel based on
class and spec.
**Use instead of:** Hard-coded class/spec dispel capability tables.
**Usage:**
```lua
local LD = LibStub("LibDispel")
if LD:CanDispel("Magic") then
    -- Current character can dispel magic debuffs
end
```

### oUF (oUF Unit Frames)
**What:** Full unit frame framework. Handles all unit data, events, and display.
**Use instead of:** Building unit frames from scratch with raw CreateFrame.
**When to use:** If you are building a complete unit frame replacement.
**When to skip:** If you just need to detect or glow existing frames (use LibGetFrame).
**Source:** https://github.com/oUF-wow/oUF
**Note:** ElvUI's unit frames are built on oUF.

### oUF Plugins
**What:** Collection of extension elements for oUF unit frames — adds support
for specific display features like absorb bars, heal prediction, raid role
icons, combat indicators, threat display, and more.
**Use instead of:** Writing custom oUF elements from scratch.
**When to use:** Only if you are building unit frames with oUF and need
specific display features that oUF doesn't include by default.
**Source:** Bundled with many oUF layouts; individual plugins on CurseForge/GitHub.
**Note:** Each plugin registers as an oUF element via `oUF:AddElement()`.

### LibElvUIPlugin-1.0
**What:** Registers your addon as an official ElvUI plugin. Adds your addon
to ElvUI's plugin list, enables version checking between ElvUI plugin users,
and integrates your config into ElvUI's options panel.
**Use instead of:** Manually hooking into ElvUI's config system.
**When to use:** ONLY when building an addon that extends ElvUI specifically.
Not needed for addons that merely coexist with ElvUI.
**Source:** Bundled with ElvUI (Libs/LibElvUIPlugin-1.0)
**Usage:**
```lua
local EP = LibStub("LibElvUIPlugin-1.0")
local E = unpack(ElvUI)
EP:RegisterPlugin("MyElvUIPlugin", function()
    -- Insert your options into ElvUI's config panel
    E.Options.args.MyPlugin = { type = "group", name = "My Plugin", args = {} }
end)
```

### LibRangeCheck-3.0
**What:** Estimates range to units using spell and item range checks.
**Use instead of:** Manual IsSpellInRange / IsItemInRange logic per class.
**Source:** https://github.com/WeakAuras/LibRangeCheck-3.0

---

## Data Handling

### LibDeflate
**What:** Compression and decompression for addon data.
**Use instead of:** Sending uncompressed data via AceComm.
**Source:** https://github.com/SafeteeWoW/LibDeflate

### LibSerialize
**What:** Fast serialization of Lua values to binary strings.
**Use instead of:** AceSerializer when performance matters.
**Source:** https://github.com/rossnichols/LibSerialize

### TaintLess
**What:** Fixes taint issues in Blizzard's default UI code.
**Use instead of:** Nothing — just embed it if your addon modifies any Blizzard frames.
**Source:** https://www.townlong-yak.com/addons/taintless
**Note:** Embed as optional dependency. Helps prevent taint errors.

---

## Localization

### LibTranslit-1.0
**What:** Transliterates Cyrillic characters to Latin for name matching.
**When to use:** If your addon matches player names and your server has
Russian-language players.

### AceLocale-3.0
**What:** Localization framework for translating addon strings.
**Use instead of:** Hardcoded English strings throughout your code.
**Source:** Part of Ace3.

---

## Decision Guide

| You need to... | Use this library |
|----------------|-----------------|
| Find a player's raid frame | LibGetFrame-1.0 |
| Add a glow to a frame | LibCustomGlow-1.0 |
| Build a config panel | AceConfig-3.0 + AceConfigDialog-3.0 |
| Build a fully custom config layout | AceGUI-3.0 directly |
| Add profile management UI | AceDBOptions-3.0 |
| Manage saved variables with profiles | AceDB-3.0 |
| Register slash commands | AceConsole-3.0 (or hand-roll if simple) |
| Handle events with auto-cleanup | AceEvent-3.0 |
| Manage timers | AceTimer-3.0 |
| Send data between addon clients | AceComm-3.0 (open world only in 12.0!) |
| Serialize tables to strings | AceSerializer-3.0 or LibSerialize |
| Compress data | LibDeflate |
| Create a minimap icon | LibDBIcon-1.0 + LibDataBroker-1.1 |
| Let users pick fonts/textures | LibSharedMedia-3.0 |
| Add media picker dropdowns to config | AceGUI-3.0-SharedMediaWidgets |
| Make frames snap to edges/each other | LibSimpleSticky |
| Build custom unit frames | oUF |
| Extend oUF with extra elements | oUF Plugins |
| Build an ElvUI plugin addon | LibElvUIPlugin-1.0 |
| Check spell range to a unit | LibRangeCheck-3.0 |
| Detect dispel capability | LibDispel |
| Fix Blizzard taint issues | TaintLess |
| Glow + frame finding together | LibGetFrame-1.0 + LibCustomGlow-1.0 |

---

## Anti-Patterns (things to NEVER hand-roll)

1. Frame detection across raid addons — ALWAYS use LibGetFrame
2. Glow/highlight effects — ALWAYS use LibCustomGlow
3. Config panel UI — ALWAYS use AceConfig unless you need a truly custom layout
4. SavedVariables profile management — ALWAYS use AceDB
5. Minimap icon creation — ALWAYS use LibDBIcon
6. Addon-to-addon communication — ALWAYS use AceComm (with 12.0 instance caveat)
