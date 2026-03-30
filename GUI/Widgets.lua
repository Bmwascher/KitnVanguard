local _, ns = ...

local Theme = ns.Theme
local GUIWidgets = {}
ns.GUIWidgets = GUIWidgets

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local math_abs = math.abs
local select = select

--------------------------------------------------------------------------------
-- Toggle (animated knob slider, matches KE style)
--------------------------------------------------------------------------------
function GUIWidgets:CreateToggle(parent, labelText, initialState, onValueChanged)
    local T = Theme
    local TOGGLE_WIDTH = 48
    local TOGGLE_HEIGHT = 24
    local KNOB_SIZE = 22
    local KNOB_PADDING = 1
    local ANIM_DURATION = 0.18

    local OFF_POS = KNOB_PADDING
    local ON_POS = TOGGLE_WIDTH - KNOB_SIZE - KNOB_PADDING

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(36)

    -- Label above the toggle
    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    ns:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
    row.label = label

    -- Toggle track
    local track = CreateFrame("Frame", nil, row, "BackdropTemplate")
    track:SetSize(TOGGLE_WIDTH, TOGGLE_HEIGHT)
    track:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    track:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    track:SetBackdropColor(T.bgDark[1], T.bgDark[2], T.bgDark[3], 1)
    track:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)

    -- Knob
    local knob = CreateFrame("Frame", nil, track, "BackdropTemplate")
    knob:SetSize(KNOB_SIZE, KNOB_SIZE)
    knob:SetPoint("LEFT", track, "LEFT", OFF_POS, 0)
    knob:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    knob:SetBackdropColor(0, 0, 0, 1)
    knob:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)

    local knobFill = knob:CreateTexture(nil, "ARTWORK")
    knobFill:SetAllPoints()
    knobFill:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.4)

    -- Animation
    local animGroup = knob:CreateAnimationGroup()
    local slideAnim = animGroup:CreateAnimation("Translation")
    slideAnim:SetDuration(ANIM_DURATION)
    slideAnim:SetSmoothing("OUT")

    local state = initialState or false
    local isAnimating = false

    local function updateVisuals(toState, instant)
        if toState then
            if instant then
                track:SetBackdropColor(T.accent[1] * 0.5, T.accent[2] * 0.5, T.accent[3] * 0.5, 1)
            end
            knobFill:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 1)
        else
            if instant then
                track:SetBackdropColor(T.bgDark[1], T.bgDark[2], T.bgDark[3], 1)
            end
            knobFill:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.4)
        end
    end

    local function animateToState(toState, instant)
        if isAnimating and not instant then return end
        isAnimating = true
        state = toState
        local targetX = toState and ON_POS or OFF_POS
        local currentX = select(4, knob:GetPoint())
        local deltaX = targetX - currentX

        if instant or math_abs(deltaX) < 1 then
            knob:ClearAllPoints()
            knob:SetPoint("LEFT", track, "LEFT", targetX, 0)
            updateVisuals(toState, true)
            isAnimating = false
        else
            updateVisuals(toState, true)
            animGroup:Stop()
            knob:ClearAllPoints()
            knob:SetPoint("LEFT", track, "LEFT", currentX, 0)
            slideAnim:SetOffset(deltaX, 0)
            animGroup:SetScript("OnFinished", function()
                knob:ClearAllPoints()
                knob:SetPoint("LEFT", track, "LEFT", targetX, 0)
                isAnimating = false
            end)
            animGroup:Play()
        end
    end

    -- Initialize
    animateToState(state, true)

    -- Click handler
    local button = CreateFrame("Button", nil, track)
    button:SetAllPoints()
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function()
        if isAnimating then return end
        local newState = not state
        animateToState(newState, false)
        if onValueChanged then
            C_Timer.After(ANIM_DURATION, function()
                onValueChanged(newState)
            end)
        end
    end)

    -- Hover
    button:SetScript("OnEnter", function()
        knobFill:SetColorTexture(
            T.accent[1] * 1.2,
            T.accent[2] * 1.2,
            T.accent[3] * 1.2,
            state and 1 or 0.6
        )
    end)
    button:SetScript("OnLeave", function()
        knobFill:SetColorTexture(
            T.accent[1],
            T.accent[2],
            T.accent[3],
            state and 1 or 0.4
        )
    end)

    -- Public API
    function row:SetValue(value, instant)
        if value ~= state then
            animateToState(value, instant)
        end
    end

    function row:GetValue()
        return state
    end

    row.toggle = track
    return row
