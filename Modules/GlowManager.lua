local _, ns = ...

local GlowManager = {}
ns.GlowManager = GlowManager

local activeGlows = {} -- parentFrame -> overlay frame

-- Create a glow overlay frame anchored to a raid frame.
-- Parented to UIParent (not the raid frame) to avoid secure frame tree
-- taint and combat lockdown issues with Show/Hide during combat.
local function createGlowOverlay(raidFrame, playerName)
    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetPoint("TOPLEFT", raidFrame, "TOPLEFT")
    overlay:SetPoint("BOTTOMRIGHT", raidFrame, "BOTTOMRIGHT")
    overlay:SetFrameStrata(raidFrame:GetFrameStrata())
    overlay:SetFrameLevel(raidFrame:GetFrameLevel() + 10)

    local color = ns.db and ns.db.glowColor or { r = 1, g = 0.8, b = 0, a = 1 }
    local borderSize = 2

    -- Semi-transparent colored fill
    local fill = overlay:CreateTexture(nil, "OVERLAY")
    fill:SetAllPoints()
    fill:SetColorTexture(color.r, color.g, color.b, 0.2)

    -- Border edges
    local top = overlay:CreateTexture(nil, "OVERLAY")
    top:SetColorTexture(color.r, color.g, color.b, color.a)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(borderSize)

    local bottom = overlay:CreateTexture(nil, "OVERLAY")
    bottom:SetColorTexture(color.r, color.g, color.b, color.a)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(borderSize)

    local left = overlay:CreateTexture(nil, "OVERLAY")
    left:SetColorTexture(color.r, color.g, color.b, color.a)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(borderSize)

    local right = overlay:CreateTexture(nil, "OVERLAY")
    right:SetColorTexture(color.r, color.g, color.b, color.a)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(borderSize)

    -- Player name text for absolute clarity
    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetText(playerName)
    text:SetTextColor(color.r, color.g, color.b, 1)
    overlay.nameText = text

    -- Pulse animation for visibility
    local ag = overlay:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local alpha = ag:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0.4)
    alpha:SetDuration(0.5)
    overlay.pulseAnim = ag

    overlay:Show()
    ag:Play()

    return overlay
end

--- Apply a glow overlay to a raid frame.
function GlowManager:ApplyGlow(frame, playerName)
    if activeGlows[frame] then
        return -- already glowing this frame
    end
    activeGlows[frame] = createGlowOverlay(frame, playerName)
end

--- Remove all active glow overlays.
function GlowManager:RemoveAllGlows()
    for _, overlay in pairs(activeGlows) do
        overlay.pulseAnim:Stop()
        overlay:Hide()
    end
    wipe(activeGlows)
end

--- Callback handler for DebuffDetector assignment changes.
function GlowManager:OnAssignmentChanged(assignedTarget)
    self:RemoveAllGlows()

    if not assignedTarget then
        return
    end

    local frame = ns.FrameFinder:FindFrameByName(assignedTarget)
    if frame then
        self:ApplyGlow(frame, assignedTarget)
    end
end

function GlowManager:Initialize()
    ns.DebuffDetector:RegisterCallback(function(assignedTarget)
        GlowManager:OnAssignmentChanged(assignedTarget)
    end)
end
