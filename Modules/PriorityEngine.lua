local _, ns = ...

local PriorityEngine = {}
ns.PriorityEngine = PriorityEngine

-- Build a lookup table: lowercase name -> priority index
local function buildPriorityLookup(priorityList)
    local lookup = {}
    for i, name in ipairs(priorityList) do
        lookup[name:lower()] = i
    end
    return lookup
end

--- Sort debuffed players by their position in the priority list.
--- Players not in the priority list sort to the end (alphabetical tiebreak).
function PriorityEngine:SortByPriority(debuffedPlayers)
    local db = ns.db
    if not db or not db.priorityList or #db.priorityList == 0 then
        return {}
    end

    local lookup = buildPriorityLookup(db.priorityList)
    local sorted = {}
    for i = 1, #debuffedPlayers do
        sorted[i] = debuffedPlayers[i]
    end

    table.sort(sorted, function(a, b)
        local prioA = lookup[a:lower()] or 999
        local prioB = lookup[b:lower()] or 999
        if prioA == prioB then
            return a:lower() < b:lower()
        end
        return prioA < prioB
    end)

    return sorted
end

--- Compute this healer's assigned target from the debuffed list.
--- Returns: targetName (string or nil), sortedList (table)
function PriorityEngine:ComputeAssignment(debuffedPlayers)
    local db = ns.db
    if not db or db.healerNumber < 1 or db.healerNumber > ns.MAX_HEALERS then
        return nil, {}
    end

    local sorted = self:SortByPriority(debuffedPlayers)
    return sorted[db.healerNumber], sorted
end

--- Compute all healer assignments for display/diagnostics.
--- Returns: assignments (table of healerNum -> name), sortedList (table)
function PriorityEngine:ComputeAllAssignments(debuffedPlayers)
    local sorted = self:SortByPriority(debuffedPlayers)
    local assignments = {}
    for i = 1, math.min(ns.MAX_HEALERS, #sorted) do
        assignments[i] = sorted[i]
    end
    return assignments, sorted
end
