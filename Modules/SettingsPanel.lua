local _, ns = ...

-- Register KitnVanguard in Blizzard's addon settings list (ESC > Options > AddOns)

local function CreateSettingsPanel()
    local panel = CreateFrame("Frame")
    panel.name = ns.ADDON_NAME

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ns:AccentText("Kitn") .. "Vanguard")

    -- Description
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("Dispel assignment coordinator for Lightblinded Vanguard (Mythic, The Voidspire).\n\nUse the button below to open the full settings GUI, or type /kv config in chat.")

    -- Open Settings button
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(200, 30)
    btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    btn:SetText("Open KitnVanguard Settings")
    btn:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then
            SettingsPanel:Hide()
        end
        if ns.ConfigFrame then
            ns.ConfigFrame:Toggle()
        end
    end)

    -- Version info
    local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -12)
    local version = C_AddOns.GetAddOnMetadata(ns.ADDON_NAME, "Version") or "dev"
    ver:SetText("Version: " .. version)

    -- Register with Blizzard settings
    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.ADDON_NAME)
    category.ID = ns.ADDON_NAME
    Settings.RegisterAddOnCategory(category)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    CreateSettingsPanel()
    self:UnregisterAllEvents()
end)
