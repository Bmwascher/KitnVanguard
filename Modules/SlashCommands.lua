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
    print("  |cffaaaaaa/kv config|r -- Open settings GUI")
    print("  |cffaaaaaa/kv scan|r -- Build priority list from raid roster")
    print("  |cffaaaaaa/kv sync|r -- Sync priority list to raid (leader/assist)")
    print("  |cffaaaaaa/kv who|r -- Show who has KitnVanguard installed")
    print("  |cffaaaaaa/kv status|r -- Show addon status")
    print("  |cffaaaaaa/kv clear|r -- Clear glow overlays")
    if ns.debugMode then
        print("|cff00ccff--- Debug ------|r")
        print("  |cffaaaaaa/kv debug|r -- Toggle verbose UNIT_AURA logging")
        print("  |cffaaaaaa/kv debugaura|r -- Raw UNIT_AURA sniffer for raid units")
        print("  |cffaaaaaa/kv diag|r -- Full diagnostics")
        print("  |cffaaaaaa/kv test|r -- Simulate debuffs and show assignments")
        print("  |cffaaaaaa/kv testglow|r -- Glow your own frame for 5 seconds")
        print("  |cffaaaaaa/kv import <string>|r -- Import priority list")
        print("  |cffaaaaaa/kv export|r -- Export priority list as string")
        print("  |cffaaaaaa/kv swap <a> <b>|r -- Swap two priority positions")
        print("  |cffaaaaaa/kv healer <1-5>|r -- Set healer override")
        print("  |cffaaaaaa/kv reassign|r -- Toggle reassignment after dispel")
    end
end

