---
name: wow-midnight-api
description: >
  WoW 12.0 Midnight API restrictions, Secret Values system, deprecated and
  removed APIs, combat lockdown rules, and taint rules. This skill MUST be
  consulted before writing ANY code that interacts with: unit data, health,
  power, auras, buffs, debuffs, spells, cooldowns, nameplates, combat log,
  combat events, unit frames, or any API that could return secret values.
  Triggers: UnitHealth, UnitPower, UnitName, UnitAura, C_Spell, C_UnitAuras,
  COMBAT_LOG, CLEU, aura, buff, debuff, spell, cooldown, nameplate, combat,
  secret, taint, health, power, mana, energy, rage, unit frame, status bar,
  GetSpellInfo, GetSpellCooldown, CombatLogGetCurrentEventInfo, C_DamageMeter,
  issecretvalue, SecretValues, addon restrictions, restricted actions,
  IsAuraFilteredOutByInstanceID, dispelName, addedAuras, removedAuraInstanceIDs.
---

# WoW 12.0 Midnight - API Restrictions and Secret Values

## READ THIS BEFORE WRITING ANY COMBAT-RELATED CODE

WoW 12.0 Midnight (launched March 2, 2026; prepatch January 20, 2026)
introduced the largest addon API change in WoW history. Blizzard implemented
Secret Values - a mechanism that black-boxes combat data so addons can
DISPLAY it but CANNOT perform logic or decision-making on it.

If you write code using pre-12.0 patterns, it WILL compile but WILL crash
when it encounters a secret value in combat. These errors are especially
insidious because they only manifest during combat or inside instances.

---

## What Are Secret Values?

Secret values are opaque wrappers around normal Lua values (numbers, strings,
booleans). They enforce restrictions at the language level:

- Tainted code CANNOT: compare, add, subtract, multiply, divide,
  concatenate (with some exceptions), use in if/then conditions, use as
  table keys, use in string.format, use in tostring(), iterate over
  (if the table is secret)
- Tainted code CAN: store in variables, store in table fields,
  pass to a specific set of approved Blizzard API functions, pass to
  widget APIs that accept secrets
- Untainted code: secrets behave like regular values with no restrictions

### Critical property of secret values:
SECRET VALUES ARE NOT NIL. A secret value wrapping any type will return
true for `secretValue ~= nil`. This is exploitable for detection:
```lua
-- This works even when dispelName is secret:
if auraData.dispelName ~= nil then
    -- Aura IS dispellable (we don't know the type, but it has one)
end
```

### Testing for secrets

```lua
-- Test a single value
if issecretvalue(someValue) then
    -- This value is secret: passthrough only, no logic
end

-- Test a table
if issecrettable(someTable) then
    -- Cannot iterate or access fields
end

-- Test if you can access a table without error
if canaccesstable(someTable) then
    -- Safe to read
end

-- Forcibly make a value secret (for testing your secret-safe code)
local secretVal = secretwrap(42)

-- Drop your ability to access secrets (for security)
dropsecretaccess()
```

---

## What Returns Secret Values in 12.0?

### Always secret in combat or instances:

| API | Returns | Secret when |
|-----|---------|-------------|
| UnitHealth(unit) | number | In combat or instance |
| UnitHealthMax(unit) | number | In combat or instance |
| UnitPower(unit, type) | number | In combat or instance |
| UnitPowerMax(unit, type) | number | In combat or instance |
| UnitName(unit) | string | Non-player units in instances |
| UnitGUID(unit) | string | Creature units in instances |
| C_Spell.GetSpellCooldown(spellID) | table | In combat or instance |
| C_UnitAuras.GetAuraDataByIndex() | AuraData | Most fields secret for other players |
| C_UnitAuras.GetAuraDataByAuraInstanceID() | AuraData | Most fields secret for other players |

### New 12.0 replacement APIs (return secrets but work with display):

| API | Purpose |
|-----|---------|
| UnitHealthPercent(unit) | Returns secret percentage for health bar coloring |
| UnitHealthMissing(unit) | Returns secret missing health amount |
| UnitPowerPercent(unit) | Returns secret percentage for power bar coloring |
| UnitPowerMissing(unit) | Returns secret missing power amount |

### Completely REMOVED in 12.0:

| Removed API or Event | Replacement |
|----------------------|-------------|
| COMBAT_LOG_EVENT_UNFILTERED | C_DamageMeter APIs, RegisterEventCallback |
| CombatLogGetCurrentEventInfo() | Removed with CLEU |
| SendAddonMessage (in instances) | Blocked, no replacement in instances |
| Many 11.x deprecated functions | Check warcraft.wiki.gg for specifics |

