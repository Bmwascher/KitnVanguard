local ADDON_NAME, ns = ...

-- Constants
ns.ADDON_NAME = ADDON_NAME
ns.SPELL_ID = 1246502 -- Avenger's Shield debuff
ns.MAX_HEALERS = 5

-- Print helpers
function ns:Print(msg)
    print("|cff00ccffKitnVanguard:|r " .. msg)
end

function ns:PrintError(msg)
    print("|cffff6060KitnVanguard:|r " .. msg)
end

-- SavedVariables defaults
local defaults = {
    priorityList = {},
    healerNumber = 0,
    enabled = true,
    glowColor = { r = 1, g = 0.8, b = 0, a = 1 },
}

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            -- Initialize SavedVariables with defaults
            KitnVanguardDB = KitnVanguardDB or {}
            for key, value in pairs(defaults) do
                if KitnVanguardDB[key] == nil then
                    if type(value) == "table" then
                        KitnVanguardDB[key] = CopyTable(value)
                    else
                        KitnVanguardDB[key] = value
                    end
                end
            end
            ns.db = KitnVanguardDB
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Initialize modules
        if ns.DebuffDetector then
            ns.DebuffDetector:Initialize()
        end
        if ns.FrameFinder then
            ns.FrameFinder:Initialize()
        end
        if ns.GlowManager then
            ns.GlowManager:Initialize()
        end
        if ns.SlashCommands then
            ns.SlashCommands:Initialize()
        end

        local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
        ns:Print("v" .. version .. " loaded. Type /kv help for commands.")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