-- ============================================================
-- /kv config
-- ============================================================
Commands["config"] = function()
    if ns.ConfigFrame then
        ns.ConfigFrame:Toggle()
    end
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
-- /kv scan
-- ============================================================
Commands["scan"] = function()
    if not IsInRaid() then
        ns:PrintError("Must be in a raid to scan roster.")
        return
    end

    local db = ns.db
    local numMembers = GetNumGroupMembers()
    local roster = {}

    -- Build role order lookup from SavedVariables
    local roleSortOrder = {}
    for idx, role in ipairs(db.scanRoleOrder) do
        roleSortOrder[role] = idx
    end
    roleSortOrder["NONE"] = #db.scanRoleOrder + 1

    -- Build class order lookup from SavedVariables
    local classSortOrder = {}
    for idx, classId in ipairs(db.scanClassOrder) do
        classSortOrder[classId] = idx
    end

    for i = 1, numMembers do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local name = ns:GetFullUnitName(unit)
            local role = UnitGroupRolesAssigned(unit)

            if name then
                local roleKey = role
                if issecretvalue(role) then
                    roleKey = "NONE"
                end
                -- Get class ID for class-based sorting
                local _, _, classId = UnitClass(unit)
                roster[#roster + 1] = {
                    name = name,
                    role = roleKey,
                    classId = classId or 0,
                }
            end
        end
    end

    if #roster == 0 then
        ns:PrintError("No raid members found.")
        return
    end

    -- Sort by: role order -> class order within role -> alphabetical
    table.sort(roster, function(a, b)
        local roleA = roleSortOrder[a.role] or 99
        local roleB = roleSortOrder[b.role] or 99
        if roleA ~= roleB then
            return roleA < roleB
        end
        local classA = classSortOrder[a.classId] or 99
        local classB = classSortOrder[b.classId] or 99
        if classA ~= classB then
            return classA < classB
        end
        return a.name:lower() < b.name:lower()
    end)

    local priorityList = {}
    for i, entry in ipairs(roster) do
        priorityList[i] = entry.name
    end

    db.priorityList = priorityList
    ns:Print("Scanned " .. #priorityList .. " raid members (sorted by role + class priority):")
    local roleColors = { TANK = "|cff5599ff", DAMAGER = "|cffff5555", HEALER = "|cff55ff55", NONE = "|cffaaaaaa" }
    for i, entry in ipairs(roster) do
        local c = roleColors[entry.role] or "|cffaaaaaa"
        print(format("  |cffaaaaaa%2d.|r %s%s|r", i, c, entry.name))
    end
    ns:Print("Use /kv swap <a> <b> to rearrange, then /kv export to share.")
end

-- ============================================================
-- /kv sync
-- ============================================================
Commands["sync"] = function()
    if ns.Sync then
        ns.Sync:Broadcast()
    end
end

-- ============================================================
-- /kv who
-- ============================================================
Commands["who"] = function()
    if ns.Sync then
        ns.Sync:PrintStatus()
    end
end

-- ============================================================
-- /kv swap <a> <b>
-- ============================================================
Commands["swap"] = function(rest)
    local db = ns.db
    if not db.priorityList or #db.priorityList == 0 then
        ns:PrintError("No priority list configured. Use /kv scan or /kv import first.")
        return
    end

    if not rest or rest == "" then
        ns:PrintError("Usage: /kv swap <a> <b>  (e.g. /kv swap 1 3)")
        return
    end

    local a, b = rest:match("^(%d+)%s+(%d+)$")
    if not a then
        ns:PrintError("Usage: /kv swap <a> <b>  (e.g. /kv swap 1 3)")
        return
    end

    a, b = tonumber(a), tonumber(b)
    local listLen = #db.priorityList

    if a < 1 or a > listLen or b < 1 or b > listLen then
        ns:PrintError("Positions must be between 1 and " .. listLen)
        return
    end

    if a == b then
        ns:Print("Nothing to swap.")
        return
    end

    local nameA = db.priorityList[a]
    local nameB = db.priorityList[b]
    db.priorityList[a] = nameB
    db.priorityList[b] = nameA
    ns:Print("Swapped #" .. a .. " (" .. nameA .. ") and #" .. b .. " (" .. nameB .. ")")
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

    if db.healerNumber < 1 and #ns.healerList == 0 then
        ns:PrintError("No healer list available. Pull a boss or set a healer override.")
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
-- /kv testglow
-- ============================================================
Commands["testglow"] = function()
    local success = ns.GlowManager:TestGlow(5)
    if success then
        ns:Print("Glowing your frame for 5 seconds...")
    else
        ns:PrintError("Could not find your raid frame. Are raid/party frames visible?")
    end
end

-- ============================================================
-- /kv reassign
-- ============================================================
Commands["reassign"] = function()
    ns.db.reassignAfterDispel = not ns.db.reassignAfterDispel
    if ns.db.reassignAfterDispel then
        ns:Print("Reassign after dispel: |cff00ff00ON|r (glow moves to next target)")
    else
        ns:Print("Reassign after dispel: |cffff0000OFF|r (glow stays until wave is over)")
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
-- /kv debugaura — raw UNIT_AURA sniffer for raid units
-- ============================================================
local debugAuraFrame = CreateFrame("Frame")
local debugAuraActive = false

debugAuraFrame:SetScript("OnEvent", function(_, _, unit, info)
    if not unit or not unit:match("^raid%d+$") then
        return
    end

    local hasInfo = info ~= nil
    local hasAdded = hasInfo and info.addedAuras ~= nil
    local isFull = hasInfo and info.isFullUpdate

    if not hasAdded and not isFull then
        -- Only print events that have addedAuras or are full updates
        return
    end

    if hasAdded then
        -- Collect harmful/secret entries first, only print if any exist
        local lines = {}
        for i, aura in ipairs(info.addedAuras) do
            local sid = aura.spellId
            local sname = aura.name
            local harmful = aura.isHarmful
            local sidSecret = issecretvalue(sid)
            local harmSecret = issecretvalue(harmful)
            -- Only show: secret spellId, secret isHarmful, or isHarmful == true
            if sidSecret or harmSecret or harmful == true then
                local sidStr = sidSecret and "SECRET" or tostring(sid)
                local nameStr = issecretvalue(sname) and "SECRET" or tostring(sname)
                local harmStr = harmSecret and "SECRET" or tostring(harmful)
                local tracked = (not sidSecret and ns.TRACKED_SPELLS[sid]) and " |cff00ff00<< TRACKED|r" or ""
                lines[#lines + 1] = format("  [%d] spellId=%s name=%s isHarmful=%s%s",
                    i, sidStr, nameStr, harmStr, tracked)
            end
        end
        if #lines == 0 then
            return
        end
        print(format("[KV-SNIFF] %s addedAuras=%d isFullUpdate=%s",
            unit, #info.addedAuras, tostring(isFull)))
        for _, line in ipairs(lines) do
            print(line)
        end
    end
end)

Commands["debugaura"] = function()
    debugAuraActive = not debugAuraActive
    if debugAuraActive then
        debugAuraFrame:RegisterEvent("UNIT_AURA")
        ns:Print("Aura sniffer |cff00ff00ON|r - printing raw UNIT_AURA data for raid units")
        ns:Print("Do a boss pull, then /kv debugaura again to stop.")
    else
        debugAuraFrame:UnregisterAllEvents()
        ns:Print("Aura sniffer |cffff0000OFF|r")
    end
end

-- ============================================================
-- /kv debug
-- ============================================================
Commands["debug"] = function()
    ns.debugMode = not ns.debugMode
    if ns.debugMode then
        ns:Print("Debug mode |cff00ff00ON|r - logging UNIT_AURA events for spells: " ..
            table.concat(ns.SPELL_IDS, ", "))
    else
        ns:Print("Debug mode |cffff0000OFF|r")
    end
end

-- ============================================================
-- /kv status
-- ============================================================
Commands["status"] = function()
    local db = ns.db
    ns:Print("=== Status ===")
    print("  Enabled: " .. (db.enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    if db.healerNumber > 0 then
        print("  Healer: |cffffff00Override #" .. db.healerNumber .. "|r")
    else
        print("  Healer: |cff00ff00Auto|r (detected from raid)")
    end
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

    if db.healerNumber > 0 then
        print("  Healer: Override #" .. db.healerNumber)
    else
        print("  Healer: Auto (" .. #ns.healerList .. " in list)")
    end
    print("  Priority list: " .. #db.priorityList .. " players")
    print("  Spell IDs: " .. table.concat(ns.SPELL_IDS, ", "))
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
