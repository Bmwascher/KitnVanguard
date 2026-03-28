local _, ns = ...

local SlashCommands = {}
ns.SlashCommands = SlashCommands

local Commands = {}
local IMPORT_VERSION = "v1"

-- ============================================================
-- /kv help
-- ============================================================
Commands["help"] = function()
    print("|cff00ccff=== KitnVanguard Commands ===|r")
    print("  |cffaaaaaa/kv import <string>|r -- Import priority list")
    print("  |cffaaaaaa/kv export|r -- Export priority list as string")
    print("  |cffaaaaaa/kv healer <1-5>|r -- Set your healer number")
    print("  |cffaaaaaa/kv priority|r -- Show current priority list")
    print("  |cffaaaaaa/kv test|r -- Simulate debuffs and show assignments")
    print("  |cffaaaaaa/kv clear|r -- Clear glow overlays")
    print("  |cffaaaaaa/kv status|r -- Show addon status")
    print("  |cffaaaaaa/kv diag|r -- Full diagnostics")
end

-- ============================================================
-- /kv import <string>
-- ============================================================
Commands["import"] = function(rest)
    if not rest or rest == "" then
        ns:PrintError("Usage: /kv import <priority string>")
        ns:Print("Format: v1:Name1|Name2|Name3|...")
        return
    end

    -- Parse optional version prefix
    local version, data = rest:match("^(v%d+):(.+)$")
    if not version then
        -- Accept strings without version prefix
        data = rest
    elseif version ~= IMPORT_VERSION then
        ns:PrintError("Unsupported import version: " .. version)
        ns:Print("Expected: " .. IMPORT_VERSION)
        return
    end

    -- Split pipe-delimited names
    local parts = { strsplit("|", data) }
    local priorityList = {}
    for _, name in ipairs(parts) do
        name = strtrim(name)
        if name ~= "" then
            priorityList[#priorityList + 1] = name
        end
    end

    if #priorityList == 0 then
        ns:PrintError("No valid names found in import string.")
        return
    end

    ns.db.priorityList = priorityList
    ns:Print("Imported " .. #priorityList .. " players in priority order:")
    for i, name in ipairs(priorityList) do
        print(format("  |cffaaaaaa%2d.|r %s", i, name))
    end
end

-- ============================================================
-- /kv export
-- ============================================================
Commands["export"] = function()
    local db = ns.db
    if not db.priorityList or #db.priorityList == 0 then
        ns:PrintError("No priority list configured. Import one first with /kv import")
        return
    end

    local exportStr = IMPORT_VERSION .. ":" .. table.concat(db.priorityList, "|")
    ns:Print("Export string (copy and share):")
    print(exportStr)
end

-- ============================================================
-- /kv healer <1-5>
-- ============================================================
Commands["healer"] = function(rest)
    if not rest or rest == "" then
        local current = ns.db.healerNumber
        if current > 0 then
            ns:Print("You are healer #" .. current)
        else
            ns:Print("Healer number not set. Use: /kv healer <1-5>")
        end
        return
    end

    local num = tonumber(rest)
    if not num or num < 1 or num > ns.MAX_HEALERS or num ~= math.floor(num) then
        ns:PrintError("Healer number must be 1-" .. ns.MAX_HEALERS)
        return
    end

    ns.db.healerNumber = num
    ns:Print("You are now healer #" .. num)
end

-- ============================================================
-- /kv priority
-- ============================================================
Commands["priority"] = function()
    local db = ns.db
    if not db.priorityList or #db.priorityList == 0 then
        ns:PrintError("No priority list configured. Import one with /kv import")
        return
    end

    ns:Print("Priority list (" .. #db.priorityList .. " players):")
    for i, name in ipairs(db.priorityList) do
        print(format("  |cffaaaaaa%2d.|r %s", i, name))
    end
end

-- ============================================================
-- /kv test
-- ============================================================
Commands["test"] = function()
    local db = ns.db
    if not db.priorityList or #db.priorityList == 0 then
        ns:PrintError("No priority list configured. Import one first with /kv import")
        return
    end

    if db.healerNumber < 1 or db.healerNumber > ns.MAX_HEALERS then
        ns:PrintError("Healer number not set. Use /kv healer <1-5> first.")
        return
    end

    -- Pick 8 random players from priority list (or fewer if list is short)
    local pool = {}
    for i, name in ipairs(db.priorityList) do
        pool[i] = name
    end

    -- Fisher-Yates shuffle
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local debuffCount = math.min(8, #pool)
    local debuffed = {}
    for i = 1, debuffCount do
        debuffed[i] = pool[i]
    end

    ns:Print("=== TEST: Simulating " .. debuffCount .. " debuffs ===")
    print("  Debuffed: " .. table.concat(debuffed, ", "))

    local assignments, sorted = ns.PriorityEngine:ComputeAllAssignments(debuffed)
    print("  Sorted by priority: " .. table.concat(sorted, ", "))

    ns:Print("Assignments:")
    for i = 1, ns.MAX_HEALERS do
        local marker = (i == db.healerNumber) and " |cff00ff00<< YOU|r" or ""
        if assignments[i] then
            print(format("  Healer #%d -> |cffffff00%s|r%s", i, assignments[i], marker))
        else
            print(format("  Healer #%d -> |cff888888(no target)|r%s", i, marker))
        end
    end

    if debuffCount > ns.MAX_HEALERS then
        ns:Print("Unassigned (" .. (debuffCount - ns.MAX_HEALERS) .. " players):")
        for i = ns.MAX_HEALERS + 1, #sorted do
            print("  " .. sorted[i])
        end
    end

    -- Trigger visual glow via simulation
    ns.DebuffDetector:SimulateDebuffs(debuffed)
    if not IsInRaid() and not IsInGroup() then
        ns:Print("Note: Glow overlay requires visible raid frames in a group.")
    end
end

-- ============================================================
-- /kv clear
-- ============================================================
Commands["clear"] = function()
    ns.GlowManager:RemoveAllGlows()
    ns:Print("Glows cleared.")
end

-- ============================================================
-- /kv status
-- ============================================================
Commands["status"] = function()
    local db = ns.db
    ns:Print("=== Status ===")
    print("  Enabled: " .. (db.enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print("  Healer #: " .. (db.healerNumber > 0 and tostring(db.healerNumber) or "|cffff6060Not set|r"))
    print("  Priority list: " .. #db.priorityList .. " players")
    print("  Frame library: LibGetFrame")

    local debuffed = ns.DebuffDetector:GetDebuffedNames()
    print("  Currently debuffed: " .. #debuffed)
    if #debuffed > 0 then
        print("  Debuffed: " .. table.concat(debuffed, ", "))
    end
end

-- ============================================================
-- /kv diag
-- ============================================================
Commands["diag"] = function()
    local db = ns.db
    print("|cff00ccff=== KitnVanguard Diagnostics ===|r")

    local version = C_AddOns.GetAddOnMetadata(ns.ADDON_NAME, "Version") or "dev"
    print("  Version: " .. version)

    UpdateAddOnMemoryUsage()
    local mem = GetAddOnMemoryUsage(ns.ADDON_NAME)
    print(format("  Memory: %.1f KB", mem))

    print("  Combat: " .. (InCombatLockdown() and "|cffff0000YES|r" or "|cff00ff00No|r"))
    print("  In raid: " .. (IsInRaid() and ("Yes (" .. GetNumGroupMembers() .. " members)") or "No"))
    print("  In group: " .. (IsInGroup() and "Yes" or "No"))

    print("  Healer #: " .. (db.healerNumber > 0 and tostring(db.healerNumber) or "NOT SET"))
    print("  Priority list: " .. #db.priorityList .. " players")
    print("  Spell ID: " .. ns.SPELL_ID)
    print("  Frame library: LibGetFrame")

    local debuffed = ns.DebuffDetector:GetDebuffedNames()
    print("  Active debuffs: " .. #debuffed)

    -- Readiness check
    local ready = true
    if #db.priorityList == 0 then
        print("  |cffff6060WARNING:|r No priority list imported")
        ready = false
    end
    if db.healerNumber < 1 then
        print("  |cffff6060WARNING:|r Healer number not set")
        ready = false
    end
    if ready then
        print("  |cff00ff00Ready for encounter|r")
    end
end

-- ============================================================
-- Slash command router
-- ============================================================
function SlashCommands:Initialize()
    SLASH_KITNVANGUARD1 = "/kv"
    SLASH_KITNVANGUARD2 = "/kitnvanguard"
    SlashCmdList["KITNVANGUARD"] = function(msg)
        local cmd, rest = msg:match("^(%S+)%s*(.-)$")
        cmd = cmd and cmd:lower() or ""

        if cmd == "" or cmd == "help" then
            Commands["help"]()
        elseif Commands[cmd] then
            Commands[cmd](rest)
        else
            ns:PrintError("Unknown command: " .. cmd)
            ns:Print("Type /kv help for a list of commands.")
        end
    end
end
