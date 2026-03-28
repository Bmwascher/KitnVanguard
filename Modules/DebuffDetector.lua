local _, ns = ...

local DebuffDetector = {}
ns.DebuffDetector = DebuffDetector

-- Track debuffed players by auraInstanceID.
-- Key: auraInstanceID (number), Value: { unit = "raidN", name = "PlayerName" }
-- This avoids GetAuraDataByIndex entirely — its fields are secret inside instances.
local trackedAuras = {}
local callbacks = {}
local notifyPending = false

function DebuffDetector:RegisterCallback(func)
    callbacks[#callbacks + 1] = func
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

-- Fire all registered callbacks with current assignment state
local function notifyCallbacks()
    notifyPending = false

    local names = getDebuffedNames()
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

-- Debounced notification: batch rapid UNIT_AURA events into one callback per frame
local function scheduleNotify()
    if notifyPending then
        return
    end
    notifyPending = true
    C_Timer.After(0, notifyCallbacks)
end

-- Process a UNIT_AURA event using the info payload.
-- info.addedAuras contains clean, non-secret AuraData entries.
-- info.removedAuraInstanceIDs lists auras that were dispelled/expired.
local function processUnitAura(unit, info)
    if not info then
        return
    end

    local db = ns.db
    if not db or not db.enabled then
        return
    end

    -- Only process raid/party units
    if not (unit:match("^raid%d+$") or unit:match("^party%d+$") or unit == "player") then
        return
    end

    local changed = false

    -- Full update: clear tracked auras for this unit first.
    -- addedAuras will contain ALL current auras for the unit.
    if info.isFullUpdate then
        for id, data in pairs(trackedAuras) do
            if data.unit == unit then
                trackedAuras[id] = nil
                changed = true
            end
        end
    end

    -- Process newly added auras — these fields are NOT secret in the event payload
    if info.addedAuras then
        for _, auraData in ipairs(info.addedAuras) do
            local spellId = auraData.spellId
            -- Defensive guard: verify spellId is accessible before comparing
            if not issecretvalue(spellId) and spellId == ns.SPELL_ID then
                local auraId = auraData.auraInstanceID
                if not issecretvalue(auraId) then
                    local name = UnitName(unit)
                    if name and not issecretvalue(name) then
                        trackedAuras[auraId] = {
                            unit = unit,
                            name = name,
                        }
                        changed = true
                    end
                end
            end
        end
    end

    -- Process removed auras (dispelled or expired)
    if info.removedAuraInstanceIDs then
        for _, id in ipairs(info.removedAuraInstanceIDs) do
            if trackedAuras[id] then
                trackedAuras[id] = nil
                changed = true
            end
        end
    end

    -- Only notify if tracking state actually changed
    if changed then
        scheduleNotify()
    end
end

-- Event handler
local eventFrame = CreateFrame("Frame")

local function onEvent(_, event, unit, info)
    if event == "UNIT_AURA" then
        if unit then
            processUnitAura(unit, info)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Unit tokens may shift on roster change; clear tracking.
        -- Subsequent UNIT_AURA full updates will rebuild it.
        if next(trackedAuras) then
            wipe(trackedAuras)
            scheduleNotify()
        end
    end
end

function DebuffDetector:Initialize()
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:SetScript("OnEvent", onEvent)
end

function DebuffDetector:Disable()
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    wipe(trackedAuras)
    notifyPending = false
    -- Fire one final callback to clear glows
    notifyCallbacks()
end

-- Return current debuffed player names (for diagnostics)
function DebuffDetector:GetDebuffedNames()
    return getDebuffedNames()
end

-- Simulate debuffs for /kv test (bypasses UNIT_AURA tracking)
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
