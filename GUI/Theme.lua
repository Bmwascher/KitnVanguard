local _, ns = ...

-- Theme system matching KitnEssentials visual style
local Theme = {
    -- Backgrounds (matches KES ThemeDefaults)
    bgDark         = { 0.0627, 0.0627, 0.0627, 0.75 },
    bgMedium       = { 0.0902, 0.0902, 0.0902, 0.75 },
    bgLight        = { 0.0314, 0.0314, 0.0314, 0.75 },
    bgHover        = { 0.1804, 0.1804, 0.1804, 0.75 },
    border         = { 0, 0, 0, 1 },

    -- Accent (KitnUI pink #FF008C)
    accent         = { 1.0, 0.0, 0.549, 1 },
    accentHover    = { 1.0, 0.0, 0.549, 0.25 },
    accentDim      = { 0.80, 0.0, 0.439, 1 },

    -- Text (matches KES: all white)
    textPrimary    = { 1, 1, 1, 1 },
    textSecondary  = { 1, 1, 1, 1 },
    textMuted      = { 1, 1, 1, 1 },

    -- Selection
    selectedBg     = { 1.0, 0.0, 0.549, 0.20 },
    selectedText   = { 0.902, 0.902, 0.902, 1 },

    -- Status
    error          = { 0.90, 0.30, 0.30, 1 },
    success        = { 0.30, 0.80, 0.40, 1 },
    warning        = { 0.90, 0.75, 0.30, 1 },

    -- Dimensions
    headerHeight   = 32,
    footerHeight   = 24,
    borderSize     = 1,

    -- Spacing
    paddingSmall   = 4,
    paddingMedium  = 8,
    paddingLarge   = 12,
    scrollbarWidth = 14,

    -- Fonts (use default WoW font — no custom media dependency)
    fontFace       = "Fonts\\FRIZQT__.TTF",
    fontSizeSmall  = 12,
    fontSizeNormal = 13,
    fontSizeLarge  = 16,
    fontOutline    = "OUTLINE",
}
ns.Theme = Theme

--- Apply theme font to a FontString.
--- @param fontString table FontString object
--- @param size string|number "small", "normal", "large", or a number
function ns:ApplyFont(fontString, size)
    if not fontString or not fontString.SetFont then return end
    local T = self.Theme
    local fs
    if type(size) == "number" then
        fs = size
    elseif size == "small" then
        fs = T.fontSizeSmall
    elseif size == "large" then
        fs = T.fontSizeLarge
    else
        fs = T.fontSizeNormal
    end
    local fo = T.fontOutline
    if fo == "NONE" then fo = "" end
    fontString:SetFont(T.fontFace, fs, fo)
    fontString:SetShadowOffset(0, 0)
end

--- Return accent-colored text: "|cffFF008CKitn|r"
function ns:AccentText(text)
    local T = self.Theme
    local r = math.floor(T.accent[1] * 255)
    local g = math.floor(T.accent[2] * 255)
    local b = math.floor(T.accent[3] * 255)
    return format("|cff%02x%02x%02x%s|r", r, g, b, text)
end