end

--------------------------------------------------------------------------------
-- Dropdown (styled select menu)
--------------------------------------------------------------------------------
function GUIWidgets:CreateDropdown(parent, labelText, options, initialValue, onValueChanged)
    local T = Theme
    local DROPDOWN_HEIGHT = 24
    local ITEM_HEIGHT = 22

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(36)

    -- Label
    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    ns:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
    row.label = label

    -- Dropdown button
    local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
    btn:SetHeight(DROPDOWN_HEIGHT)
    btn:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    btn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -14)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], 1)
    btn:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)

    local selectedText = btn:CreateFontString(nil, "OVERLAY")
    selectedText:SetPoint("LEFT", btn, "LEFT", T.paddingMedium, 0)
    selectedText:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    selectedText:SetJustifyH("LEFT")
    ns:ApplyFont(selectedText, "normal")
    selectedText:SetTextColor(T.textPrimary[1], T.textPrimary[2], T.textPrimary[3], 1)

    -- Arrow indicator (collapse.tga texture)
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", btn, "RIGHT", -T.paddingSmall, 0)
    arrow:SetTexture("Interface\\AddOns\\KitnVanguard\\Media\\collapse.tga")
    arrow:SetVertexColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)

    -- Dropdown menu (created once, shown/hidden)
    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetWidth(btn:GetWidth())
    menu:SetFrameStrata("TOOLTIP")
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], 1)
    menu:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
    menu:Hide()

    local currentValue = initialValue
    local menuItems = {}

    -- Build menu items
    local function buildMenu()
        for _, item in ipairs(menuItems) do
            item:Hide()
        end
        menuItems = {}

        for i, opt in ipairs(options) do
            local itemBtn = CreateFrame("Button", nil, menu, "BackdropTemplate")
            itemBtn:SetHeight(ITEM_HEIGHT)
            itemBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -(i - 1) * ITEM_HEIGHT)
            itemBtn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", 0, -(i - 1) * ITEM_HEIGHT)

            local itemText = itemBtn:CreateFontString(nil, "OVERLAY")
            itemText:SetPoint("LEFT", itemBtn, "LEFT", T.paddingMedium, 0)
            itemText:SetJustifyH("LEFT")
            ns:ApplyFont(itemText, "normal")
            itemText:SetText(opt.text or tostring(opt.value))
            itemText:SetTextColor(T.textPrimary[1], T.textPrimary[2], T.textPrimary[3], 1)

            itemBtn:SetScript("OnClick", function()
                currentValue = opt.value
                selectedText:SetText(opt.text or tostring(opt.value))
                menu:Hide()
                if onValueChanged then
                    onValueChanged(opt.value)
                end
            end)

            itemBtn:SetScript("OnEnter", function()
                itemBtn:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                itemBtn:SetBackdropColor(T.accentHover[1], T.accentHover[2], T.accentHover[3], T.accentHover[4])
                itemBtn:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
            end)
            itemBtn:SetScript("OnLeave", function()
                itemBtn:SetBackdrop(nil)
            end)

            menuItems[i] = itemBtn
        end

        menu:SetHeight(#options * ITEM_HEIGHT)
    end

    -- Match menu width to button
    btn:SetScript("OnSizeChanged", function(_, width)
        menu:SetWidth(width)
    end)

    -- Set initial display text
    for _, opt in ipairs(options) do
        if opt.value == initialValue then
            selectedText:SetText(opt.text or tostring(opt.value))
            break
        end
    end

    buildMenu()

    -- Toggle menu on click
    btn:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            menu:Show()
        end
    end)

    -- Hover
    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(T.bgHover[1], T.bgHover[2], T.bgHover[3], 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], 1)
        -- Auto-close menu if mouse leaves both
        C_Timer.After(0.3, function()
            if menu:IsShown() and not menu:IsMouseOver() and not btn:IsMouseOver() then
                menu:Hide()
            end
        end)
    end)
    menu:SetScript("OnLeave", function()
        C_Timer.After(0.3, function()
            if menu:IsShown() and not menu:IsMouseOver() and not btn:IsMouseOver() then
                menu:Hide()
            end
        end)
    end)

    -- Public API
    function row:SetValue(value)
        currentValue = value
        for _, opt in ipairs(options) do
            if opt.value == value then
                selectedText:SetText(opt.text or tostring(opt.value))
                break
            end
        end
    end

    function row:GetValue()
        return currentValue
    end

    row.dropdown = btn
    row.menu = menu
    return row
