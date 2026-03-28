local _, ns = ...

local LGF = LibStub("LibGetFrame-1.0")
local LCG = LibStub("LibCustomGlow-1.0")

local GlowManager = {}
ns.GlowManager = GlowManager

local GLOW_KEY = "KitnVanguard"
local activeGlowFrames = {} -- set of frames currently glowing

-- Resolve a player name to a unit token by scanning raid/party members
local function findUnitByName(playerName)
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then
        return nil
    end

    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and numMembers or (numMembers - 1)

    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) then
            local name = UnitName(unit)
            if name and not issecretvalue(name) and name == playerName then
                return unit
            end
        end
    end

    -- Check player in party mode
    if not IsInRaid() then
        local name = UnitName("player")
        if name and not issecretvalue(name) and name == playerName then
            return "player"
        end
    end

    return nil
end

--- Apply a PixelGlow to a raid frame.
function GlowManager:ApplyGlow(frame)
    if activeGlowFrames[frame] then
        return
    end
    local color = ns.db and ns.db.glowColor or { r = 1, g = 0.8, b = 0, a = 1 }
    -- PixelGlow_Start(frame, color, N, frequency, length, thickness, xOff, yOff, border, key)
    LCG.PixelGlow_Start(frame, { color.r, color.g, color.b, color.a },
        8, 0.25, nil, 2, 0, 0, true, GLOW_KEY)
    activeGlowFrames[frame] = true
end

--- Remove all active glows.
function GlowManager:RemoveAllGlows()
    for frame in pairs(activeGlowFrames) do
        LCG.PixelGlow_Stop(frame, GLOW_KEY)
    end
    wipe(activeGlowFrames)
end

--- Callback handler for DebuffDetector assignment changes.
function GlowManager:OnAssignmentChanged(assignedTarget)
    self:RemoveAllGlows()

    if not assignedTarget then
        return
    end

    local unitToken = findUnitByName(assignedTarget)
    if not unitToken then
        return
    end

    local frame = LGF.GetUnitFrame(unitToken)
    if frame then
        self:ApplyGlow(frame)
    end
end

function GlowManager:Initialize()
    ns.DebuffDetector:RegisterCallback(function(assignedTarget)
        GlowManager:OnAssignmentChanged(assignedTarget)
    end)
end
