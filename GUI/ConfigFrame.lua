local _, ns = ...

local Theme = ns.Theme
local Widgets = ns.GUIWidgets

local ConfigFrame = {}
ns.ConfigFrame = ConfigFrame

local CreateFrame = CreateFrame

local ROLE_NAMES = { TANK = "Tanks", DAMAGER = "DPS", HEALER = "Healers" }
local ROLE_COLORS = {
    TANK    = { 0.33, 0.59, 1.0 },
    DAMAGER = { 1.0, 0.33, 0.33 },
    HEALER  = { 0.33, 1.0, 0.40 },
}

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------
function ConfigFrame:Toggle()
    if InCombatLockdown() then
        ns:PrintError("Cannot open settings in combat.")
        return
    end
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function ConfigFrame:Show()
    if InCombatLockdown() then
        ns:PrintError("Settings will open after combat ends.")
        self.reopenAfterCombat = true
        return
    end
    if not self.frame then
        self:Create()
    end
    self.frame:Show()
end

function ConfigFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function ConfigFrame:IsShown()
    return self.frame and self.frame:IsShown()
end

--------------------------------------------------------------------------------
-- Build the main frame
--------------------------------------------------------------------------------
function ConfigFrame:Create()
    if self.frame then return end

    local T = Theme

    -- Main window
    local frame = CreateFrame("Frame", "KitnVanguard_ConfigFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(560, 720)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = T.borderSize,
    })
    frame:SetBackdropColor(T.bgDark[1], T.bgDark[2], T.bgDark[3], T.bgDark[4])
    frame:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], T.border[4])

    -- Title bar
    local header = CreateFrame("Frame", nil, frame)
    header:SetHeight(T.headerHeight)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", T.borderSize, -T.borderSize)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -T.borderSize, -T.borderSize)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", header, "LEFT", T.paddingMedium, 0)
    ns:ApplyFont(title, "large")
    title:SetText(ns:AccentText("Kitn") .. "Vanguard")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    local closeIcon = closeBtn:CreateTexture(nil, "OVERLAY")
    closeIcon:SetAllPoints()
    closeIcon:SetTexture("Interface\\AddOns\\KitnVanguard\\Media\\KitnCustomCrossv3.png")
    closeIcon:SetRotation(math.rad(45))
    closeIcon:SetVertexColor(T.textPrimary[1], T.textPrimary[2], T.textPrimary[3], 1)
    closeBtn:SetScript("OnClick", function() ConfigFrame:Hide() end)
    closeBtn:SetScript("OnEnter", function()
        closeIcon:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeIcon:SetVertexColor(T.textPrimary[1], T.textPrimary[2], T.textPrimary[3], 1)
    end)

    -- Header bottom border
    local headerBorder = header:CreateTexture(nil, "BORDER")
    headerBorder:SetHeight(T.borderSize)
    headerBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerBorder:SetColorTexture(T.border[1], T.border[2], T.border[3], T.border[4])

    -- Tab bar
    local TAB_HEIGHT = 28
    local tabBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    tabBar:SetHeight(TAB_HEIGHT)
    tabBar:SetPoint("TOPLEFT", frame, "TOPLEFT", T.borderSize, -(T.headerHeight + T.borderSize))
    tabBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -T.borderSize, -(T.headerHeight + T.borderSize))
    tabBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    tabBar:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], T.bgMedium[4])

    local tabBarBorder = tabBar:CreateTexture(nil, "BORDER")
    tabBarBorder:SetHeight(T.borderSize)
    tabBarBorder:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMLEFT", 0, 0)
    tabBarBorder:SetPoint("BOTTOMRIGHT", tabBar, "BOTTOMRIGHT", 0, 0)
    tabBarBorder:SetColorTexture(T.border[1], T.border[2], T.border[3], T.border[4])

    self.tabButtons = {}
    self.activeTab = nil

    local tabs = {
        { id = "general",  text = "General" },
        { id = "priority", text = "Scan Priority" },
        { id = "glow",     text = "Raid Frame Glow" },
        { id = "alert",    text = "Text Alert" },
    }

    for idx, tab in ipairs(tabs) do
        local tabBtn = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        tabBtn:SetHeight(TAB_HEIGHT)
        tabBtn:SetWidth(124)
        tabBtn:SetPoint("LEFT", tabBar, "LEFT", (idx - 1) * 124, 0)
        tabBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = T.borderSize,
        })
        tabBtn:SetBackdropColor(0, 0, 0, 0)
        tabBtn:SetBackdropBorderColor(0, 0, 0, 0)

        local tabText = tabBtn:CreateFontString(nil, "OVERLAY")
        tabText:SetPoint("CENTER")
        ns:ApplyFont(tabText, "normal")
        tabText:SetText(tab.text)
        tabText:SetTextColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)
        tabBtn.label = tabText

        -- Accent underline (hidden until selected)
        local underline = tabBtn:CreateTexture(nil, "OVERLAY")
        underline:SetHeight(2)
        underline:SetPoint("BOTTOMLEFT", tabBtn, "BOTTOMLEFT", 0, 0)
        underline:SetPoint("BOTTOMRIGHT", tabBtn, "BOTTOMRIGHT", 0, 0)
        underline:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 1)
        underline:Hide()
        tabBtn.underline = underline

        tabBtn:SetScript("OnClick", function()
            ConfigFrame:ShowTab(tab.id)
        end)
        tabBtn:SetScript("OnEnter", function()
            if ConfigFrame.activeTab ~= tab.id then
                tabText:SetTextColor(T.textPrimary[1], T.textPrimary[2], T.textPrimary[3], 1)
            end
        end)
        tabBtn:SetScript("OnLeave", function()
            if ConfigFrame.activeTab ~= tab.id then
                tabText:SetTextColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)
            end
        end)

        self.tabButtons[tab.id] = tabBtn
    end

    -- Footer bar
    local footer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    footer:SetHeight(T.footerHeight)
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", T.borderSize, T.borderSize)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -T.borderSize, T.borderSize)
    footer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    footer:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], 1)

    local footerBorder = footer:CreateTexture(nil, "OVERLAY")
    footerBorder:SetHeight(T.borderSize)
    footerBorder:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    footerBorder:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    footerBorder:SetColorTexture(T.border[1], T.border[2], T.border[3], T.border[4])

    local versionText = footer:CreateFontString(nil, "OVERLAY")
    versionText:SetPoint("LEFT", footer, "LEFT", T.paddingSmall, 0)
    ns:ApplyFont(versionText, "small")
    local ver = C_AddOns.GetAddOnMetadata(ns.ADDON_NAME, "Version") or "dev"
    versionText:SetText(ns:AccentText("Kitn") .. "Vanguard |cff888888v" .. ver .. "|r")

    -- Scrollable content area (below tab bar, above footer)
    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", T.borderSize,
        -(T.headerHeight + TAB_HEIGHT + T.borderSize * 2))
    contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
        -T.borderSize, T.footerHeight + T.borderSize)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentArea, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", 0, 0)

    -- Hide default scrollbar chrome
    if scrollFrame.ScrollBar then
        local sb = scrollFrame.ScrollBar
        sb:ClearAllPoints()
        sb:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -3, -T.paddingSmall - 12)
        sb:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -3, T.paddingSmall + 12)
        sb:SetWidth(10)
        if sb.Background then sb.Background:Hide() end
        if sb.Top then sb.Top:Hide() end
        if sb.Middle then sb.Middle:Hide() end
        if sb.Bottom then sb.Bottom:Hide() end
        if sb.trackBG then sb.trackBG:Hide() end
        if sb.ScrollUpButton then sb.ScrollUpButton:Hide() end
        if sb.ScrollDownButton then sb.ScrollDownButton:Hide() end
    end

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(560 - T.borderSize * 2 - T.scrollbarWidth)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollFrame = scrollFrame

    -- ESC to close
    table.insert(UISpecialFrames, "KitnVanguard_ConfigFrame")

    frame:Hide()
    self.frame = frame
    self.scrollChild = scrollChild

    -- Show default tab
    self:ShowTab("general")
