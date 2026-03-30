local _, ns = ...

local PriorityEngine = {}
ns.PriorityEngine = PriorityEngine

local UnitIsUnit = UnitIsUnit

-- Build a lookup table: lowercase name -> priority index
local function buildPriorityLookup(priorityList)
    local lookup = {}
    for i, name in ipairs(priorityList) do
        lookup[name:lower()] = i
    end
    return lookup
end

--- Sort debuffed players by: non-dwarves first, then priority list (or raid index fallback).
--- debuffedData: array of { name, unit, raidIndex, isDwarf } from DebuffDetector
--- Returns: sorted array of the same entries
function PriorityEngine:SortDebuffed(debuffedData)
    local db = ns.db
    local hasPriorityList = db and db.priorityList and #db.priorityList > 0
    local lookup = hasPriorityList and buildPriorityLookup(db.priorityList) or {}

    local sorted = {}
    for i = 1, #debuffedData do
        sorted[i] = debuffedData[i]
    end

    -- WA sort: if a[5] == b[5] then return a[2] < b[2] else return a[5] < b[5] end
    -- [5] = isDwarf (0 or 1), [2] = raidIndex
    table.sort(sorted, function(a, b)
        -- Dwarves sort last (they can Stoneform self-cleanse)
        if a.isDwarf ~= b.isDwarf then
            return a.isDwarf < b.isDwarf
        end
        -- Within same dwarf status: priority list or raid index
        if hasPriorityList then
            local prioA = lookup[a.name:lower()] or 999
            local prioB = lookup[b.name:lower()] or 999
            if prioA ~= prioB then
                return prioA < prioB
            end
        end
        -- Fallback: raid index (deterministic across all clients)
        return (a.raidIndex or 99) < (b.raidIndex or 99)
    end)

    return sorted
end

--- Two-pass healer assignment matching the WA pattern.
--- Pass 1: Healers who are debuffed get self-assigned (self-dispel is fastest).
--- Pass 2: Remaining healers get the next unassigned target in priority order.
---
--- healerList: array of unit tokens (from ns.healerList, built on ENCOUNTER_START)
--- debuffedData: array of { name, unit, raidIndex, isDwarf }
--- Returns: assignments table { [healerIndex] = debuffedEntry }, myAssignment (or nil)
function PriorityEngine:ComputeAssignments(healerList, debuffedData)
    local sorted = self:SortDebuffed(debuffedData)

    -- Track which healers and targets are assigned
    local healerAssigned = {}  -- healerIndex -> true
    local targetAssigned = {}  -- index in sorted -> true
    local assignments = {}     -- healerIndex -> sorted entry

    -- Pass 1: Self-dispel — if a healer is debuffed, assign them to themselves
    -- WA: for i, v in ipairs(aura_env.healers) do
    --       if not UnitIsDead(v) then for k, info in ipairs(affected) do
    --         if UnitIsUnit(info[1], v) then ... break end
    for i, healerUnit in ipairs(healerList) do
        if not UnitIsDead(healerUnit) then
            for k, entry in ipairs(sorted) do
                if not targetAssigned[k] and UnitIsUnit(entry.unit, healerUnit) then
                    assignments[i] = entry
                    healerAssigned[i] = true
                    targetAssigned[k] = true
                    break
                end
            end
        end
    end

    -- Pass 2: Remaining healers get next unassigned target
    -- WA: for i, v in ipairs(aura_env.healers) do
    --       if not UnitIsDead(v) and not healerassigned[i] then
    --         for k, info in ipairs(affected) do if not info[4] then ...
    for i, healerUnit in ipairs(healerList) do
        if not UnitIsDead(healerUnit) and not healerAssigned[i] then
            for k, entry in ipairs(sorted) do
                if not targetAssigned[k] then
                    assignments[i] = entry
                    healerAssigned[i] = true
                    targetAssigned[k] = true
                    break
                end
            end
        end
    end

    -- Find this player's assignment
    -- WA: if UnitIsUnit(v, "player") then ... show assignment
    local myAssignment = nil
    for i, healerUnit in ipairs(healerList) do
        if UnitIsUnit(healerUnit, "player") and assignments[i] then
            myAssignment = assignments[i].name
            break
        end
    end

    return assignments, myAssignment, sorted
end

--- Legacy API: simple sort-based assignment (used by /kv test and SimulateDebuffs)
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

--- Legacy API: compute assignment by healer number (for /kv test)
function PriorityEngine:ComputeAssignment(debuffedPlayers)
    local db = ns.db
    if not db or db.healerNumber < 1 or db.healerNumber > ns.MAX_HEALERS then
        return nil, {}
    end
    local sorted = self:SortByPriority(debuffedPlayers)
    return sorted[db.healerNumber], sorted
end

--- Legacy API: compute all assignments for display (for /kv test)
function PriorityEngine:ComputeAllAssignments(debuffedPlayers)
    local sorted = self:SortByPriority(debuffedPlayers)
    local assignments = {}
    for i = 1, math.min(ns.MAX_HEALERS, #sorted) do
        assignments[i] = sorted[i]
    end
    return assignments, sorted
end
