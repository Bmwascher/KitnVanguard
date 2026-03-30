local _, ns = ...

local ok1, LGF = pcall(LibStub, "LibGetFrame-1.0")
local ok2, LCG = pcall(LibStub, "LibCustomGlow-1.0")
if not ok1 or not ok2 then
    print("|cffff6060KitnVanguard:|r Missing library — LibGetFrame or LibCustomGlow not found. Glow disabled.")
    return
end

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
            local name = ns:GetFullUnitName(unit)
            if name and name == playerName then
                return unit
            end
        end
    end

    -- Check player in party mode
    if not IsInRaid() then
        local name = ns:GetFullUnitName("player")
        if name and name == playerName then
            return "player"
        end
    end

    return nil
end

--- Apply glow to a raid frame using configured type and settings.
function GlowManager:ApplyGlow(frame)
    if activeGlowFrames[frame] then
        return
    end

    local db = ns.db.glow
    if not db or not db.enabled then
        return
    end

    local c = db.color or { r = 1, g = 0.8, b = 0, a = 1 }
    local color = { c.r, c.g, c.b, c.a or 1 }
    local glowType = db.glowType or "pixel"

    if glowType == "pixel" then
        -- PixelGlow_Start(frame, color, N, frequency, length, thickness, xOff, yOff, border, key)
        LCG.PixelGlow_Start(frame, color,
            db.lines or 8,
            db.frequency or 0.25,
            nil,
            db.thickness or 2,
            0, 0,
            db.border ~= false,
            GLOW_KEY)
    elseif glowType == "button" then
        -- ButtonGlow_Start(frame, color, frequency)
        LCG.ButtonGlow_Start(frame, color, db.frequency or 0.125)
    elseif glowType == "autocast" then
        -- AutoCastGlow_Start(frame, color, N, frequency, scale, xOff, yOff, key)
        LCG.AutoCastGlow_Start(frame, color,
            db.lines or 4,
            db.frequency or 0.125,
            db.scale or 1,
            0, 0,
            GLOW_KEY)
    elseif glowType == "proc" then
        -- ProcGlow_Start(frame, options)
        LCG.ProcGlow_Start(frame, {
            color = color,
            duration = 1,
            key = GLOW_KEY,
        })
    end

    activeGlowFrames[frame] = true
end

--- Remove all active glows (stops all glow types to handle type changes).
function GlowManager:RemoveAllGlows()
    for frame in pairs(activeGlowFrames) do
        LCG.PixelGlow_Stop(frame, GLOW_KEY)
        LCG.ButtonGlow_Stop(frame)
        LCG.AutoCastGlow_Stop(frame, GLOW_KEY)
        LCG.ProcGlow_Stop(frame, GLOW_KEY)
    end
    wipe(activeGlowFrames)
end

--- Callback handler for DebuffDetector assignment changes.
function GlowManager:OnAssignmentChanged(assignedTarget)
    local previousTarget = self.currentTarget
    self:RemoveAllGlows()

    if not assignedTarget then
        if previousTarget then
            ns:Print("Dispel target cleared.")
        end
        self.currentTarget = nil
        return
    end

    local unitToken = findUnitByName(assignedTarget)
    if not unitToken then
        self.currentTarget = nil
        return
    end

    local frame = LGF.GetUnitFrame(unitToken)
    if frame then
        self:ApplyGlow(frame)
    end

    if assignedTarget ~= previousTarget then
        ns:Print("Dispel -> |cffffff00" .. assignedTarget .. "|r")
    end
    self.currentTarget = assignedTarget
end

--- Glow the player's own frame for a duration (seconds). Returns true on success.
function GlowManager:TestGlow(duration)
    local db = ns.db.glow
    if not db or not db.enabled then
        return false
    end
    local frame = LGF.GetUnitFrame("player")
    if not frame then
        return false
    end
    self:RemoveAllGlows()
    self:ApplyGlow(frame)
    C_Timer.After(duration, function()
        GlowManager:RemoveAllGlows()
    end)
    return true
end

function GlowManager:Initialize()
    ns.DebuffDetector:RegisterCallback(function(assignedTarget)
        GlowManager:OnAssignmentChanged(assignedTarget)
    end)
end