end

--------------------------------------------------------------------------------
-- Button (accent-styled with hover animation)
--------------------------------------------------------------------------------
function GUIWidgets:CreateButton(parent, text, onClick)
    local T = Theme

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(28)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(T.accent[1] * 0.3, T.accent[2] * 0.3, T.accent[3] * 0.3, 1)
    btn:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 0.5)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("CENTER")
    ns:ApplyFont(btnText, "normal")
    btnText:SetText(text or "")
    btnText:SetTextColor(T.textPrimary[1], T.textPrimary[2], T.textPrimary[3], 1)

    btn:SetScript("OnClick", onClick)

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(T.accent[1] * 0.5, T.accent[2] * 0.5, T.accent[3] * 0.5, 1)
        btn:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(T.accent[1] * 0.3, T.accent[2] * 0.3, T.accent[3] * 0.3, 1)
        btn:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 0.5)
    end)

    function btn:SetLabel(newText)
        btnText:SetText(newText)
    end

    return btn
end

--------------------------------------------------------------------------------
-- Priority List (reorderable player list with up/down arrows)
--------------------------------------------------------------------------------
function GUIWidgets:CreatePriorityList(parent, priorityList, onChange)
    local T = Theme
    local ROW_HEIGHT = 22
    local ARROW_SIZE = 14
    local ARROW_TEXTURE = "Interface\\AddOns\\KitnVanguard\\Media\\collapse.tga"
    local RAID_CLASS_COLORS = RAID_CLASS_COLORS

    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(1)
    container.rowFrames = {}

    -- Resolve class color for a player name (searches raid units)
    local function getClassColor(playerName)
        local numMembers = GetNumGroupMembers()
        if numMembers == 0 then return nil end
        local prefix = IsInRaid() and "raid" or "party"
        local count = IsInRaid() and numMembers or (numMembers - 1)
        for idx = 1, count do
            local unit = prefix .. idx
            if UnitExists(unit) then
                local name = ns:GetFullUnitName(unit)
                if name and name == playerName then
                    local _, class = UnitClass(unit)
                    if class and RAID_CLASS_COLORS[class] then
                        local c = RAID_CLASS_COLORS[class]
                        return c.r, c.g, c.b
                    end
                end
            end
        end
        return nil
    end

    local function rebuild()
        for _, row in ipairs(container.rowFrames) do
            row:Hide()
        end
        container.rowFrames = {}

        if not priorityList or #priorityList == 0 then
            container:SetHeight(20)
            return
        end

        for i, name in ipairs(priorityList) do
            local row = CreateFrame("Frame", nil, container, "BackdropTemplate")
            row:SetHeight(ROW_HEIGHT)
            row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)

            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            if i % 2 == 0 then
                row:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], 0.5)
            else
                row:SetBackdropColor(0, 0, 0, 0)
            end

            row:EnableMouse(true)
            row:SetScript("OnEnter", function()
                row:SetBackdropColor(T.accentHover[1], T.accentHover[2], T.accentHover[3], T.accentHover[4])
            end)
            row:SetScript("OnLeave", function()
                if i % 2 == 0 then
                    row:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], 0.5)
                else
                    row:SetBackdropColor(0, 0, 0, 0)
                end
            end)

            -- Rank number
            local rank = row:CreateFontString(nil, "OVERLAY")
            rank:SetPoint("LEFT", row, "LEFT", 4, 0)
            rank:SetWidth(24)
            rank:SetJustifyH("RIGHT")
            ns:ApplyFont(rank, "small")
            rank:SetText(tostring(i) .. ".")
            rank:SetTextColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)

            -- Player name (class colored if in group)
            local nameText = row:CreateFontString(nil, "OVERLAY")
            nameText:SetPoint("LEFT", rank, "RIGHT", 6, 0)
            nameText:SetPoint("RIGHT", row, "RIGHT", -50, 0)
            nameText:SetJustifyH("LEFT")
            ns:ApplyFont(nameText, "normal")
            nameText:SetText(name)
            local cr, cg, cb = getClassColor(name)
            if cr then
                nameText:SetTextColor(cr, cg, cb, 1)
            else
                nameText:SetTextColor(T.textPrimary[1], T.textPrimary[2], T.textPrimary[3], 1)
            end

            -- Up arrow (collapse.tga rotated 180°)
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
                    priorityList[i], priorityList[i - 1] = priorityList[i - 1], priorityList[i]
                    rebuild()
                    if onChange then onChange() end
                end)
            end

            -- Down arrow (collapse.tga, default orientation)
            if i < #priorityList then
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
                    priorityList[i], priorityList[i + 1] = priorityList[i + 1], priorityList[i]
                    rebuild()
                    if onChange then onChange() end
                end)
            end

            container.rowFrames[#container.rowFrames + 1] = row
        end

        container:SetHeight(#priorityList * ROW_HEIGHT)
    end

    rebuild()

    function container:Refresh()
        rebuild()
    end

    return container
end

--------------------------------------------------------------------------------
-- Card (bordered section with title header — same pattern as KE)
--------------------------------------------------------------------------------
function GUIWidgets:CreateCard(parent, title, yOffset)
    local T = Theme

    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:EnableMouse(false)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", T.paddingSmall, -(yOffset or 0) + T.paddingSmall)
    card:SetPoint("RIGHT", parent, "RIGHT", -T.paddingSmall, 0)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = T.borderSize,
    })
    card:SetBackdropColor(T.bgLight[1], T.bgLight[2], T.bgLight[3], T.bgLight[4])
    card:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], T.border[4])

    card.rows = {}
    card.currentY = 0

    -- Header
    local headerHeight = 0
    if title and title ~= "" then
        headerHeight = 32
        local header = CreateFrame("Frame", nil, card, "BackdropTemplate")
        header:SetHeight(headerHeight)
        header:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
        header:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = T.borderSize,
        })
        header:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], T.bgMedium[4])
        header:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], T.border[4])

        local titleText = header:CreateFontString(nil, "OVERLAY")
        titleText:SetPoint("LEFT", header, "LEFT", T.paddingMedium, 0)
        ns:ApplyFont(titleText, "large")
        titleText:SetText(title)
        titleText:SetTextColor(T.accent[1], T.accent[2], T.accent[3], 1)
        card.titleText = titleText
    end
    card.headerHeight = headerHeight

    -- Content container
    local content = CreateFrame("Frame", nil, card)
    content:SetPoint("TOPLEFT", card, "TOPLEFT", T.paddingMedium, -headerHeight - T.paddingMedium)
    content:SetPoint("TOPRIGHT", card, "TOPRIGHT", -T.paddingMedium, -headerHeight - T.paddingMedium)
    content:SetHeight(1)
    content:EnableMouse(false)
    card.content = content

    function card:AddRow(widget, height, spacing)
        height = height or 36
        spacing = spacing or T.paddingSmall
        widget:SetParent(self.content)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -self.currentY)
        widget:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -self.currentY)
        self.currentY = self.currentY + height + spacing
        self.rows[#self.rows + 1] = widget
        self.content:SetHeight(self.currentY)
        self:UpdateHeight()
        return widget
    end

    function card:AddLabel(text)
        local lbl = self.content:CreateFontString(nil, "OVERLAY")
        lbl:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -self.currentY)
        lbl:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -self.currentY)
        lbl:SetJustifyH("LEFT")
        ns:ApplyFont(lbl, "normal")
        lbl:SetText(text)
        lbl:SetTextColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
        local h = lbl:GetStringHeight() or 14
        self.currentY = self.currentY + h + T.paddingSmall
        self.content:SetHeight(self.currentY)
        self:UpdateHeight()
        return lbl
    end

    function card:AddSpacing(amount)
        amount = amount or T.paddingMedium
        self.currentY = self.currentY + amount
        self.content:SetHeight(self.currentY)
        self:UpdateHeight()
    end

    function card:UpdateHeight()
        local totalHeight = self.headerHeight + self.currentY + T.paddingMedium * 2
        self:SetHeight(totalHeight)
        self.contentHeight = totalHeight
    end

    function card:GetContentHeight()
        return self.contentHeight or 0
    end

    card:UpdateHeight()
    return card