---

## VERIFIED IN-GAME: Aura System Behavior (March 2026)

These findings were confirmed through live testing inside raid instances.
This is the most important section for any addon that needs to detect
auras, debuffs, or dispellable effects on raid members.

### UNIT_AURA Event Payload (info.addedAuras)

| Scenario | spellId | name | isHarmful | dispelName | auraInstanceID |
|----------|---------|------|-----------|------------|----------------|
| Your own auras on yourself | Clean | Clean | Clean | Clean | Clean |
| Your heals/buffs on others | Clean | Clean | Clean | Clean | Clean |
| Boss-applied auras on YOU | Clean | Clean | Clean | Clean | Clean |
| Boss-applied auras on OTHER players | SECRET | SECRET | SECRET | SECRET | Needs verification |

KEY FINDING: The same event (UNIT_AURA info.addedAuras) returns clean
data for auras on yourself but SECRET data for boss-applied auras on
other raid members. This means you CANNOT reliably check spellId or
name to identify specific debuffs on other players.

### C_UnitAuras.GetAuraDataByIndex() — DO NOT USE FOR DETECTION

All fields are secret inside instances when querying other players:
spellId, name, isHarmful, dispelName, duration, expirationTime.
Only auraInstanceID is confirmed non-secret.

### C_UnitAuras.IsAuraFilteredOutByInstanceID()

This API accepts a unit, auraInstanceID, and filter string. It returns
a non-secret boolean. When it returns false with "HARMFUL" filter, the
aura IS harmful. This was discovered from a working WeakAura implementation.

```lua
local isHarmful = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HARMFUL")
```

NOTE: This only works if auraInstanceID itself is not secret. Testing
showed auraInstanceID is clean for your own auras but may be secret for
other players — verify in-game before relying on this for cross-player detection.

### Secret ~= nil Pattern

Secret values are NOT nil. This enables presence-checking:
```lua
-- Works even on secret values:
if auraData.dispelName ~= nil then
    -- Has a dispel type (Magic, Curse, Disease, Poison, or secret)
end
```

### Time-Window Collection Pattern (Recommended for Debuff Waves)

When a boss applies debuffs to multiple players simultaneously, use a
time-window approach to collect all affected players:

```lua
local windowActive = false
local collected = {}

-- On each UNIT_AURA with harmful+dispellable detection:
if not windowActive then
    windowActive = true
    collected = {}
    C_Timer.After(0.2, function()
        windowActive = false
        -- Sort collected targets by priority
        -- Assign healers
        -- Apply glows
    end)
end
table.insert(collected, { unit = unit, auraInstanceID = id })
```

Benefits:
- Batches simultaneous debuff applications into one assignment pass
- Handles variable debuff counts (8 normal, 20 empowered)
- 0.2s window matches server batch timing for ability casts
- Mass dispel threshold: skip assignment if count > 15

### Correct Aura Detection Pattern (Proven Working)

```lua
frame:RegisterEvent("UNIT_AURA")
frame:SetScript("OnEvent", function(self, event, unit, info)
    if not info then return end

    -- Detect new debuffs
    if info.addedAuras then
        for _, aura in pairs(info.addedAuras) do
            local id = aura.auraInstanceID
            if id and not issecretvalue(id) then
                -- Check if harmful using filter API (non-secret return)
                local isHarmful = not C_UnitAuras.IsAuraFilteredOutByInstanceID(
                    unit, id, "HARMFUL")
                -- Check if dispellable (secret ~= nil trick)
                local isDispellable = aura.dispelName ~= nil

                if isHarmful and isDispellable then
                    -- This is a harmful, dispellable debuff
                    -- Add to tracking, start collection window
                end
            end
        end
    end

    -- Detect removals (dispels)
    if info.removedAuraInstanceIDs then
        for _, id in pairs(info.removedAuraInstanceIDs) do
            -- Remove from tracking
        end
    end

    -- Handle full aura refresh
    if info.isFullUpdate then
        -- Rebuild tracking state
    end
end)
```

### Anti-Patterns (will break in instances)

