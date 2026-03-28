local _, ns = ...

local FrameFinder = {}
ns.FrameFinder = FrameFinder

local frameCache = {}    -- unitToken -> frame reference
local cacheValid = false

-- Find the Blizzard CompactRaidFrame for a given unit token
local function findBlizzardFrame(unitToken)
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if not frame then
            break
        end
        -- Compare unit tokens directly (strings, never secret) instead of
        -- UnitIsUnit() which returns secret inside instances
        if frame:IsVisible() and frame.unit and frame.unit == unitToken then
            return frame
        end
    end
    return nil
end

--- Find the raid frame for a unit token (cached).
function FrameFinder:FindFrame(unitToken)
    if cacheValid and frameCache[unitToken] then
        local cached = frameCache[unitToken]
        -- Validate cache: direct string compare avoids secret UnitIsUnit return
        if cached:IsVisible() and cached.unit and cached.unit == unitToken then
            return cached
        end
        frameCache[unitToken] = nil
    end

    local frame = findBlizzardFrame(unitToken)
    if frame then
        frameCache[unitToken] = frame
        cacheValid = true
    end
    return frame
end

--- Find the raid frame for a player name by scanning raid/party unit tokens.
--- Returns: frame (or nil), unitToken (or nil)
function FrameFinder:FindFrameByName(playerName)
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then
        return nil, nil
    end

    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and numMembers or (numMembers - 1)

    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) then
            local name = UnitName(unit)
            if name and not issecretvalue(name) and name == playerName then
                return self:FindFrame(unit), unit
            end
        end
    end

    -- Check player in party mode
    if not IsInRaid() then
        local name = UnitName("player")
        if name and not issecretvalue(name) and name == playerName then
            return self:FindFrame("player"), "player"
        end
    end

    return nil, nil
end

--- Invalidate the frame cache (called on roster changes).
function FrameFinder:InvalidateCache()
    wipe(frameCache)
    cacheValid = false
end

-- Event handler for roster changes
local eventFrame = CreateFrame("Frame")

function FrameFinder:Initialize()
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:SetScript("OnEvent", function()
        FrameFinder:InvalidateCache()
    end)
end

--- Return the name of the detected raid frame addon (for diagnostics).
function FrameFinder:GetDetectedAddon()
    return "Blizzard"
end