end

--------------------------------------------------------------------------------
-- EditBox (text input with label, matches KE style)
--------------------------------------------------------------------------------
function GUIWidgets:CreateEditBox(parent, labelText, value, callback)
    local T = Theme

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(36)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    ns:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)

    local container = CreateFrame("Frame", nil, row, "BackdropTemplate")
    container:SetHeight(22)
    container:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    container:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -14)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    container:SetBackdropColor(T.bgMedium[1], T.bgMedium[2], T.bgMedium[3], 1)
    container:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)

    local editBox = CreateFrame("EditBox", nil, container)
    editBox:SetPoint("LEFT", container, "LEFT", T.paddingSmall, 0)
    editBox:SetPoint("RIGHT", container, "RIGHT", -T.paddingSmall, 0)
    editBox:SetHeight(20)
    editBox:SetAutoFocus(false)
    ns:ApplyFont(editBox, "normal")
    editBox:SetTextColor(T.textPrimary[1], T.textPrimary[2], T.textPrimary[3], 1)
    editBox:SetText(value or "")

    editBox:SetScript("OnEnterPressed", function(eb)
        eb:ClearFocus()
        if callback then callback(eb:GetText()) end
    end)
    editBox:SetScript("OnEscapePressed", function(eb)
        eb:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusGained", function()
        container:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 1)
    end)
    editBox:SetScript("OnEditFocusLost", function(eb)
        container:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
        if callback then callback(eb:GetText()) end
    end)

    function row:SetValue(text)
        editBox:SetText(text or "")
    end

    function row:GetValue()
        return editBox:GetText()
    end

    row.editBox = editBox
    row.container = container
    return row
