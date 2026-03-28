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
  issecretvalue, SecretValues, addon restrictions, restricted actions.
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
| C_UnitAuras.GetAuraDataByIndex() | AuraData | Many fields secret |
| C_UnitAuras.GetAuraDataByAuraInstanceID() | AuraData | Many fields secret |

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

## Correct Code Patterns


### VERIFIED IN-GAME: Aura Detection (March 2026)

This was confirmed through live testing inside a raid instance:

| Method | Secret? | Use? |
|--------|---------|------|
| C_UnitAuras.GetAuraDataByIndex() fields | YES — spellId, name, isHarmful, dispelName, duration all secret | NEVER use for detection inside instances |
| UNIT_AURA event info.addedAuras entries | NO — spellId, name, isHarmful, dispelName all readable | USE THIS for aura detection |
| auraInstanceID | NO — clean in both paths | USE THIS for tracking and removal |
| info.removedAuraInstanceIDs | NO — clean | USE THIS for detecting dispels/removals |

The correct aura detection pattern inside instances:

```lua
-- WRONG: GetAuraDataByIndex returns secret fields inside instances
for i = 1, 40 do
    local data = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
    if data and data.spellId == TARGET_SPELL_ID then  -- ERROR: secret comparison
        -- This will fail
    end
end

-- CORRECT: Use event payload which has clean values
frame:RegisterEvent("UNIT_AURA")
frame:SetScript("OnEvent", function(self, event, unit, info)
    if not info then return end
    -- Detect new debuffs
    if info.addedAuras then
        for _, aura in pairs(info.addedAuras) do
            if aura.spellId == TARGET_SPELL_ID then
                -- spellId is NOT secret in addedAuras
                -- Track by aura.auraInstanceID for later removal
            end
        end
    end
    -- Detect removals
    if info.removedAuraInstanceIDs then
        for _, id in pairs(info.removedAuraInstanceIDs) do
            -- Clean up tracked auras by instance ID
        end
    end
    -- Handle full aura refresh (roster change, zone change)
    if info.isFullUpdate then
        -- Wipe and rebuild tracking from addedAuras
    end
end)
```

This is the ONLY reliable way to detect specific auras inside instances in 12.0.

### Pattern 1: Passthrough (most common)

Pass secret values directly to widget APIs that accept them.
NEVER inspect, compare, or perform math on the values.

```lua
-- WRONG: will error when health is secret
local health = UnitHealth("target")
if health < UnitHealthMax("target") * 0.3 then
    frame:SetBackdropColor(1, 0, 0)  -- turn red when low
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
-- CORRECT: check before operating
local health = UnitHealth("player")
if issecretvalue(health) then
    -- Restricted context: passthrough only
    myBar:SetValue(health)
else
    -- Unrestricted: safe to do math
    local pct = health / UnitHealthMax("player")
    if pct < 0.3 then
        myBar:SetStatusBarColor(1, 0, 0)
    end
end
```

### Pattern 3: ColorCurve for health coloring

Use the new Curve system instead of manual color calculation.

```lua
-- CORRECT: Blizzard's 12.0 solution for health bar colors
local colorCurve = C_CurveUtil.CreateColorCurve()
-- Add color stops: percentage to R, G, B
colorCurve:AddPoint(0.0, 1.0, 0.0, 0.0)   -- 0% = red
colorCurve:AddPoint(0.5, 1.0, 1.0, 0.0)   -- 50% = yellow
colorCurve:AddPoint(1.0, 0.0, 1.0, 0.0)   -- 100% = green

-- Apply to a health bar using secret-safe percentage
local pct = UnitHealthPercent("target")
myHealthBar:SetStatusBarColorCurve(colorCurve, pct)
```

### Pattern 4: Duration objects for timers

```lua
-- CORRECT: secret-safe timer display
local duration = C_DurationUtil.CreateDuration()
-- SetTimerDuration auto-updates the bar without addon polling
myTimerBar:SetTimerDuration(duration)
```

### Pattern 5: Restriction status check

```lua
-- CORRECT: check if restrictions are active before using old patterns
if not GetRestrictedActionStatus("secretHealth") then
    -- Not restricted right now, old patterns are safe
    local hp = UnitHealth("player")
    if hp < 1000 then
        -- This math is safe here
    end
else
    -- Restricted, passthrough only
    myBar:SetValue(UnitHealth("player"))
end
```

### Pattern 6: FontString with secrets

```lua
-- CORRECT: SetText accepts secrets
local name = UnitName("target")
myNameText:SetText(name)
-- NOTE: After this, myNameText:GetText() will return a SECRET
-- Check with: myNameText:HasSecretValues()
-- Clear with: myNameText:SetToDefaults()
```

---

## Widget Secret Aspects

When you pass a secret value to a widget API, the widget gets marked
with a secret aspect. This affects other APIs on the same widget:

| Action | Aspect applied | Consequence |
|--------|---------------|-------------|
| FontString:SetText(secretStr) | Text | GetText() returns secret |
| Texture:SetTexture(secretFileID) | Texture | GetTexture() returns secret |
| StatusBar:SetValue(secretNum) | Value | GetValue() returns secret |

Clearing aspects:
```lua
myWidget:SetToDefaults()  -- Clears all secret aspects
```

Checking aspects:
```lua
if myWidget:HasSecretValues() then
    -- Widget is marked, some getters will return secrets
end
```

---

## Communication Restrictions in Instances

- Chat messages received as secret values while inside instances
- SendAddonMessage() is BLOCKED inside instances
- SendAddonMessageLogged() is also blocked
- No addon-to-addon communication in dungeons or raids
- These restrictions lift when you leave the instance

---

## How to Verify API Behavior

When you encounter an API you are unsure about:

1. Check extracted docs: Look in .wow-api-reference/Interface/AddOns/Blizzard_APIDocumentationGenerated/
   for the relevant system file. Search for SecretReturns, ConditionalSecret, SecretArguments.

2. Check warcraft.wiki.gg: Search for the function name. The wiki is updated to 12.0.1.
   Example URL: https://warcraft.wiki.gg/wiki/API_UnitHealth

3. Check the Secret Values article: https://warcraft.wiki.gg/wiki/Secret_Values

4. When in doubt, treat the return as potentially secret. Use the issecretvalue() guard pattern.

---

## Common Mistakes Claude Will Make

1. Using COMBAT_LOG_EVENT_UNFILTERED: This event is GONE. Period. If you need damage
   meter data, use C_DamageMeter. For combat events, use RegisterEventCallback where available.

2. Comparing health/power values: Any "if health < X" will error in combat.
   Use passthrough patterns or issecretvalue() guards.

3. String formatting unit names: string.format("Target: %s", UnitName("target"))
   will error if UnitName returns a secret. Use SetText() passthrough instead.

4. Iterating aura tables: AuraData fields may be secret. Always use issecretvalue()
   or issecrettable() before accessing fields programmatically.

5. Using old GetSpellInfo patterns: Many spell APIs changed in 11.0 AND again in 12.0.
   Always check the current API signature, not cached knowledge.

6. Sending addon messages inside instance checks: Any code path that runs inside
   a dungeon or raid cannot use SendAddonMessage.

---

## Quick Reference: Secret-Accepting Widget APIs

These Blizzard APIs accept secret values from tainted code:

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
