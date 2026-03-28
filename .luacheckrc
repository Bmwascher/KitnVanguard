-- Luacheck configuration for KitnVanguard addon
std = "lua51"
max_line_length = false
self = false
exclude_files = {
    "Libs/**",
    ".wow-api-reference/**",
}

-- Globals this addon sets
globals = {
    "SLASH_KITNVANGUARD1",
    "SLASH_KITNVANGUARD2",
    "SlashCmdList",
    "KitnVanguardDB",
}

-- WoW API globals this addon reads
read_globals = {
    -- Core Lua extensions in WoW
    "strsplit", "strjoin", "strtrim", "format", "tinsert", "tremove",
    "wipe", "CopyTable", "tContains", "strsub", "strlen",

    -- Frame and UI
    "CreateFrame", "UIParent", "Settings",
    "BackdropTemplateMixin",
    "CompactRaidFrameContainer",
    "EnumerateFrames",

    -- Unit functions
    "UnitHealth", "UnitHealthMax", "UnitHealthPercent",
    "UnitPower", "UnitPowerMax", "UnitPowerPercent",
    "UnitName", "UnitLevel", "UnitClass", "UnitRace",
    "UnitGUID", "UnitExists", "UnitIsDead", "UnitIsUnit",
    "UnitGroupRolesAssigned",
    "InCombatLockdown",

    -- Raid and group
    "IsInRaid", "IsInGroup", "GetNumGroupMembers",
    "UnitInRaid", "UnitInParty",

    -- Auras (critical for this addon)
    "C_UnitAuras",

    -- Addon management
    "GetAddOnMemoryUsage", "UpdateAddOnMemoryUsage",
    "C_AddOns",

    -- Timer
    "C_Timer",

    -- Secret Values (12.0)
    "issecretvalue", "issecrettable", "canaccesstable",
    "secretwrap", "dropsecretaccess",
    "GetRestrictedActionStatus",
    "C_Secrets", "C_RestrictedActions",

    -- Glow APIs
    "ActionButton_ShowOverlayGlow",
    "ActionButton_HideOverlayGlow",

    -- Misc
    "LibStub", "ReloadUI",
    "print", "date",

    -- Encoding
    "strbyte", "strchar",

    -- ElvUI detection
    "ElvUI",

    -- Cell detection
    "Cell",
}