end

--------------------------------------------------------------------------------
-- ColorPicker (color swatch that opens WoW's ColorPickerFrame)
--------------------------------------------------------------------------------
function GUIWidgets:CreateColorPicker(parent, labelText, color, callback)
    local T = Theme
    color = color or { r = 1, g = 1, b = 1, a = 1 }

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(36)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    ns:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)

    -- Color swatch button
    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetSize(48, 22)
    swatch:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -14)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    swatch:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
    swatch:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)

    local currentR, currentG, currentB, currentA = color.r, color.g, color.b, color.a or 1
    local prevR, prevG, prevB, prevA = currentR, currentG, currentB, currentA

    swatch:SetScript("OnEnter", function()
        swatch:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 1)
    end)
    swatch:SetScript("OnLeave", function()
        swatch:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
    end)

    swatch:SetScript("OnClick", function()
        prevR, prevG, prevB, prevA = currentR, currentG, currentB, currentA
        local info = {}
        info.hasOpacity = true
        info.opacity = 1 - currentA
        info.r = currentR
        info.g = currentG
        info.b = currentB
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = 1 - ColorPickerFrame:GetColorAlpha()
            currentR, currentG, currentB, currentA = r, g, b, a
            swatch:SetBackdropColor(r, g, b, a)
            if callback then callback(r, g, b, a) end
        end
        info.opacityFunc = info.swatchFunc
        info.cancelFunc = function()
            currentR, currentG, currentB, currentA = prevR, prevG, prevB, prevA
            swatch:SetBackdropColor(prevR, prevG, prevB, prevA)
            if callback then callback(prevR, prevG, prevB, prevA) end
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    function row:SetColor(r, g, b, a)
        currentR, currentG, currentB, currentA = r, g, b, a or 1
        swatch:SetBackdropColor(r, g, b, a or 1)
    end

    function row:GetColor()
        return currentR, currentG, currentB, currentA
    end

    row.swatch = swatch
    return row
end

--------------------------------------------------------------------------------
-- Slider (KE-style: fill bar + stepper arrows + editable value box)
--------------------------------------------------------------------------------
function GUIWidgets:CreateSlider(parent, labelText, minVal, maxVal, step, value, callback)
    local T = Theme
    local STEPPER_TEXTURE = "Interface\\AddOns\\KitnVanguard\\Media\\collapse.tga"
    local math_floor = math.floor
    local math_max = math.max
    local math_min = math.min

    minVal = tonumber(minVal) or 0
    maxVal = tonumber(maxVal) or 100
    step = tonumber(step) or 1
    value = tonumber(value) or minVal

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(36)

    -- Label
    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 1)
    label:SetJustifyH("LEFT")
    ns:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)

    -- Slider background track
    local sliderBG = CreateFrame("Frame", nil, row, "BackdropTemplate")
    sliderBG:SetHeight(8)
    sliderBG:SetPoint("TOPLEFT", row, "TOPLEFT", 68, -22)
    sliderBG:SetPoint("TOPRIGHT", row, "TOPRIGHT", -18, -22)
    sliderBG:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sliderBG:SetBackdropColor(T.bgDark[1], T.bgDark[2], T.bgDark[3], 1)
    sliderBG:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
    sliderBG:EnableMouse(false)

    -- Actual slider
    local slider = CreateFrame("Slider", nil, row)
    slider:SetHeight(8)
    slider:SetPoint("TOPLEFT", row, "TOPLEFT", 77, -22)
    slider:SetPoint("TOPRIGHT", row, "TOPRIGHT", -27, -22)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(value)
    slider:SetHitRectInsets(-9, -9, -5, -5)

    -- Fill bar
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(6)
    fill:SetPoint("LEFT", sliderBG, "LEFT", 1, 0)
    fill:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 1)

    -- Transparent thumb (custom frame overlaid)
    local thumbTex = slider:CreateTexture(nil, "ARTWORK")
    thumbTex:SetColorTexture(0, 0, 0, 0)
    slider:SetThumbTexture(thumbTex)

    local thumbFrame = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    thumbFrame:SetSize(19, 12)
    thumbFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    thumbFrame:SetBackdropColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 0.6)
    thumbFrame:SetBackdropBorderColor(0, 0, 0, 1)

    slider:HookScript("OnUpdate", function()
        thumbFrame:ClearAllPoints()
        thumbFrame:SetPoint("CENTER", thumbTex, "CENTER", 0, 0)
    end)

    -- Left stepper (decrement)
    local leftStepper = CreateFrame("Button", nil, row)
    leftStepper:SetSize(20, 20)
    leftStepper:SetPoint("RIGHT", sliderBG, "LEFT", 0, 0)
    local leftIcon = leftStepper:CreateTexture(nil, "ARTWORK")
    leftIcon:SetAllPoints()
    leftIcon:SetTexture(STEPPER_TEXTURE)
    leftIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
    leftIcon:SetRotation(math.rad(-90))
    leftStepper:SetScript("OnClick", function()
        slider:SetValue(math_max(minVal, slider:GetValue() - step))
    end)
    leftStepper:SetScript("OnEnter", function()
        leftIcon:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
    end)
    leftStepper:SetScript("OnLeave", function()
        leftIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
    end)

    -- Right stepper (increment)
    local rightStepper = CreateFrame("Button", nil, row)
    rightStepper:SetSize(20, 20)
    rightStepper:SetPoint("LEFT", sliderBG, "RIGHT", 0, 0)
    local rightIcon = rightStepper:CreateTexture(nil, "ARTWORK")
    rightIcon:SetAllPoints()
    rightIcon:SetTexture(STEPPER_TEXTURE)
    rightIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
    rightIcon:SetRotation(math.rad(90))
    rightStepper:SetScript("OnClick", function()
        slider:SetValue(math_min(maxVal, slider:GetValue() + step))
    end)
    rightStepper:SetScript("OnEnter", function()
        rightIcon:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
    end)
    rightStepper:SetScript("OnLeave", function()
        rightIcon:SetVertexColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
    end)

    -- Editable value box
    local valueContainer = CreateFrame("Frame", nil, row, "BackdropTemplate")
    valueContainer:SetSize(48, 24)
    valueContainer:SetPoint("RIGHT", leftStepper, "LEFT", 0, 0)
    valueContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    valueContainer:SetBackdropColor(T.bgDark[1], T.bgDark[2], T.bgDark[3], 1)
    valueContainer:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)

    local valueEdit = CreateFrame("EditBox", nil, valueContainer)
    valueEdit:SetPoint("TOPLEFT", 0, 0)
    valueEdit:SetPoint("BOTTOMRIGHT", 0, 0)
    valueEdit:SetFontObject("GameFontNormal")
    valueEdit:SetTextColor(T.accent[1], T.accent[2], T.accent[3], 1)
    valueEdit:SetJustifyH("CENTER")
    valueEdit:SetAutoFocus(false)
    valueEdit:SetText(tostring(value))

    local isUpdating = false

    -- Update fill width and editbox text
    local function updateFill()
        local val = slider:GetValue()
        if maxVal == minVal then return end
        local pct = (val - minVal) / (maxVal - minVal)
        local width = math_max(1, (slider:GetWidth() - 2) * pct)
        fill:SetWidth(width)
        if not isUpdating then
            isUpdating = true
            valueEdit:SetText(tostring(math_floor(val * 100 + 0.5) / 100))
            isUpdating = false
        end
    end

    slider:SetScript("OnValueChanged", function(_, val)
        updateFill()
        if callback then callback(val) end
    end)
    slider:SetScript("OnSizeChanged", updateFill)

    -- EditBox input handling
    local function commitEdit(eb)
        eb:ClearFocus()
        local num = tonumber(eb:GetText())
        if num then
            num = math_max(minVal, math_min(maxVal, num))
            isUpdating = true
            slider:SetValue(num)
            isUpdating = false
        else
            updateFill()
        end
    end

    valueEdit:SetScript("OnEnterPressed", commitEdit)
    valueEdit:SetScript("OnEscapePressed", function(eb)
        eb:ClearFocus()
        updateFill()
    end)
    valueEdit:SetScript("OnEditFocusGained", function(eb)
        valueContainer:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 1)
        eb:HighlightText()
    end)
    valueEdit:SetScript("OnEditFocusLost", function(eb)
        valueContainer:SetBackdropBorderColor(T.border[1], T.border[2], T.border[3], 1)
        eb:HighlightText(0, 0)
        commitEdit(eb)
    end)

    -- Drag state for thumb color
    slider:SetScript("OnMouseDown", function()
        thumbFrame:SetBackdropColor(T.accent[1], T.accent[2], T.accent[3], 1)
    end)
    slider:SetScript("OnMouseUp", function()
        thumbFrame:SetBackdropColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 0.6)
    end)
    slider:SetScript("OnEnter", function()
        thumbFrame:SetBackdropColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 1)
    end)
    slider:SetScript("OnLeave", function()
        thumbFrame:SetBackdropColor(T.textSecondary[1], T.textSecondary[2], T.textSecondary[3], 0.6)
    end)

    C_Timer.After(0, updateFill)

    function row:SetValue(val) slider:SetValue(val) end
    function row:GetValue() return slider:GetValue() end

    row.slider = slider
    row.valueEdit = valueEdit
    return row