end

--------------------------------------------------------------------------------
-- Tab switching
--------------------------------------------------------------------------------
function ConfigFrame:ShowTab(tabId)
    local T = Theme
    self.activeTab = tabId

    -- Update tab button visuals
    for id, btn in pairs(self.tabButtons) do
        if id == tabId then
            btn.label:SetTextColor(T.accent[1], T.accent[2], T.accent[3], 1)
            btn.underline:Show()
        else
            btn.label:SetTextColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)
            btn.underline:Hide()
        end
    end

    -- Clear scroll content
    local sc = self.scrollChild
    for _, child in ipairs({ sc:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ sc:GetRegions() }) do
        region:Hide()
    end

    -- Reset scroll position
    if self.scrollFrame then
        self.scrollFrame:SetVerticalScroll(0)
    end

    -- Build tab content
    if tabId == "general" then
        self:BuildGeneralTab(sc)
    elseif tabId == "priority" then
        self:BuildPriorityTab(sc)
    elseif tabId == "glow" then
        self:BuildGlowTab(sc)
    elseif tabId == "alert" then
        self:BuildAlertTab(sc)
    end
end

--------------------------------------------------------------------------------
-- General Tab
--------------------------------------------------------------------------------
function ConfigFrame:BuildGeneralTab(parent)
    local T = Theme
    local yOffset = T.paddingMedium
    local db = ns.db

    ------------------------------------------------------------
    -- Quick Setup
    ------------------------------------------------------------
    local setupCard = Widgets:CreateCard(parent, "Quick Setup", yOffset)
    setupCard:AddLabel("Scan your raid to auto-build a priority list sorted by role and class.")

    local scanBtn = Widgets:CreateButton(parent, "Scan from Raid", function()
        if not IsInRaid() then
            ns:PrintError("Must be in a raid to scan.")
            return
        end
        SlashCmdList["KITNVANGUARD"]("scan")
        ConfigFrame:ShowTab("general")
    end)
    setupCard:AddRow(scanBtn, 28)

    local count = db.priorityList and #db.priorityList or 0
    setupCard:AddLabel(count > 0
        and (count .. " players in priority list")
        or "No priority list configured yet.")

    setupCard:AddSpacing(T.paddingSmall)
    yOffset = yOffset + setupCard:GetContentHeight() + T.paddingMedium

    ------------------------------------------------------------
    -- Priority List
    ------------------------------------------------------------
    if db.priorityList and #db.priorityList > 0 then
        local prioCard = Widgets:CreateCard(parent, "Priority List", yOffset)
        prioCard:AddLabel("Higher = dispelled first. Use arrows to reorder.")

        local prioList = Widgets:CreatePriorityList(parent, db.priorityList, function() end)
        local listHeight = #db.priorityList * 22
        prioCard:AddRow(prioList, listHeight, 0)

        prioCard:AddSpacing(T.paddingSmall)

        prioCard:AddSpacing(T.paddingSmall)
        yOffset = yOffset + prioCard:GetContentHeight() + T.paddingMedium
    end

    ------------------------------------------------------------
    -- Dispel Behavior
    ------------------------------------------------------------
    local behaviorCard = Widgets:CreateCard(parent, "Dispel Behavior", yOffset)

    local reassignToggle = Widgets:CreateToggle(parent, "Reassign After Dispel",
        db.reassignAfterDispel, function(val)
            db.reassignAfterDispel = val
            if val then
                ns:Print("Reassign after dispel: |cff00ff00ON|r")
            else
                ns:Print("Reassign after dispel: |cffff0000OFF|r")
            end
        end)
    behaviorCard:AddRow(reassignToggle)
    behaviorCard:AddLabel("ON: glow moves to next target after each dispel. OFF: stays until wave ends.")

    behaviorCard:AddSpacing(T.paddingSmall)

    local warlockToggle = Widgets:CreateToggle(parent, "Include Warlocks",
        db.includeWarlocks, function(val)
            db.includeWarlocks = val
            ns:Print("Warlock dispellers: " .. (val and "|cff00ff00included|r" or "|cffff0000excluded|r"))
        end)
    behaviorCard:AddRow(warlockToggle)
    behaviorCard:AddLabel("Adds warlocks (Imp Singe Magic) as backup dispellers after healers.")

    behaviorCard:AddSpacing(T.paddingSmall)
    yOffset = yOffset + behaviorCard:GetContentHeight() + T.paddingMedium

    ------------------------------------------------------------
    -- Advanced
    ------------------------------------------------------------
    local advancedCard = Widgets:CreateCard(parent, "Advanced", yOffset)

    -- Addon Enabled + Minimap Button side by side
    local toggleRow = CreateFrame("Frame", nil, parent)
    toggleRow:SetHeight(36)

    local enabledToggle = Widgets:CreateToggle(toggleRow, "Addon Enabled", db.enabled, function(val)
        db.enabled = val
        ns:Print("Addon " .. (val and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    end)
    enabledToggle:SetPoint("TOPLEFT", toggleRow, "TOPLEFT", 0, 0)
    enabledToggle:SetWidth(200)

    local minimapToggle = Widgets:CreateToggle(toggleRow, "Minimap Button",
        not db.minimap.hide, function(val)
            db.minimap.hide = not val
            local okIcon, LDBIcon = pcall(LibStub, "LibDBIcon-1.0")
            if okIcon then
                if val then
                    LDBIcon:Show("KitnVanguard")
                else
                    LDBIcon:Hide("KitnVanguard")
                end
            end
            ns:Print("Minimap button " .. (val and "|cff00ff00shown|r" or "|cffff0000hidden|r"))
        end)
    minimapToggle:SetPoint("TOPLEFT", toggleRow, "TOPLEFT", 220, 0)
    minimapToggle:SetWidth(200)

    advancedCard:AddRow(toggleRow)

    advancedCard:AddSpacing(T.paddingSmall)

    local healerOptions = {
        { value = 0, text = "Auto (recommended)" },
        { value = 1, text = "Force #1" },
        { value = 2, text = "Force #2" },
        { value = 3, text = "Force #3" },
        { value = 4, text = "Force #4" },
        { value = 5, text = "Force #5" },
        { value = 6, text = "Force #6" },
    }
    local healerDropdown = Widgets:CreateDropdown(parent, "Healer Position",
        healerOptions, db.healerNumber, function(val)
            db.healerNumber = val
            if val == 0 then
                ns:Print("Healer position: |cff00ff00Auto|r")
            else
                ns:Print("Healer override: #" .. val)
            end
        end)
    advancedCard:AddRow(healerDropdown)
    advancedCard:AddLabel("Auto-detected from raid roster on pull. Override only for testing as non-healer.")

    advancedCard:AddSpacing(T.paddingMedium)

    local resetBtn = Widgets:CreateButton(parent, "Reset All Settings to Defaults", function()
        wipe(KitnVanguardDB)
        ns:Print("Settings reset to defaults. Reloading...")
        C_Timer.After(0.5, ReloadUI)
    end)
    advancedCard:AddRow(resetBtn, 28)

    advancedCard:AddSpacing(T.paddingSmall)
    yOffset = yOffset + advancedCard:GetContentHeight() + T.paddingMedium

    parent:SetHeight(yOffset + T.paddingLarge)
end

--------------------------------------------------------------------------------
-- Scan Priority Tab (role order + class order within roles)
--------------------------------------------------------------------------------
function ConfigFrame:BuildPriorityTab(parent)
    local T = Theme
    local yOffset = T.paddingMedium
    local db = ns.db
    local ARROW_TEXTURE = "Interface\\AddOns\\KitnVanguard\\Media\\collapse.tga"
    local ARROW_SIZE = 14
    local ROW_HEIGHT = 24
    local CLASS_COLORS = RAID_CLASS_COLORS

    ------------------------------------------------------------
    -- Role Order card
    ------------------------------------------------------------
    local roleCard = Widgets:CreateCard(parent, "Role Order", yOffset)
    roleCard:AddLabel("Roles higher in the list get dispelled first.")

    local roleContainer = CreateFrame("Frame", nil, parent)
    roleContainer:SetHeight(#db.scanRoleOrder * ROW_HEIGHT)

    local function rebuildRoles()
        for _, child in ipairs({ roleContainer:GetChildren() }) do
            child:Hide()
        end

        for i, role in ipairs(db.scanRoleOrder) do
            local row = CreateFrame("Frame", nil, roleContainer, "BackdropTemplate")
            row:SetHeight(ROW_HEIGHT)
            row:SetPoint("TOPLEFT", roleContainer, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", roleContainer, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            if i % 2 == 0 then
                row:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], 0.5)
            else
                row:SetBackdropColor(0, 0, 0, 0)
            end

            local rank = row:CreateFontString(nil, "OVERLAY")
            rank:SetPoint("LEFT", row, "LEFT", 4, 0)
            rank:SetWidth(24)
            rank:SetJustifyH("RIGHT")
            ns:ApplyFont(rank, "small")
            rank:SetText(tostring(i) .. ".")
            rank:SetTextColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)

            local nameText = row:CreateFontString(nil, "OVERLAY")
            nameText:SetPoint("LEFT", rank, "RIGHT", 6, 0)
            ns:ApplyFont(nameText, "normal")
            nameText:SetText(ROLE_NAMES[role] or role)
            local rc = ROLE_COLORS[role] or { 1, 1, 1 }
            nameText:SetTextColor(rc[1], rc[2], rc[3], 1)

            if i > 1 then
                local upBtn = CreateFrame("Button", nil, row)
                upBtn:SetSize(ARROW_SIZE, ARROW_SIZE)
                upBtn:SetPoint("RIGHT", row, "RIGHT", -ARROW_SIZE - 4, 0)
                local upIcon = upBtn:CreateTexture(nil, "OVERLAY")
                upIcon:SetAllPoints()
                upIcon:SetTexture(ARROW_TEXTURE)
                upIcon:SetRotation(math.rad(180))
                upIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
                upBtn:SetScript("OnEnter", function()
                    upIcon:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
                end)
                upBtn:SetScript("OnLeave", function()
                    upIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
                end)
                upBtn:SetScript("OnClick", function()
                    db.scanRoleOrder[i], db.scanRoleOrder[i - 1] = db.scanRoleOrder[i - 1], db.scanRoleOrder[i]
                    rebuildRoles()
                end)
            end

            if i < #db.scanRoleOrder then
                local downBtn = CreateFrame("Button", nil, row)
                downBtn:SetSize(ARROW_SIZE, ARROW_SIZE)
                downBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                local downIcon = downBtn:CreateTexture(nil, "OVERLAY")
                downIcon:SetAllPoints()
                downIcon:SetTexture(ARROW_TEXTURE)
                downIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
                downBtn:SetScript("OnEnter", function()
                    downIcon:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
                end)
                downBtn:SetScript("OnLeave", function()
                    downIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
                end)
                downBtn:SetScript("OnClick", function()
                    db.scanRoleOrder[i], db.scanRoleOrder[i + 1] = db.scanRoleOrder[i + 1], db.scanRoleOrder[i]
                    rebuildRoles()
                end)
            end
        end
    end

    rebuildRoles()
    roleCard:AddRow(roleContainer, #db.scanRoleOrder * ROW_HEIGHT)
    roleCard:AddSpacing(T.paddingSmall)
    yOffset = yOffset + roleCard:GetContentHeight() + T.paddingMedium

    ------------------------------------------------------------
    -- Class Order card
    ------------------------------------------------------------
    local classCard = Widgets:CreateCard(parent, "Class Order (within each role)", yOffset)
    classCard:AddLabel("Classes higher in the list get dispelled first within their role group.")

    local classContainer = CreateFrame("Frame", nil, parent)
    classContainer:SetHeight(#db.scanClassOrder * ROW_HEIGHT)

    local function rebuildClasses()
        for _, child in ipairs({ classContainer:GetChildren() }) do
            child:Hide()
        end

        for i, classId in ipairs(db.scanClassOrder) do
            local info = ns.CLASS_INFO[classId]
            if not info then info = { file = "WARRIOR", name = "Unknown" } end

            local row = CreateFrame("Frame", nil, classContainer, "BackdropTemplate")
            row:SetHeight(ROW_HEIGHT)
            row:SetPoint("TOPLEFT", classContainer, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", classContainer, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            if i % 2 == 0 then
                row:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], 0.5)
            else
                row:SetBackdropColor(0, 0, 0, 0)
            end

            local rank = row:CreateFontString(nil, "OVERLAY")
            rank:SetPoint("LEFT", row, "LEFT", 4, 0)
            rank:SetWidth(24)
            rank:SetJustifyH("RIGHT")
            ns:ApplyFont(rank, "small")
            rank:SetText(tostring(i) .. ".")
            rank:SetTextColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)

            local nameText = row:CreateFontString(nil, "OVERLAY")
            nameText:SetPoint("LEFT", rank, "RIGHT", 6, 0)
            ns:ApplyFont(nameText, "normal")
            nameText:SetText(info.name)
            local cc = CLASS_COLORS[info.file]
            if cc then
                nameText:SetTextColor(cc.r, cc.g, cc.b, 1)
            else
                nameText:SetTextColor(T.textPrimary[1], T.textPrimary[2], T.textPrimary[3], 1)
            end

            if i > 1 then
                local upBtn = CreateFrame("Button", nil, row)
                upBtn:SetSize(ARROW_SIZE, ARROW_SIZE)
                upBtn:SetPoint("RIGHT", row, "RIGHT", -ARROW_SIZE - 4, 0)
                local upIcon = upBtn:CreateTexture(nil, "OVERLAY")
                upIcon:SetAllPoints()
                upIcon:SetTexture(ARROW_TEXTURE)
                upIcon:SetRotation(math.rad(180))
                upIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
                upBtn:SetScript("OnEnter", function()
                    upIcon:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
                end)
                upBtn:SetScript("OnLeave", function()
                    upIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
                end)
                upBtn:SetScript("OnClick", function()
                    db.scanClassOrder[i], db.scanClassOrder[i - 1] = db.scanClassOrder[i - 1], db.scanClassOrder[i]
                    rebuildClasses()
                end)
            end

            if i < #db.scanClassOrder then
                local downBtn = CreateFrame("Button", nil, row)
                downBtn:SetSize(ARROW_SIZE, ARROW_SIZE)
                downBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                local downIcon = downBtn:CreateTexture(nil, "OVERLAY")
                downIcon:SetAllPoints()
                downIcon:SetTexture(ARROW_TEXTURE)
                downIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
                downBtn:SetScript("OnEnter", function()
                    downIcon:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
                end)
                downBtn:SetScript("OnLeave", function()
                    downIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
                end)
                downBtn:SetScript("OnClick", function()
                    db.scanClassOrder[i], db.scanClassOrder[i + 1] = db.scanClassOrder[i + 1], db.scanClassOrder[i]
                    rebuildClasses()
                end)
            end
        end
    end

    rebuildClasses()
    classCard:AddRow(classContainer, #db.scanClassOrder * ROW_HEIGHT)
    classCard:AddSpacing(T.paddingSmall)
    yOffset = yOffset + classCard:GetContentHeight() + T.paddingMedium

    parent:SetHeight(yOffset + T.paddingLarge)
end

--------------------------------------------------------------------------------
-- Glow Tab
--------------------------------------------------------------------------------
function ConfigFrame:BuildGlowTab(parent)
    local T = Theme
    local yOffset = T.paddingMedium
    local db = ns.db.glow

    -- Preview card (top for quick testing)
    local testCard = Widgets:CreateCard(parent, "Preview", yOffset)

    local testBtn = Widgets:CreateButton(parent, "Test Glow (5 seconds)", function()
        local success = ns.GlowManager:TestGlow(5)
        if success then
            ns:Print("Glowing your frame for 5 seconds...")
        else
            ns:PrintError("Could not find your frame. Are raid/party frames visible?")
        end
    end)
    testCard:AddRow(testBtn, 28)

    testCard:AddSpacing(T.paddingSmall)
    yOffset = yOffset + testCard:GetContentHeight() + T.paddingMedium

    -- General card
    local generalCard = Widgets:CreateCard(parent, "Glow Settings", yOffset)
    generalCard:AddLabel("Highlights your dispel target's raid frame.")

    local enabledToggle = Widgets:CreateToggle(parent, "Enable Glow", db.enabled, function(val)
        db.enabled = val
        ns:Print("Glow " .. (val and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    end)
    generalCard:AddRow(enabledToggle)

    -- Glow type dropdown
    local glowTypes = {
        { value = "pixel",    text = "Pixel Glow (rotating lines)" },
        { value = "button",   text = "Button Glow (action button style)" },
        { value = "autocast", text = "AutoCast Glow (orbiting particles)" },
        { value = "proc",     text = "Proc Glow (spell proc flash)" },
    }
    local typeDropdown = Widgets:CreateDropdown(parent, "Glow Type",
        glowTypes, db.glowType, function(val)
            db.glowType = val
            ns:Print("Glow type: " .. val)
            -- Refresh tab to show type-specific settings
            ConfigFrame:ShowTab("glow")
        end)
    generalCard:AddRow(typeDropdown)

    -- Color picker
    local colorPicker = Widgets:CreateColorPicker(parent, "Glow Color",
        db.color, function(r, g, b, a)
            db.color = { r = r, g = g, b = b, a = a }
        end)
    generalCard:AddRow(colorPicker)

    generalCard:AddSpacing(T.paddingSmall)
    yOffset = yOffset + generalCard:GetContentHeight() + T.paddingMedium

    -- Type-specific settings card
    local glowType = db.glowType or "pixel"

    if glowType == "pixel" then
        local pixelCard = Widgets:CreateCard(parent, "Pixel Glow Settings", yOffset)

        local linesSlider = Widgets:CreateSlider(parent, "Number of Lines",
            1, 20, 1, db.lines or 8, function(val)
                db.lines = val
            end)
        pixelCard:AddRow(linesSlider)

        local freqSlider = Widgets:CreateSlider(parent, "Rotation Speed",
            -1, 1, 0.05, db.frequency or 0.25, function(val)
                db.frequency = val
            end)
        pixelCard:AddRow(freqSlider)

        local thickSlider = Widgets:CreateSlider(parent, "Line Thickness",
            1, 6, 1, db.thickness or 2, function(val)
                db.thickness = val
            end)
        pixelCard:AddRow(thickSlider)

        local borderToggle = Widgets:CreateToggle(parent, "Solid Border",
            db.border ~= false, function(val)
                db.border = val
            end)
        pixelCard:AddRow(borderToggle)

        pixelCard:AddSpacing(T.paddingSmall)
        yOffset = yOffset + pixelCard:GetContentHeight() + T.paddingMedium

    elseif glowType == "button" then
        local btnCard = Widgets:CreateCard(parent, "Button Glow Settings", yOffset)

        local freqSlider = Widgets:CreateSlider(parent, "Frequency",
            0.01, 1, 0.01, db.frequency or 0.125, function(val)
                db.frequency = val
            end)
        btnCard:AddRow(freqSlider)

        btnCard:AddSpacing(T.paddingSmall)
        yOffset = yOffset + btnCard:GetContentHeight() + T.paddingMedium

    elseif glowType == "autocast" then
        local autoCard = Widgets:CreateCard(parent, "AutoCast Glow Settings", yOffset)

        local particlesSlider = Widgets:CreateSlider(parent, "Particle Groups",
            1, 8, 1, db.lines or 4, function(val)
                db.lines = val
            end)
        autoCard:AddRow(particlesSlider)

        local freqSlider = Widgets:CreateSlider(parent, "Speed",
            -1, 1, 0.025, db.frequency or 0.125, function(val)
                db.frequency = val
            end)
        autoCard:AddRow(freqSlider)

        local scaleSlider = Widgets:CreateSlider(parent, "Particle Scale",
            0.5, 3, 0.1, db.scale or 1, function(val)
                db.scale = val
            end)
        autoCard:AddRow(scaleSlider)

        autoCard:AddSpacing(T.paddingSmall)
        yOffset = yOffset + autoCard:GetContentHeight() + T.paddingMedium

    elseif glowType == "proc" then
        local procCard = Widgets:CreateCard(parent, "Proc Glow Settings", yOffset)
        procCard:AddLabel("Uses default Blizzard proc animation.")
        procCard:AddSpacing(T.paddingSmall)
        yOffset = yOffset + procCard:GetContentHeight() + T.paddingMedium
    end

    parent:SetHeight(yOffset + T.paddingLarge)
end

--------------------------------------------------------------------------------
-- Text Alert Tab
--------------------------------------------------------------------------------
function ConfigFrame:BuildAlertTab(parent)
    local T = Theme
    local yOffset = T.paddingMedium
    local db = ns.db.alert

    ------------------------------------------------------------
    -- General Alert Settings
    ------------------------------------------------------------
    local generalCard = Widgets:CreateCard(parent, "Alert Settings", yOffset)

    local enabledToggle = Widgets:CreateToggle(parent, "Enable Alert Text", db.enabled, function(val)
        db.enabled = val
        ns:Print("Alert display " .. (val and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    end)
    generalCard:AddRow(enabledToggle)

    local prefixBox = Widgets:CreateEditBox(parent, "Text Prefix", db.textPrefix, function(val)
        db.textPrefix = val
        ns:Print("Alert prefix set to: " .. val)
    end)
    generalCard:AddRow(prefixBox)

    local durationSlider = Widgets:CreateSlider(parent, "Auto-hide (seconds, 0 = stay until cleared)",
        0, 30, 1, db.duration, function(val)
            db.duration = val
        end)
    generalCard:AddRow(durationSlider)

    -- Sound settings
    local soundToggle = Widgets:CreateToggle(parent, "Play Sound on Assignment",
        db.soundEnabled, function(val)
            db.soundEnabled = val
            ns:Print("Alert sound " .. (val and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
        end)
    generalCard:AddRow(soundToggle)

    -- Sound file dropdown (LSM-powered, matches KES EbonMightHelper)
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local soundOptions = { { value = "None", text = "None" } }
    if LSM then
        local sounds = LSM:HashTable("sound")
        for name in pairs(sounds) do
            soundOptions[#soundOptions + 1] = { value = name, text = name }
        end
        -- Sort alphabetically (except None stays first)
        table.sort(soundOptions, function(a, b)
            if a.value == "None" and b.value == "None" then return false end
            if a.value == "None" then return true end
            if b.value == "None" then return false end
            return a.text:lower() < b.text:lower()
        end)
    end
    local soundDropdown = Widgets:CreateDropdown(parent, "Alert Sound",
        soundOptions, db.soundFile or "None", function(val)
            db.soundFile = val
            -- Preview the sound on select
            if val ~= "None" and LSM then
                local path = LSM:Fetch("sound", val)
                if path then
                    pcall(PlaySoundFile, path, db.soundChannel or "Master")
                end
            end
        end)
    generalCard:AddRow(soundDropdown)

    -- Sound channel dropdown
    local channelOptions = {
        { value = "Master",   text = "Master" },
        { value = "SFX",      text = "SFX" },
        { value = "Music",    text = "Music" },
        { value = "Ambience", text = "Ambience" },
        { value = "Dialog",   text = "Dialog" },
    }
    local channelDropdown = Widgets:CreateDropdown(parent, "Sound Channel",
        channelOptions, db.soundChannel or "Master", function(val)
            db.soundChannel = val
        end)
    generalCard:AddRow(channelDropdown)

    -- Test button
    local testBtn = Widgets:CreateButton(parent, "Test Alert (5 seconds)", function()
        ns.AlertFrame:Test(5)
        ns:Print("Showing test alert for 5 seconds...")
    end)
    generalCard:AddRow(testBtn, 28)

    generalCard:AddSpacing(T.paddingSmall)
    yOffset = yOffset + generalCard:GetContentHeight() + T.paddingMedium

    ------------------------------------------------------------
    -- Text Style
    ------------------------------------------------------------
    local textCard = Widgets:CreateCard(parent, "Text Style", yOffset)

    local fontSizeSlider = Widgets:CreateSlider(parent, "Font Size",
        12, 48, 1, db.fontSize, function(val)
            db.fontSize = val
            ns.AlertFrame:ApplySettings()
        end)
    textCard:AddRow(fontSizeSlider)

    local outlineOptions = {
        { value = "THICKOUTLINE", text = "Thick Outline" },
        { value = "OUTLINE",     text = "Outline" },
        { value = "NONE",        text = "None" },
    }
    local outlineDropdown = Widgets:CreateDropdown(parent, "Font Outline",
        outlineOptions, db.fontOutline, function(val)
            db.fontOutline = val
            ns.AlertFrame:ApplySettings()
        end)
    textCard:AddRow(outlineDropdown)

    local colorPicker = Widgets:CreateColorPicker(parent, "Text Color",
        db.textColor, function(r, g, b, a)
            db.textColor = { r = r, g = g, b = b, a = a }
            ns.AlertFrame:ApplySettings()
        end)
    textCard:AddRow(colorPicker)

    textCard:AddSpacing(T.paddingSmall)
    yOffset = yOffset + textCard:GetContentHeight() + T.paddingMedium

    ------------------------------------------------------------
    -- Position (KE-style position card with anchor grids)
    ------------------------------------------------------------
    local posCard = Widgets:CreatePositionCard(parent, yOffset, {
        title = "Position",
        db = db,
        sliderRange = { -800, 800 },
        onChangeCallback = function()
            ns.AlertFrame:ApplySettings()
        end,
    })
    yOffset = yOffset + posCard:GetContentHeight() + T.paddingMedium

    parent:SetHeight(yOffset + T.paddingLarge)
end

--------------------------------------------------------------------------------
-- Refresh (re-show current tab)
--------------------------------------------------------------------------------
function ConfigFrame:Refresh()
    if not self.frame or not self.activeTab then return end
    self:ShowTab(self.activeTab)
end

--------------------------------------------------------------------------------
-- Combat handler: hide in combat, reopen after
--------------------------------------------------------------------------------
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if ConfigFrame:IsShown() then
            ConfigFrame.reopenAfterCombat = true
            ConfigFrame:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ConfigFrame.reopenAfterCombat then
            ConfigFrame.reopenAfterCombat = nil
            ConfigFrame:Show()
        end
    end
end)
