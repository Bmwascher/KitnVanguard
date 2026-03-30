local _, ns = ...

local Sync = {}
ns.Sync = Sync

local ok1, LibSerialize = pcall(LibStub, "LibSerialize")
local ok2, LibDeflate = pcall(LibStub, "LibDeflate")
local ok3, AceComm = pcall(LibStub, "AceComm-3.0")
if not ok1 or not ok2 or not ok3 then
    print("|cffff6060KitnVanguard:|r Missing library — LibSerialize, LibDeflate, or AceComm not found. Sync disabled.")
    return
end

local PREFIX_SYNC = "KV_SYNC"
local PREFIX_ACK = "KV_ACK"

-- Addon presence tracking (NSRT HasNSRT pattern)
local raidAddonStatus = {} -- "Name-Realm" -> true/false

-- Encode a data table into a compressed string for addon messaging
local function encode(data)
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    return LibDeflate:EncodeForWoWAddonChannel(compressed)
end

-- Decode a received string back into a data table
local function decode(text)
    local decoded = LibDeflate:DecodeForWoWAddonChannel(text)
    if not decoded then return nil end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return nil end
    local success, data = LibSerialize:Deserialize(decompressed)
    if not success then return nil end
    return data
end

-- Send an ACK response so the leader knows we have the addon
local function sendAck()
    if C_ChatInfo.InChatMessagingLockdown() then
        return
    end
    local ver = C_AddOns.GetAddOnMetadata(ns.ADDON_NAME, "Version") or "dev"
    AceComm:SendCommMessage(PREFIX_ACK, ver, "RAID")
end