end

--------------------------------------------------------------------------------
-- AnchorButtons (9-point dot selector — matches KE PositionCard style)
--------------------------------------------------------------------------------
local ANCHOR_DIRECTIONS = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}

local DIRECTION_NAMES = {
    TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right",
    LEFT = "Left", CENTER = "Center", RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right",
}

function GUIWidgets:CreateAnchorButtons(parent, labelText, value, callback)
    local T = Theme
    local buttonSize = 12
    local frameWidth = 130
    local frameHeight = 68
    local titleHeight = 18
    local spacing = 2

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(frameWidth + buttonSize, frameHeight + buttonSize + titleHeight + spacing + 4)

    -- Title label
    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOP", container, "TOP", 0, 2)
    label:SetHeight(titleHeight)
    label:SetJustifyH("CENTER")
    ns:ApplyFont(label, "small")
    label:SetText(labelText or "")
    label:SetTextColor(T.accent[1], T.accent[2], T.accent[3], 1)
    container.label = label

    -- Background with border (represents the frame outline)
    local background = CreateFrame("Frame", nil, container, "BackdropTemplate")
    background:SetSize(frameWidth, frameHeight)
    background:SetPoint("TOP", container, "TOP", 0, -(titleHeight + spacing))
    background:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    background:SetBackdropColor(T.bgDark[1], T.bgDark[2], T.bgDark[3], 1)
    background:SetBackdropBorderColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)

    container.value = value or "CENTER"
    local buttons = {}

    for _, direction in ipairs(ANCHOR_DIRECTIONS) do
        local btn = CreateFrame("Button", nil, container)
        btn:SetSize(buttonSize, buttonSize)
        btn:SetPoint("CENTER", background, direction)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.tex = tex
        btn.direction = direction

        if container.value == direction then
            tex:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
        else
            tex:SetVertexColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)
        end

        btn:SetScript("OnClick", function()
            container.value = direction
            for _, b in pairs(buttons) do
                if container.value == b.direction then
                    b.tex:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
                else
                    b.tex:SetVertexColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)
                end
            end
            if callback then callback(direction) end
        end)

        btn:SetScript("OnEnter", function()
            tex:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 0.6)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(DIRECTION_NAMES[direction] or direction, 1, 0.82, 0)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function()
            if container.value == direction then
                tex:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
            else
                tex:SetVertexColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)
            end
            GameTooltip:Hide()
        end)

        buttons[direction] = btn
    end
    container.buttons = buttons

    function container:SetValue(val)
        self.value = val
        for direction, btn in pairs(self.buttons) do
            if val == direction then
                btn.tex:SetVertexColor(T.accent[1], T.accent[2], T.accent[3], 1)
            else
                btn.tex:SetVertexColor(T.textMuted[1], T.textMuted[2], T.textMuted[3], 1)
            end
        end
    end

    function container:GetValue()
        return self.value
    end

    return container
