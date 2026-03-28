local _, ns = ...

local DebuffDetector = {}
ns.DebuffDetector = DebuffDetector

local debuffedNames = {} -- current list of debuffed player names
local callbacks = {}     -- registered callback functions
local scanPending = false

function DebuffDetector:RegisterCallback(func)
    callbacks[#callbacks + 1] = func
end

local function fireCallbacks(assignedTarget, allAssignments)
    for _, func in ipairs(callbacks) do
        func(assignedTarget, allAssignments, debuffedNames)
    end
end

-- Scan a single unit for spell 1246502 with secret value guards
local function scanUnit(unitToken)
    if not UnitExists(unitToken) then
        return false
    end

    local i = 1
    while true do
        local auraData = C_UnitAuras.GetAuraDataByIndex(unitToken, i, "HARMFUL")
        if not auraData then
            break
        end

        -- Guard: skip if entire aura table is secret
        if not issecrettable(auraData) then
            local spellId = auraData.spellId
            -- Guard: only compare spellId if it's not secret
            if not issecretvalue(spellId) then
                if spellId == ns.SPELL_ID then
                    return true
                end
            end
        end

        i = i + 1
    end
    return false
end

-- Full raid scan: check all raid/party members for the debuff
local function scanAllUnits()
    local names = {}
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then
        return names
    end

    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and numMembers or (numMembers - 1)

    for i = 1, count do
        local unit = prefix .. i
        -- Skip UnitIsDead check: returns secret in combat, and dead
        -- players won't have the aura anyway
        if UnitExists(unit) then
            if scanUnit(unit) then
                local name = UnitName(unit)
                -- Player names are NOT secret for raid members
                if name and not issecretvalue(name) then
                    names[#names + 1] = name
                end
            end
        end
    end

    -- Check the player themselves in party mode
    if not IsInRaid() and UnitExists("player") then
        if scanUnit("player") then
            local name = UnitName("player")
            if name and not issecretvalue(name) then
                names[#names + 1] = name
            end
        end
    end

    return names
end

-- Re-compute debuff state and fire callbacks
local function processDebuffChange()
    scanPending = false

    local db = ns.db
    if not db or not db.enabled then
        return
    end

    debuffedNames = scanAllUnits()

    if #debuffedNames > 0 then
        local assignedTarget = ns.PriorityEngine:ComputeAssignment(debuffedNames)
        local assignments = ns.PriorityEngine:ComputeAllAssignments(debuffedNames)
        fireCallbacks(assignedTarget, assignments)
    else
        fireCallbacks(nil, {})
    end
end

-- Debounce: batch rapid UNIT_AURA events into one scan per frame
local function scheduleScan()
    if scanPending then
        return
    end
    scanPending = true
    C_Timer.After(0, processDebuffChange)
end

-- Event handler
local eventFrame = CreateFrame("Frame")

local function onEvent(_, event, unit)
    if event == "UNIT_AURA" then
        if not unit then return end
        -- Only scan raid/party unit changes
        if unit:match("^raid%d+$") or unit:match("^party%d+$") or unit == "player" then
            scheduleScan()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        scheduleScan()
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
    debuffedNames = {}
    fireCallbacks(nil, {})
end

-- Return current debuffed player names (for diagnostics)
function DebuffDetector:GetDebuffedNames()
    return debuffedNames
end

-- Simulate debuffs for /kv test (bypasses UNIT_AURA scanning)
function DebuffDetector:SimulateDebuffs(names)
    debuffedNames = names
    if #names > 0 then
        local assignedTarget = ns.PriorityEngine:ComputeAssignment(names)
        local assignments = ns.PriorityEngine:ComputeAllAssignments(names)
        fireCallbacks(assignedTarget, assignments)
    else
        fireCallbacks(nil, {})
    end
end