-- Broadcast priority data to the raid (leader/assist only)
function Sync:Broadcast()
    if not IsInRaid() then
        ns:PrintError("Must be in a raid to sync.")
        return
    end

    if not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        ns:PrintError("Only raid leader or assist can sync settings.")
        return
    end

    if C_ChatInfo.InChatMessagingLockdown() then
        ns:PrintError("Cannot sync during messaging lockdown.")
        return
    end

    -- Reset addon status tracking for this sync cycle
    wipe(raidAddonStatus)
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local name = ns:GetFullUnitName(unit)
            if name then
                raidAddonStatus[name] = false
            end
        end
    end
    -- Mark self as having the addon
    local myName = ns:GetFullUnitName("player")
    if myName then
        raidAddonStatus[myName] = true
    end

    local db = ns.db
    local payload = {
        version = 1,
        priorityList = db.priorityList,
        scanRoleOrder = db.scanRoleOrder,
        scanClassOrder = db.scanClassOrder,
        includeWarlocks = db.includeWarlocks,
    }

    local encoded = encode(payload)
    AceComm:SendCommMessage(PREFIX_SYNC, encoded, "RAID")

    ns:Print("Priority list synced to raid (" .. #db.priorityList .. " players).")
end

-- Resolve AceComm sender name to a raid unit token
-- AceComm sends "Name-Realm" which may not work directly with Unit* functions
local function senderToUnit(sender)
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local name = ns:GetFullUnitName(unit)
            if name and name == sender then
                return unit
            end
            -- Also try short name match (same-realm sender has no realm suffix)
            local shortName = UnitName(unit)
            if shortName and shortName == sender then
                return unit
            end
        end
    end
    return nil
end

-- Handle received sync data
local function onReceiveSync(_, text, _, sender)
    -- Resolve sender to a raid unit token for reliable API calls
    local senderUnit = senderToUnit(sender)
    if not senderUnit then
        return
    end
    -- Only accept from leader or assist
    if not UnitIsGroupLeader(senderUnit) and not UnitIsGroupAssistant(senderUnit) then
        return
    end

    local data = decode(text)
    if not data or data.version ~= 1 then
        return
    end

    local db = ns.db
    local changed = false

    if data.priorityList and type(data.priorityList) == "table" then
        db.priorityList = data.priorityList
        changed = true
    end
    if data.scanRoleOrder and type(data.scanRoleOrder) == "table" then
        db.scanRoleOrder = data.scanRoleOrder
        changed = true
    end
    if data.scanClassOrder and type(data.scanClassOrder) == "table" then
        db.scanClassOrder = data.scanClassOrder
        changed = true
    end
    -- Sync determinism-critical toggles (must match across all clients)
    if data.includeWarlocks ~= nil then
        db.includeWarlocks = data.includeWarlocks
        changed = true
    end

    if changed then
        local displayName = sender:match("^([^%-]+)") or sender
        ns:Print("Synced priority list from |cffffff00" .. displayName .. "|r ("
            .. #db.priorityList .. " players).")
        -- Refresh GUI if open so toggles reflect synced values
        if ns.ConfigFrame and ns.ConfigFrame:IsShown() then
            ns.ConfigFrame:Refresh()
        end
    end

    -- Reply with ACK so leader knows we have the addon
    sendAck()
end

-- Handle received ACK (addon presence confirmation)
local function onReceiveAck(_, text, _, sender)
    -- Mark sender as having the addon
    -- AceComm sender may be "Name-Realm" or "Name" — try both
    if raidAddonStatus[sender] ~= nil then
        raidAddonStatus[sender] = true
    else
        -- Try matching by short name
        local shortName = sender:match("^([^%-]+)")
        for fullName in pairs(raidAddonStatus) do
            if fullName == shortName or fullName:match("^([^%-]+)") == shortName then
                raidAddonStatus[fullName] = true
                break
            end
        end
    end

    if ns.debugMode then
        local displayName = sender:match("^([^%-]+)") or sender
        ns:Print("ACK from |cff00ff00" .. displayName .. "|r (v" .. (text or "?") .. ")")
    end
end

-- Print addon status report
function Sync:PrintStatus()
    if not IsInRaid() then
        ns:PrintError("Must be in a raid.")
        return
    end

    local hasAddon = {}
    local missingAddon = {}

    for name, status in pairs(raidAddonStatus) do
        local displayName = name:match("^([^%-]+)") or name
        if status then
            hasAddon[#hasAddon + 1] = "|cff00ff00" .. displayName .. "|r"
        else
            missingAddon[#missingAddon + 1] = "|cffff6060" .. displayName .. "|r"
        end
    end

    table.sort(hasAddon)
    table.sort(missingAddon)

    ns:Print("=== KitnVanguard Status ===")
    if #hasAddon > 0 then
        print("  Installed (" .. #hasAddon .. "): " .. table.concat(hasAddon, ", "))
    end
    if #missingAddon > 0 then
        print("  Missing (" .. #missingAddon .. "): " .. table.concat(missingAddon, ", "))
    end
    if next(raidAddonStatus) == nil then
        print("  No data yet. Run a ready check or /kv sync first.")
    end
end

-- Event handler
local eventFrame = CreateFrame("Frame")

function Sync:Initialize()
    AceComm:RegisterComm(PREFIX_SYNC, onReceiveSync)
    AceComm:RegisterComm(PREFIX_ACK, onReceiveAck)

    self.lastBroadcastTime = 0

    eventFrame:RegisterEvent("READY_CHECK")
    eventFrame:RegisterEvent("START_PLAYER_COUNTDOWN")
    eventFrame:SetScript("OnEvent", function(_, event)
        if not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
            -- Non-leaders still send ACK on ready check
            if event == "READY_CHECK" then
                C_Timer.After(0.5, sendAck)
            end
            return
        end
        if C_ChatInfo.InChatMessagingLockdown() then
            return
        end

        if event == "READY_CHECK" then
            self.lastBroadcastTime = GetTime()
            C_Timer.After(0.5, function()
                Sync:Broadcast()
            end)
        elseif event == "START_PLAYER_COUNTDOWN" then
            if (GetTime() - self.lastBroadcastTime) < 30 then
                return
            end
            self.lastBroadcastTime = GetTime()
            C_Timer.After(0.5, function()
                Sync:Broadcast()
            end)
        end
    end)
end
