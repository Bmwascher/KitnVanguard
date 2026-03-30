local ADDON_NAME, ns = ...

-- Constants
ns.ADDON_NAME = ADDON_NAME
ns.MAX_HEALERS = 5

-- Tracked debuff spell IDs (add/remove IDs here)
ns.SPELL_IDS = {
    1246502, -- Avenger's Shield
    1255979, -- Dread Breath
}
-- Build a fast lookup set: ns.TRACKED_SPELLS[spellId] == true
ns.TRACKED_SPELLS = {}
for _, id in ipairs(ns.SPELL_IDS) do
    ns.TRACKED_SPELLS[id] = true
end

-- Print helpers
function ns:Print(msg)
    print("|cff00ccffKitnVanguard:|r " .. msg)
end

function ns:PrintError(msg)
    print("|cffff6060KitnVanguard:|r " .. msg)
end

-- Debug mode (session-only, not persisted across /reload)
ns.debugMode = false

--- Get full player name including realm for cross-realm players.
--- Returns "Name-Server" for cross-realm, "Name" for same-realm, or nil.
function ns:GetFullUnitName(unit)
    local name, realm = UnitName(unit)
    if not name or issecretvalue(name) then
        return nil
    end
    if realm and realm ~= "" and not issecretvalue(realm) then
        name = name .. "-" .. realm
    end
    return name
end

-- Class info lookup (avoids GetClassInfo calls at GUI build time)
ns.CLASS_INFO = {
    [1]  = { file = "WARRIOR",      name = "Warrior" },
    [2]  = { file = "PALADIN",      name = "Paladin" },
    [3]  = { file = "HUNTER",       name = "Hunter" },
    [4]  = { file = "ROGUE",        name = "Rogue" },
    [5]  = { file = "PRIEST",       name = "Priest" },
    [6]  = { file = "DEATHKNIGHT",  name = "Death Knight" },
    [7]  = { file = "SHAMAN",       name = "Shaman" },
    [8]  = { file = "MAGE",         name = "Mage" },
    [9]  = { file = "WARLOCK",      name = "Warlock" },
    [10] = { file = "MONK",         name = "Monk" },
    [11] = { file = "DRUID",        name = "Druid" },
    [12] = { file = "DEMONHUNTER",  name = "Demon Hunter" },
    [13] = { file = "EVOKER",       name = "Evoker" },
}

-- SavedVariables defaults
local defaults = {
    priorityList = {},
    healerNumber = 0,
    enabled = true,
    reassignAfterDispel = true,
    -- Glow settings (LibCustomGlow)
    glow = {
        enabled = true,
        glowType = "pixel",   -- "pixel", "button", "autocast", "proc"
        color = { r = 1, g = 0.8, b = 0, a = 1 },
        lines = 8,            -- number of lines/particles
        frequency = 0.25,     -- rotation speed (negative = reverse)
        thickness = 2,        -- line thickness (pixel glow)
        border = true,        -- solid border under lines (pixel glow)
        scale = 1,            -- particle scale (autocast glow)
    },
    includeWarlocks = true,
    -- Scan priority: role order and class order within roles
    scanRoleOrder = { "HEALER", "DAMAGER", "TANK" },
    scanClassOrder = { 8, 9, 5, 13, 7, 3, 4, 10, 11, 12, 6, 1, 2 },
    -- Alert display settings
    alert = {
        enabled = true,
        textPrefix = "Dispel:",
        fontSize = 28,
        fontOutline = "OUTLINE",
        textColor = { r = 1, g = 1, b = 1, a = 1 },
        anchorFrom = "CENTER",
        anchorTo = "CENTER",
        xOffset = 0,
        yOffset = 200,
        duration = 0, -- 0 = stay until cleared
        soundEnabled = true,
        soundFile = "RaidWarning",
        soundChannel = "Master",
    },
    minimap = { hide = false },
}

-- Recursive merge: backfills missing keys from defaults into saved data.
-- Existing user values are never overwritten. Only nil keys get the default.
local function deepMerge(saved, default)
    for key, defaultValue in pairs(default) do
        if saved[key] == nil then
            -- Key missing entirely: copy the default
            if type(defaultValue) == "table" then
                saved[key] = CopyTable(defaultValue)
            else
                saved[key] = defaultValue
            end
        elseif type(defaultValue) == "table" and type(saved[key]) == "table" then
            -- Both are tables: recurse to backfill nested keys
            deepMerge(saved[key], defaultValue)
        end
        -- If saved[key] exists and is not a table, keep the user's value
    end
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            -- Initialize SavedVariables with recursive default merge
            KitnVanguardDB = KitnVanguardDB or {}
            deepMerge(KitnVanguardDB, defaults)
            ns.db = KitnVanguardDB
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Initialize modules
        if ns.DebuffDetector then
            ns.DebuffDetector:Initialize()
        end
        if ns.GlowManager then
            ns.GlowManager:Initialize()
        end
        if ns.AlertFrame then
            ns.AlertFrame:Initialize()
        end
        if ns.Sync then
            ns.Sync:Initialize()
        end
        if ns.SlashCommands then
            ns.SlashCommands:Initialize()
        end

        -- Minimap button (LibDBIcon)
        local okLDB, LDB = pcall(LibStub, "LibDataBroker-1.1")
        local okIcon, LDBIcon = pcall(LibStub, "LibDBIcon-1.0")
        if okLDB and okIcon then
            local broker = LDB:NewDataObject("KitnVanguard", {
                type = "launcher",
                icon = "Interface\\Icons\\Spell_Holy_DispelMagic",
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        if ns.ConfigFrame then
                            ns.ConfigFrame:Toggle()
                        end
                    elseif button == "RightButton" then
                        if ns.Sync then
                            ns.Sync:PrintStatus()
                        end
                    end
                end,
                OnTooltipShow = function(tip)
                    tip:AddLine(ns:AccentText("Kitn") .. "Vanguard")
                    local count = ns.db.priorityList and #ns.db.priorityList or 0
                    tip:AddLine("Priority list: " .. count .. " players", 1, 1, 1)
                    tip:AddLine("Healers: " .. #ns.healerList, 1, 1, 1)
                    tip:AddLine(" ")
                    tip:AddLine("|cff00ff00Left-click:|r Open settings", 0.8, 0.8, 0.8)
                    tip:AddLine("|cff00ff00Right-click:|r Show addon status", 0.8, 0.8, 0.8)
                end,
            })
            LDBIcon:Register("KitnVanguard", broker, ns.db.minimap)
        end

        local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
        ns:Print("v" .. version .. " loaded. Type /kv help for commands.")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