end

--------------------------------------------------------------------------------
-- PositionCard (anchor grids + offset sliders — matches KE pattern)
--------------------------------------------------------------------------------
function GUIWidgets:CreatePositionCard(parent, yOffset, config)
    local T = Theme
    config = config or {}
    local db = config.db or {}
    local onChange = config.onChangeCallback

    local card = self:CreateCard(parent, config.title or "Position", yOffset)

    -- Anchor grids row (two side by side, equally spaced)
    local gridRow = CreateFrame("Frame", nil, parent)
    gridRow:SetHeight(105)

    local selfPointWidget = self:CreateAnchorButtons(gridRow, "Anchor From",
        db.anchorFrom or "CENTER", function(val)
            db.anchorFrom = val
            if onChange then onChange() end
        end)
    selfPointWidget:SetPoint("LEFT", gridRow, "LEFT", 50, 0)

    local anchorPointWidget = self:CreateAnchorButtons(gridRow, "To Screen's",
        db.anchorTo or "CENTER", function(val)
            db.anchorTo = val
            if onChange then onChange() end
        end)
    anchorPointWidget:SetPoint("LEFT", gridRow, "CENTER", 30, 0)

    card:AddRow(gridRow, 95)

    -- X/Y offset sliders row
    local sliderRange = config.sliderRange or { -1000, 1000 }

    local xSlider = self:CreateSlider(parent, "X Offset",
        sliderRange[1], sliderRange[2], 1, db.xOffset or 0, function(val)
            db.xOffset = val
            if onChange then onChange() end
        end)
    card:AddRow(xSlider)

    local ySlider = self:CreateSlider(parent, "Y Offset",
        sliderRange[1], sliderRange[2], 1, db.yOffset or 0, function(val)
            db.yOffset = val
            if onChange then onChange() end
        end)
    card:AddRow(ySlider)

    card:AddSpacing(T.paddingSmall)
    return card
end
