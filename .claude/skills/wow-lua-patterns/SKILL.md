---
name: wow-lua-patterns
description: >
  WoW addon Lua code patterns including event handling, frame creation,
  secure templates, SavedVariables, slash commands, AceAddon integration,
  and common addon architecture patterns. Use when writing or modifying
  WoW addon Lua code, creating new modules, registering events, building
  UI frames, or debugging WoW-specific issues.
  Triggers: lua, addon, frame, event, slash command, SavedVariables, toc,
  Ace3, AceDB, AceConsole, AceConfig, AceGUI, CreateFrame, OnEvent,
  PLAYER_LOGIN, ADDON_LOADED, module, embed, mixin, template.
---

# WoW Addon Lua Patterns

## Addon Initialization (without Ace3)

```lua
local ADDON_NAME, ns = ...  -- ns is the private addon namespace table

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            -- Initialize SavedVariables here
            KitnTestDB = KitnTestDB or {}
            if KitnTestDB.enabled == nil then KitnTestDB.enabled = true end
            if KitnTestDB.scale == nil then KitnTestDB.scale = 1.0 end
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Safe to use most APIs here, player is fully loaded
        ns:InitializeUI()
        ns:RegisterSlashCommands()
    end
end)
```

## Addon Initialization (with Ace3)

```lua
local MyAddon = LibStub("AceAddon-3.0"):NewAddon("KitnTest",
    "AceConsole-3.0", "AceEvent-3.0")

local defaults = {
    profile = {
        enabled = true,
        scale = 1.0,
    }
}

function MyAddon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("KitnTestDB", defaults, true)
end

function MyAddon:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function MyAddon:OnDisable()
    -- Unregister events, stop timers, hide frames
end
```

## Slash Command Router

```lua
local Commands = {}

SLASH_KITNTEST1, SLASH_KITNTEST2 = "/kitntest", "/kt"
function SlashCmdList.KITNTEST(msg, editbox)
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "help" then
        Commands["help"]()
    elseif Commands[cmd] then
        Commands[cmd](rest)
    else
        print("|cffff6060KitnTest:|r Unknown command: " .. cmd)
        print("|cffff6060KitnTest:|r Type /kitntest help for a list of commands")
    end
end

Commands["help"] = function()
    print("|cff00ccff=== KitnTest Commands ===|r")
    print("|cffaaaaaa  /kitntest config|r -- Open settings")
    print("|cffaaaaaa  /kitntest status|r -- Show addon status")
    print("|cffaaaaaa  /kitntest diag|r -- Diagnostics")
end

Commands["status"] = function()
    UpdateAddOnMemoryUsage()
    local mem = GetAddOnMemoryUsage("KitnTest")
    print(format("|cff00ccffKitnTest:|r Memory: %.1f KB", mem))
end
```

## Safe CVar Toggle Pattern

```lua
local function ToggleCVar(cvar, label)
    local current = GetCVar(cvar)
    if current == nil then
        print("|cffff6060KitnTest:|r CVar " .. cvar .. " not found")
        return
    end
    local newVal = current == "1" and "0" or "1"
    SetCVar(cvar, newVal)
    print("|cff00ccffKitnTest:|r " .. label .. " " ..
        (newVal == "1" and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
end
```

## Frame Creation with Backdrop

```lua
local f = CreateFrame("Frame", "KitnTestMainFrame", UIParent, "BackdropTemplate")
f:SetSize(300, 200)
f:SetPoint("CENTER")
f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
f:SetBackdropColor(0, 0, 0, 0.8)
f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
```

## Combat Lockdown Guard

```lua
local function SafeFrameOperation(frame, operation)
    if InCombatLockdown() then
        -- Queue the operation for when combat ends
        local queueFrame = CreateFrame("Frame")
        queueFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        queueFrame:SetScript("OnEvent", function(self)
            operation(frame)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end)
        return false
    end
    operation(frame)
    return true
end

-- Usage:
SafeFrameOperation(mySecureFrame, function(f)
    f:Show()
    f:SetPoint("CENTER")
end)
```

## TOC File Template

```
## Interface: 120001
## Title: KitnTest
## Notes: Test addon for validating Claude Code development playbook
## Author: Kitn
## Version: @project-version@
## SavedVariables: KitnTestDB
## IconTexture: Interface\Icons\INV_Misc_QuestionMark
## X-Website: https://github.com/Bmwascher/KitnTest

# Core addon files
Core.lua
Modules\SlashCommands.lua
```

## In-Game Diagnostic Command

Add this to every addon for quick debugging feedback:

```lua
Commands["diag"] = function()
    print("|cff00ccff=== KitnTest Diagnostics ===|r")
    local version = C_AddOns.GetAddOnMetadata("KitnTest", "Version") or "unknown"
    print("  Version: " .. version)
    UpdateAddOnMemoryUsage()
    print(format("  Memory: %.1f KB", GetAddOnMemoryUsage("KitnTest")))
    print("  Combat: " .. (InCombatLockdown() and "|cffff0000YES|r" or "|cff00ff00No|r"))
    local count = 0
    for _ in pairs(Commands) do count = count + 1 end
    print("  Commands registered: " .. count)
end
```
