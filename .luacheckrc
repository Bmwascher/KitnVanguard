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
    "CreateFrame", "UIParent", "Settings", "ColorPickerFrame", "GameTooltip",
    "SettingsPanel",
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
    "UnitIsGroupLeader", "UnitIsGroupAssistant",

    -- Chat / communication
    "C_ChatInfo",

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

    -- Class colors
    "RAID_CLASS_COLORS",

    -- Instance/encounter
    "IsEncounterInProgress", "GetInstanceInfo",

    -- Sound
    "PlaySound", "PlaySoundFile", "StopSound",

    -- Misc
    "LibStub", "ReloadUI", "GetTime",
    "UISpecialFrames",
    "print", "date",

    -- Encoding
    "strbyte", "strchar",

    -- ElvUI detection
    "ElvUI",

    -- Cell detection
    "Cell",
}