```lua
-- WRONG: GetAuraDataByIndex fields are secret for other players
for i = 1, 40 do
    local data = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
    if data and data.spellId == TARGET_SPELL then  -- ERROR: secret comparison
        -- Will never match
    end
end

-- WRONG: Checking isHarmful directly (secret for other players)
if auraData.isHarmful then  -- ERROR: secret in conditional
    -- Will error
end

-- WRONG: String matching on aura name (secret for other players)
if auraData.name == "Avenger's Shield" then  -- ERROR: secret comparison
    -- Will error
end

-- RIGHT: Use IsAuraFilteredOutByInstanceID (non-secret return)
-- RIGHT: Use dispelName ~= nil (secret is not nil)
-- RIGHT: Use time-window collection for batch detection
```

---

## Correct Code Patterns

### Pattern 1: Passthrough (most common)

Pass secret values directly to widget APIs that accept them.
NEVER inspect, compare, or perform math on the values.

```lua
-- WRONG: will error when health is secret
local health = UnitHealth("target")
if health < UnitHealthMax("target") * 0.3 then
    frame:SetBackdropColor(1, 0, 0)
end

-- CORRECT: passthrough to StatusBar, which accepts secrets
local health = UnitHealth("target")
local maxHealth = UnitHealthMax("target")
myHealthBar:SetMinMaxValues(0, maxHealth)
myHealthBar:SetValue(health)
```

### Pattern 2: Secret-safe branching

Use issecretvalue() when you need different behavior for
secret vs non-secret contexts.

```lua
local health = UnitHealth("player")
if issecretvalue(health) then
    myBar:SetValue(health)
else
    local pct = health / UnitHealthMax("player")
    if pct < 0.3 then
        myBar:SetStatusBarColor(1, 0, 0)
    end
end
```

### Pattern 3: ColorCurve for health coloring

```lua
local colorCurve = C_CurveUtil.CreateColorCurve()
colorCurve:AddPoint(0.0, 1.0, 0.0, 0.0)   -- 0% = red
colorCurve:AddPoint(0.5, 1.0, 1.0, 0.0)   -- 50% = yellow
colorCurve:AddPoint(1.0, 0.0, 1.0, 0.0)   -- 100% = green
local pct = UnitHealthPercent("target")
myHealthBar:SetStatusBarColorCurve(colorCurve, pct)
```

### Pattern 4: Duration objects for timers

```lua
local duration = C_DurationUtil.CreateDuration()
myTimerBar:SetTimerDuration(duration)
```

### Pattern 5: Restriction status check

```lua
if not GetRestrictedActionStatus("secretHealth") then
    local hp = UnitHealth("player")
    if hp < 1000 then end
else
    myBar:SetValue(UnitHealth("player"))
end
```

### Pattern 6: FontString with secrets

```lua
local name = UnitName("target")
myNameText:SetText(name)
-- After this, myNameText:GetText() returns SECRET
-- Check with: myNameText:HasSecretValues()
-- Clear with: myNameText:SetToDefaults()
```

---

## Widget Secret Aspects

When you pass a secret value to a widget API, the widget gets marked:

| Action | Aspect | Consequence |
|--------|--------|-------------|
| FontString:SetText(secretStr) | Text | GetText() returns secret |
| Texture:SetTexture(secretFileID) | Texture | GetTexture() returns secret |
| StatusBar:SetValue(secretNum) | Value | GetValue() returns secret |

Clear: myWidget:SetToDefaults()
Check: myWidget:HasSecretValues()

---

## Communication Restrictions in Instances

- Chat messages received as secret values while inside instances
- SendAddonMessage() is BLOCKED inside instances
- SendAddonMessageLogged() is also blocked
- No addon-to-addon communication in dungeons or raids
- These restrictions lift when you leave the instance
- AceComm-3.0 will fail silently inside instances

---

## How to Verify API Behavior

1. Check extracted docs in .wow-api-reference/ for SecretReturns fields
2. Check warcraft.wiki.gg (updated to 12.0.1)
3. Check the Secret Values article: https://warcraft.wiki.gg/wiki/Secret_Values
4. When in doubt, treat the return as potentially secret
5. When stuck on 12.0 restrictions, existing WeakAuras or working addons
   can sometimes reveal which APIs bypass secret values in practice, but
   these references are rare and may not exist for your specific problem

---

## Quick Reference: Secret-Accepting Widget APIs

- StatusBar:SetValue(secretNumber)
- StatusBar:SetMinMaxValues(secretMin, secretMax)
- StatusBar:SetTimerDuration(durationObj)
- FontString:SetText(secretString)
- Texture:SetTexture(secretFileID)
- Texture:SetAtlas(secretAtlas)
- Various SetPoint, SetSize calls
- AbbreviateNumbers(secretNumber) returns secret string
- String concatenation: str .. secretVal returns secret string (relaxed in 12.0)
- C_CurveUtil color curve operations
