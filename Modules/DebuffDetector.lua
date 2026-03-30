local _, ns = ...

local DebuffDetector = {}
ns.DebuffDetector = DebuffDetector

-- Persistent tracking: confirmed harmful+dispellable auras
-- Key: auraInstanceID, Value: { unit = "raidN", name = "PlayerName" }
local trackedAuras = {}

-- Temporary buffer: candidates collected during a 0.2s detection window
local windowCandidates = {} -- auraID -> { unit, name }

local callbacks = {}
local windowActive = false
local notifyPending = false

-- Encounter state
local encounterActive = false
-- Healer list built on ENCOUNTER_START: sorted by raid index for determinism
-- WA: aura_env.healers = {} built on ENCOUNTER_START
ns.healerList = {}

-- Cooldown: prevents re-triggering within 3s of a window opening
-- Mirrors the WA pattern: aura_env.last < now-3
-- Cleared after assignment (like WA clears aura_env.last in NS_ASSIGN_EVENT)
local lastWindowTime = nil

-- Constants
local COLLECTION_WINDOW = 0.2   -- seconds to batch simultaneous debuffs
local WINDOW_COOLDOWN = 3       -- seconds before a new window can open
local MASS_DISPEL_THRESHOLD = 15 -- skip assignment above this count

function DebuffDetector:RegisterCallback(func)
    callbacks[#callbacks + 1] = func
end

-- Count tracked auras (for debug output)
local function getTrackedCount()
    local count = 0
    for _ in pairs(trackedAuras) do
        count = count + 1
    end
    return count
end

-- Collect unique debuffed player names from tracked auras
local function getDebuffedNames()
    local seen = {}
    local names = {}
    for _, data in pairs(trackedAuras) do
        if not seen[data.name] then
            seen[data.name] = true
            names[#names + 1] = data.name
        end
    end
    return names
end

-- Build debuffed data array from tracked auras (for PriorityEngine)
local function getDebuffedData()
    local seen = {}
    local data = {}
    for _, entry in pairs(trackedAuras) do
        if not seen[entry.name] then
            seen[entry.name] = true
            data[#data + 1] = {
                name = entry.name,
                unit = entry.unit,
                raidIndex = entry.raidIndex or 99,
                isDwarf = entry.isDwarf or 0,
            }
        end
    end
    return data
end

-- Fire all registered callbacks with current assignment state
local function notifyCallbacks()
    notifyPending = false

    local debuffedData = getDebuffedData()
    local names = {}
    for i, d in ipairs(debuffedData) do
        names[i] = d.name
    end

    local assignedTarget, allAssignments

    if #names > MASS_DISPEL_THRESHOLD then
        -- WA: if #aura_env.affected > 15 then return end
        allAssignments = {}
        if ns.debugMode then
            print(format("[KV] %d debuffed > %d threshold, skipping (mass dispel)",
                #names, MASS_DISPEL_THRESHOLD))
        end
    elseif #names > 0 and #ns.healerList > 0 then
        -- Use two-pass assignment with healer list (encounter mode)
        local assignments
        assignments, assignedTarget = ns.PriorityEngine:ComputeAssignments(
            ns.healerList, debuffedData)
        -- Build allAssignments as name array for compatibility
        allAssignments = {}
        for i, entry in pairs(assignments) do
            allAssignments[i] = entry.name
        end
    elseif #names > 0 then
        -- Fallback: legacy assignment by healer number (no encounter / /kv test)
        assignedTarget = ns.PriorityEngine:ComputeAssignment(names)
        allAssignments = ns.PriorityEngine:ComputeAllAssignments(names)
    else
        allAssignments = {}
    end

    for _, func in ipairs(callbacks) do
        func(assignedTarget, allAssignments, names)
    end
end

-- Called when the 0.2s collection window closes
-- WA equivalent: C_Timer.After(0.2, function() M33kAuras.ScanEvents("NS_ASSIGN_EVENT") end)
local function onWindowClose()
    windowActive = false
    -- Clear cooldown so next burst can trigger (WA: aura_env.last = nil)
    lastWindowTime = nil

    -- Move all candidates into tracked auras
    for auraId, data in pairs(windowCandidates) do
        trackedAuras[auraId] = data
    end

    local candidateCount = 0
    for _ in pairs(windowCandidates) do
        candidateCount = candidateCount + 1
    end
    wipe(windowCandidates)

    if ns.debugMode and candidateCount > 0 then
        print(format("[KV] Window closed: %d candidates -> tracked: %d",
            candidateCount, getTrackedCount()))
    end

    -- WA: if #aura_env.affected > 15 then return end
    notifyCallbacks()
end

-- Debounced notification for removals (next frame, skipped if window active)
local function scheduleNotify()
    if windowActive then
        return
    end
    if notifyPending then
        return
    end
    notifyPending = true
    C_Timer.After(0, notifyCallbacks)
end

-- Check if an aura is a candidate for tracking.
-- WA equivalent detection chain:
--   local isDebuff = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HARMFUL")
--   if isDebuff then if auraData.dispelName ~= nil then ...
local function isCandidate(unit, auraData)
    local auraId = auraData.auraInstanceID
    if issecretvalue(auraId) then
        return false, nil
    end

    -- Already tracked or already collected this window
    if trackedAuras[auraId] or windowCandidates[auraId] then
        return false, nil
    end

    -- Check harmful via IsAuraFilteredOutByInstanceID (no pcall — matches WA)
    -- Returns false when aura IS harmful (not filtered out by HARMFUL filter)
    local isHarmful = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraId, "HARMFUL")
    if not isHarmful then
        return false, nil
    end

    -- Must be dispellable (secret dispelName is not nil)
    -- WA: if auraData.dispelName ~= nil then
    if auraData.dispelName == nil then
        return false, nil
    end

    -- Outside instances: skip known helpful buffs as extra safety
    local harm = auraData.isHarmful
    if not issecretvalue(harm) and harm == false then
        return false, nil
    end

    -- Optional spell ID filter (only when spellId is readable)
    if #ns.SPELL_IDS > 0 then
        local spellId = auraData.spellId
        if not issecretvalue(spellId) and not ns.TRACKED_SPELLS[spellId] then
            return false, nil
        end
    end

    return true, auraId
end

-- Process a single UNIT_AURA event
local function processUnitAura(unit, info)
    if not info then
        return
    end

    -- Only active during boss encounters (WA: gated by ENCOUNTER_START/END)
    if not encounterActive then
        return
    end

    local db = ns.db
    if not db or not db.enabled then
        return
    end

    -- Deduplicate: in a raid, only process raidN units
    if IsInRaid() then
        if not unit:match("^raid%d+$") then
            return
        end
    else
        if not (unit:match("^party%d+$") or unit == "player") then
            return
        end
    end

    local addedCount = 0
    local removedCount = 0

    -- Full update: validate tracked auras still exist using GetUnitAuraInstanceIDs
    -- WA: C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HARMFUL") to check which are still present
    if info.isFullUpdate and next(trackedAuras) then
        local currentIds = C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HARMFUL")
        local stillExists = {}
        if currentIds then
            for _, auraInstanceID in ipairs(currentIds) do
                if trackedAuras[auraInstanceID] then
                    stillExists[auraInstanceID] = true
                end
            end
        end
        -- Remove tracked auras for this unit that no longer exist
        local cleared = 0
        for id, data in pairs(trackedAuras) do
            if data.unit == unit and not stillExists[id] then
                trackedAuras[id] = nil
                cleared = cleared + 1
            end
        end
        -- Also clean candidates for this unit
        for id, data in pairs(windowCandidates) do
            if data.unit == unit then
                windowCandidates[id] = nil
            end
        end
        if ns.debugMode and cleared > 0 then
            print(format("[KV] FULL_UPDATE %s removed %d stale | tracked: %d",
                unit, cleared, getTrackedCount()))
        end
    end

    -- Process added auras
    -- WA: for i, auraData in ipairs(updateInfo.addedAuras) do ...
    if info.addedAuras then
        for _, auraData in ipairs(info.addedAuras) do
            local candidate, auraId = isCandidate(unit, auraData)
            if candidate then
                local name = ns:GetFullUnitName(unit)
                if name then
                    -- WA stores: {unit, index, auraInstanceID, assigned, isdwarf}
                    local raidIndex = UnitInRaid(unit) or 99
                    local raceId = select(3, UnitRace(unit))
                    local isDwarf = (raceId == 3 or raceId == 34) and 1 or 0
                    windowCandidates[auraId] = {
                        unit = unit,
                        name = name,
                        raidIndex = raidIndex,
                        isDwarf = isDwarf,
                    }
                    addedCount = addedCount + 1
                    if ns.debugMode then
                        local sid = auraData.spellId
                        local sidStr = issecretvalue(sid) and "SECRET" or tostring(sid)
                        print(format("[KV] +CANDIDATE %s (%s) spell=%s id=%d",
                            unit, name, sidStr, auraId))
                    end
                end
            end
        end
    end

    -- Process removed auras
    -- WA: for i, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do ...
    if info.removedAuraInstanceIDs then
        for _, id in ipairs(info.removedAuraInstanceIDs) do
            if trackedAuras[id] then
                if ns.debugMode then
                    local d = trackedAuras[id]
                    print(format("[KV] -DEBUFF %s (%s) id=%d | tracked: %d",
                        d.unit, d.name, id, getTrackedCount() - 1))
                end
                trackedAuras[id] = nil
                removedCount = removedCount + 1
            end
            windowCandidates[id] = nil
        end
    end

    -- Start collection window with cooldown check
    -- WA: if not aura_env.last or aura_env.last < now-3 then
    if addedCount > 0 and not windowActive then
        local now = GetTime()
        if not lastWindowTime or (now - lastWindowTime) >= WINDOW_COOLDOWN then
            windowActive = true
            lastWindowTime = now
            C_Timer.After(COLLECTION_WINDOW, onWindowClose)
            if ns.debugMode then
                print("[KV] Collection window opened")
            end
        end
    end

    -- Notify on removals
    if removedCount > 0 then
        if not next(trackedAuras) then
            scheduleNotify()
        elseif ns.db.reassignAfterDispel then
            scheduleNotify()
        end
    end
end

-- Build healer list on encounter start, sorted by raid index for determinism.
-- WA: aura_env.healers = {} ... for unit in WA_IterateGroupMembers() do
--   if UnitGroupRolesAssigned(unit) == "HEALER" then table.insert(aura_env.healers, unit) end
-- Then adds warlocks (class 9) after healers.
local function buildHealerList()
    local healers = {}
    local warlocks = {}
    local numMembers = GetNumGroupMembers()

    for i = 1, numMembers do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local role = UnitGroupRolesAssigned(unit)
            if not issecretvalue(role) and role == "HEALER" then
                local raidIdx = UnitInRaid(unit) or 99
                healers[#healers + 1] = { unit = unit, raidIndex = raidIdx }
            end
            -- Warlocks (class 9) as backup dispellers (Imp Singe Magic)
            if ns.db.includeWarlocks then
                local _, _, classId = UnitClass(unit)
                if classId == 9 then
                    local raidIdx = UnitInRaid(unit) or 99
                    warlocks[#warlocks + 1] = { unit = unit, raidIndex = raidIdx }
                end
            end
        end
    end

    -- Sort by raid index for cross-client determinism
    table.sort(healers, function(a, b) return a.raidIndex < b.raidIndex end)
    table.sort(warlocks, function(a, b) return a.raidIndex < b.raidIndex end)

    -- Build final list: healers first, then warlocks (WA pattern)
    local result = {}
    for _, h in ipairs(healers) do
        result[#result + 1] = h.unit
    end
    for _, w in ipairs(warlocks) do
        result[#result + 1] = w.unit
    end

    -- If player has a manual healer number but isn't in the list, insert them
    -- (allows testing without healer spec)
    local db = ns.db
    if db and db.healerNumber > 0 then
        local playerInList = false
        for _, unit in ipairs(result) do
            if UnitIsUnit(unit, "player") then
                playerInList = true
                break
            end
        end
        if not playerInList then
            -- Find player's raid unit token
            local playerUnit = nil
            for i = 1, GetNumGroupMembers() do
                local unit = "raid" .. i
                if UnitExists(unit) and UnitIsUnit(unit, "player") then
                    playerUnit = unit
                    break
                end
            end
            if playerUnit then
                local pos = math.min(db.healerNumber, #result + 1)
                table.insert(result, pos, playerUnit)
            end
        end
    end

    ns.healerList = result

    if ns.debugMode then
        local names = {}
        for idx, unit in ipairs(result) do
            names[idx] = ns:GetFullUnitName(unit) or unit
        end
        print(format("[KV] Healer list (%d): %s", #result, table.concat(names, ", ")))
    end
end

-- Clear all state
local function clearAll()
    wipe(trackedAuras)
    wipe(windowCandidates)
    windowActive = false
    lastWindowTime = nil
    notifyPending = false
end

-- Event handler
local eventFrame = CreateFrame("Frame")

local function onEvent(_, event, ...)
    if event == "UNIT_AURA" then
        local unit, info = ...
        if unit then
            processUnitAura(unit, info)
        end
    elseif event == "ENCOUNTER_START" then
        -- WA: elseif e == "ENCOUNTER_START" then
        encounterActive = true
        clearAll()
        buildHealerList()
        if ns.debugMode then
            local encounterID, encounterName = ...
            print(format("[KV] ENCOUNTER_START: %s (id=%s)",
                tostring(encounterName), tostring(encounterID)))
        end
    elseif event == "ENCOUNTER_END" then
        -- WA: elseif e == "ENCOUNTER_END" then s:RemoveAll()
        encounterActive = false
        local hadTracked = next(trackedAuras) ~= nil
        clearAll()
        if hadTracked then
            notifyCallbacks() -- clear glows
        end
        if ns.debugMode then
            local _, encounterName, _, _, success = ...
            print(format("[KV] ENCOUNTER_END: %s (%s)",
                tostring(encounterName), success == 1 and "kill" or "wipe"))
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if next(trackedAuras) then
            wipe(trackedAuras)
            scheduleNotify()
        end
        wipe(windowCandidates)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Safety net: clear tracking if combat ends without ENCOUNTER_END
        if next(trackedAuras) then
            wipe(trackedAuras)
            notifyCallbacks()
        end
        wipe(windowCandidates)
        windowActive = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Reconnect / mid-fight join: if we zoned into an active encounter,
        -- activate detection and rebuild healer list
        if IsEncounterInProgress() then
            encounterActive = true
            clearAll()
            buildHealerList()
            if ns.debugMode then
                ns:Print("Reconnected into active encounter — detection enabled")
            end
        end
    end
end

function DebuffDetector:Initialize()
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", onEvent)
end

function DebuffDetector:Disable()
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    encounterActive = false
    clearAll()
    notifyCallbacks()
end

-- Return current debuffed player names (for diagnostics)
function DebuffDetector:GetDebuffedNames()
    return getDebuffedNames()
end

-- Is encounter currently active? (for diagnostics)
function DebuffDetector:IsEncounterActive()
    return encounterActive
end

-- Simulate debuffs for /kv test (bypasses detection, directly fires callbacks)
function DebuffDetector:SimulateDebuffs(names)
    local assignedTarget, allAssignments
    if #names > 0 then
        assignedTarget = ns.PriorityEngine:ComputeAssignment(names)
        allAssignments = ns.PriorityEngine:ComputeAllAssignments(names)
    else
        allAssignments = {}
    end

    for _, func in ipairs(callbacks) do
        func(assignedTarget, allAssignments, names)
    end
end
