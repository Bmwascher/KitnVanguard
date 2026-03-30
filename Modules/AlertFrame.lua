local _, ns = ...

local AlertFrame = {}
ns.AlertFrame = AlertFrame

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local UnitClass = UnitClass
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitExists = UnitExists
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local issecretvalue = issecretvalue

local LSM = LibStub("LibSharedMedia-3.0", true) -- optional, true = silent fail

local frame = nil
local hideTimer = nil
local soundHandle = nil

-- Class icon atlas names (WoW built-in, no custom textures needed)
local CLASS_ICON_ATLAS = {
    WARRIOR     = "classicon-warrior",
    PALADIN     = "classicon-paladin",
    HUNTER      = "classicon-hunter",
    ROGUE       = "classicon-rogue",
    PRIEST      = "classicon-priest",
    DEATHKNIGHT = "classicon-deathknight",
    SHAMAN      = "classicon-shaman",
    MAGE        = "classicon-mage",
    WARLOCK     = "classicon-warlock",
    MONK        = "classicon-monk",
    DRUID       = "classicon-druid",
    DEMONHUNTER = "classicon-demonhunter",
    EVOKER      = "classicon-evoker",
}

-- Role icon atlas fallbacks
local ROLE_ICON_ATLAS = {
    TANK    = "groupfinder-icon-role-large-tank",
    HEALER  = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps",
}

-- Find unit token for a player name, then get their class/role
local function getPlayerInfo(playerName)
    -- Check player first (works solo and in groups)
    local myName = ns:GetFullUnitName("player")
    if myName and myName == playerName then
        local _, classFile = UnitClass("player")
        local role = UnitGroupRolesAssigned("player")
        return classFile, role
    end

    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then
        return nil, nil
    end

    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and numMembers or (numMembers - 1)

    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) then
            local name = ns:GetFullUnitName(unit)
            if name and name == playerName then
                local _, classFile = UnitClass(unit)
                local role = UnitGroupRolesAssigned(unit)
                if issecretvalue(classFile) then classFile = nil end
                if issecretvalue(role) then role = nil end
                return classFile, role
            end
        end
    end

    -- Fallback: try name as a unit token directly
    if UnitExists(playerName) then
        local _, classFile = UnitClass(playerName)
        local role = UnitGroupRolesAssigned(playerName)
        return classFile, role
    end

    return nil, nil
end

-- Create the on-screen alert frame (once, reused)
local function ensureFrame()
    if frame then return end

    frame = CreateFrame("Frame", "KitnVanguard_AlertFrame", UIParent)
    frame:SetSize(400, 50)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)

    -- Prefix text ("Dispel:")
    local prefix = frame:CreateFontString(nil, "OVERLAY")
    prefix:SetPoint("RIGHT", frame, "CENTER", 0, 0)
    prefix:SetJustifyH("RIGHT")
    frame.prefix = prefix

    -- Class/role icon (between prefix and name)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", prefix, "RIGHT", 6, 0)
    frame.icon = icon

    -- Player name text (right of icon)
    local nameText = frame:CreateFontString(nil, "OVERLAY")
    nameText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    nameText:SetJustifyH("LEFT")
    frame.nameText = nameText

    frame:Hide()
end

--- Apply current settings to the frame (position, font, color).
function AlertFrame:ApplySettings()
    ensureFrame()
    local db = ns.db.alert

    -- Position
    frame:ClearAllPoints()
    frame:SetPoint(db.anchorFrom, UIParent, db.anchorTo, db.xOffset, db.yOffset)

    -- Font
    local outline = db.fontOutline
    if outline == "NONE" then outline = "" end
    frame.prefix:SetFont(ns.Theme.fontFace, db.fontSize, outline)
    frame.prefix:SetShadowOffset(1, -1)
    frame.prefix:SetShadowColor(0, 0, 0, 0.8)
    frame.nameText:SetFont(ns.Theme.fontFace, db.fontSize, outline)
    frame.nameText:SetShadowOffset(1, -1)
    frame.nameText:SetShadowColor(0, 0, 0, 0.8)

    -- Icon size matches font
    local iconSize = db.fontSize + 4
    frame.icon:SetSize(iconSize, iconSize)
end

--- Show alert for a target player.
function AlertFrame:Show(playerName)
    local db = ns.db.alert
    if not db.enabled then return end

    ensureFrame()
    self:ApplySettings()

    -- Resolve class icon or role icon
    local classFile, role = getPlayerInfo(playerName)
    local atlas = nil
    if classFile and CLASS_ICON_ATLAS[classFile] then
        atlas = CLASS_ICON_ATLAS[classFile]
    elseif role and ROLE_ICON_ATLAS[role] then
        atlas = ROLE_ICON_ATLAS[role]
    end

    if atlas then
        frame.icon:SetAtlas(atlas)
        frame.icon:Show()
    else
        frame.icon:Hide()
    end

    -- Set prefix and name text separately
    local c = db.textColor
    local prefixStr = db.textPrefix or "Dispel:"
    frame.prefix:SetText(prefixStr .. " ")
    frame.prefix:SetTextColor(c.r, c.g, c.b, c.a or 1)

    -- Strip server name for display
    local displayName = playerName:match("^([^%-]+)") or playerName
    frame.nameText:SetText(displayName)
    frame.nameText:SetTextColor(c.r, c.g, c.b, c.a or 1)

    -- Cancel existing hide timer
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end

    frame:SetAlpha(1)
    frame:Show()

    -- Play sound alert (LSM pattern from KES EbonMightHelper)
    if db.soundEnabled then
        -- Stop previous sound if still playing
        if soundHandle then
            StopSound(soundHandle)
            soundHandle = nil
        end
        local soundFile = db.soundFile
        if soundFile and soundFile ~= "None" and LSM then
            local path = LSM:Fetch("sound", soundFile)
            if path then
                local ok, willPlay, handle = pcall(PlaySoundFile, path, db.soundChannel or "Master")
                if ok and willPlay and handle then
                    soundHandle = handle
                end
            end
        end
    end

    -- Auto-hide after duration (0 = stay until cleared)
    if db.duration and db.duration > 0 then
        hideTimer = C_Timer.NewTimer(db.duration, function()
            AlertFrame:Hide()
            hideTimer = nil
        end)
    end
end

--- Hide the alert.
function AlertFrame:Hide()
    if frame then
        frame:Hide()
    end
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

--- Test display for config preview.
function AlertFrame:Test(duration)
    self:Show(UnitName("player"))
    if duration and duration > 0 then
        C_Timer.After(duration, function()
            AlertFrame:Hide()
        end)
    end
end

--- Register as a DebuffDetector callback.
function AlertFrame:Initialize()
    ns.DebuffDetector:RegisterCallback(function(assignedTarget)
        if assignedTarget then
            AlertFrame:Show(assignedTarget)
        else
            AlertFrame:Hide()
        end
    end)
end
