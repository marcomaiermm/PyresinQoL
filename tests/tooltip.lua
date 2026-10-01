-- luajit tests/tooltip.lua
FACTION_ALLIANCE = arg[1] == "de" and "Allianz" or "Alliance"
FACTION_HORDE = "Horde"
local module = {}
local ns, postCall, objectPostCall = {}, nil, nil
function GetLocale() return arg[1] == "de" and "deDE" or "enUS" end
assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
UIParent, YOU = {}, "You"
local combat, callbacks = false, {}
function InCombatLockdown() return combat end
function CreateColor(r, g, b) return { r = r, g = g, b = b } end
function CreateColorFromHexString(hex)
    return CreateColor(tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255)
end
local secret = setmetatable({}, { __tostring = function() error("Do not inspect restricted values") end })
function issecretvalue(value) return rawequal(value, secret) end
local unit, health, maximum, guild, rank = "mouseover", 1234, 5678, "Test Guild", "Officer"
function UnitHealth(token) assert(token == unit); return health end
function UnitHealthMax(token) assert(token == unit); return maximum end
function GetGuildInfo(token) assert(token == unit); return guild, rank end
local isPlayer, class = true, "MAGE"
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
function UnitIsPlayer(token) assert(token == unit); return isPlayer end
function UnitClass(token) assert(token == unit); return "Class", class end
local function Text(value)
    local text = { value = value }
    function text:SetPoint() end
    function text:GetText() return self.value end
    function text:SetText(value) self.value = value end
    function text:SetTextColor(...) self.color = { ... } end
    function text:SetFormattedText(format, ...)
        self.args = { ... }
        -- The game formatter accepts secrets; Lua's string.format cannot emulate them.
        for _, value in ipairs(self.args) do
            if issecretvalue(value) then self.value = "restricted"; return end
        end
        self.value = string.format(format, ...)
    end
    return text
end
local bar = { height = 8, scripts = {} }
function bar:GetHeight() return self.height end
function bar:SetHeight(height) self.height = height end
function bar:CreateFontString() self.text = Text(); return self.text end
function bar:HookScript(event, callback) self.scripts[event] = callback end
local function Tooltip()
    local tooltip = { scripts = {}, lines = {}, rightLines = {}, shown = true,
        background = { 0.1, 0.1, 0.1, 1 }, border = { 1, 1, 1, 1 }, anchor = "ANCHOR_NONE" }
    -- The native tooltip exposes color methods on NineSlice, not on its parent.
    tooltip.NineSlice = {}
    function tooltip.NineSlice:GetCenterColor() return unpack(tooltip.background) end
    function tooltip.NineSlice:GetBorderColor() return unpack(tooltip.border) end
    function tooltip.NineSlice:SetCenterColor(...) assert(select("#", ...) == 4); tooltip.background = { ... } end
    function tooltip.NineSlice:SetBorderColor(...) assert(select("#", ...) == 4); tooltip.border = { ... } end
    function tooltip:GetUnit() return "Name", unit end
    function tooltip:NumLines() return #self.lines end
    function tooltip:GetLeftLine(index) return self.lines[index] end
    function tooltip:GetRightLine(index) return self.rightLines[index] end
    function tooltip:AddDoubleLine(left, right)
        self.lines[#self.lines + 1] = Text(left)
        self.rightLines[#self.lines] = Text(right)
    end
    function tooltip:HookScript(event, callback)
        local previous = self.scripts[event]
        self.scripts[event] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    function tooltip:RegisterEvent() end
    function tooltip:GetPrimaryTooltipInfo() return self.info end
    function tooltip:GetPrimaryTooltipData() return self.data end
    function tooltip:GetOwner() return self.owner end
    function tooltip:SetOwner(owner, anchor)
        if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
        self.owner, self.anchor, self.point = owner, anchor, nil
        self.lines, self.rightLines, self.info, self.data = {}, {}, nil, nil
    end
    function tooltip:ClearAllPoints() self.point = nil end
    function tooltip:GetPoint() if self.point then return unpack(self.point) end end
    function tooltip:SetPoint(...) self.point = { ... } end
    function tooltip:GetAnchorType() return self.anchor end
    function tooltip:SetAnchorType(anchor, x, y) self.anchor, self.anchorX, self.anchorY = anchor, x, y end
    function tooltip:IsShown() return self.shown end
    function tooltip:Show()
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function tooltip:RefreshDataNextUpdate() self.refreshRequested = true end
    return tooltip
end
GameTooltip, ItemRefTooltip, ShoppingTooltip1 = Tooltip(), Tooltip(), Tooltip()
GameTooltip.StatusBar = bar
ShoppingTooltip1.RefreshDataNextUpdate = nil -- Comparison tooltips lack this mixin.
function GameTooltip_SetDefaultAnchor(tooltip, owner)
    tooltip:SetOwner(owner, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -17, 70)
end
function SharedTooltip_SetBackdropStyle(tooltip) tooltip.NineSlice:SetCenterColor(0.1, 0.1, 0.1, 1) end
function hooksecurefunc(object, name, callback)
    if type(object) == "string" then object, name, callback = _G, object, name end
    local original = assert(object[name], name)
    object[name] = function(...)
        original(...)
        callback(...)
    end
end
Enum = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Object = 4 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, callback)
    callbacks[kind] = callback
    if kind == Enum.TooltipDataType.Object then objectPostCall = callback
    elseif kind == Enum.TooltipDataType.Unit then postCall = callback end
end }
ns.RegisterModule = function(id, initialize) assert(id == "tooltips"); initialize(module) end
assert(loadfile("Modules/Tooltips/Tooltip.lua"))("PyresinQoL", ns)
bar.scripts.OnUpdate(bar, 0.1)
assert(bar.text.value == "", "Safe before settings load")
objectPostCall(GameTooltip)
assert(GameTooltip.anchor == "ANCHOR_NONE", "Object tooltip is safe before settings load")
PyresinQoLDB = { tooltipHealth = true, tooltipGuildRank = true }
local function Rebuild(guildText, factionText)
    GameTooltip.scripts.OnTooltipCleared()
    GameTooltip.data = { type = Enum.TooltipDataType.Unit }
    GameTooltip.lines = { Text("Player"), Text(guildText or "<Test Guild>"), Text("Level 60") }
    if factionText then table.insert(GameTooltip.lines, Text(factionText)) end
    postCall(GameTooltip)
end
Rebuild()
assert(GameTooltip.lines[1].color[1] == 0.25 and GameTooltip.lines[1].color[3] == 0.92, "Mage names use class color")
assert(GameTooltip.lines[1].value == "Player", "Preserve the displayed player name")
class = "WARRIOR"
Rebuild()
assert(GameTooltip.lines[1].color[1] == 0.78, "New players use their own class color")
isPlayer = false
Rebuild()
assert(not GameTooltip.lines[1].color, "NPCs retain native reaction colors")
isPlayer = secret
Rebuild()
assert(not GameTooltip.lines[1].color, "Do not inspect restricted player flags")
isPlayer, class = true, secret
Rebuild()
assert(not GameTooltip.lines[1].color, "Do not inspect restricted classes")
class = "UNKNOWN"
Rebuild()
assert(not GameTooltip.lines[1].color, "Unknown classes keep native colors")
class = "MAGE"
Rebuild()
assert(bar.height == 14 and bar.text.value == "1234 / 5678")
assert(GameTooltip.lines[2].value == "|cff40ff40<Test Guild>|r |cff909090Officer|r")
Rebuild(nil, FACTION_ALLIANCE)
assert(GameTooltip.lines[4].color[1] == 0.25 and GameTooltip.lines[4].color[3] == 1, "Alliance is blue")
assert(GameTooltip.lines[4].value == "|A:UI-Character-Info-Honor-Icon-Alliance:16:16|a " .. FACTION_ALLIANCE)
Rebuild(nil, FACTION_HORDE)
assert(GameTooltip.lines[4].color[1] == 1 and GameTooltip.lines[4].color[3] == 0.2, "Horde is red")
local hordeText = "|A:UI-Character-Info-Honor-Icon-Horde:16:16|a " .. FACTION_HORDE
assert(GameTooltip.lines[4].value == hordeText)
postCall(GameTooltip)
assert(GameTooltip.lines[4].value == hordeText, "Repeated processing must not duplicate faction icons")
assert(not GameTooltip.lines[3].color, "Keep other unit lines unchanged")
Rebuild(nil, "Neutral")
assert(not GameTooltip.lines[4].color, "Keep other factions unchanged")
assert(GameTooltip.lines[4].value == "Neutral", "No icon for other factions")
Rebuild(nil, secret)
assert(not GameTooltip.lines[4].color, "Do not inspect restricted faction text")
module.UpdateTooltips()
assert(GameTooltip.lines[2].value == "|cff40ff40<Test Guild>|r |cff909090Officer|r", "No duplicate rank on settings refresh")
Rebuild("Test Guild")
assert(GameTooltip.lines[2].value == "|cff40ff40<Test Guild>|r |cff909090Officer|r", "Add missing guild brackets")
Rebuild()
health, maximum = 2000, 4000
bar.scripts.OnUpdate(bar, 0.1)
assert(bar.text.value == "2000 / 4000")
health, maximum = 3000, 6000
bar.scripts.OnUpdate(bar, 0.1)
assert(bar.text.value == "3000 / 6000", "Maximum HP updates even with unchanged percentage")
unit = nil -- Blizzard clears unit data before starting the fade.
bar.scripts.OnUpdate(bar, 0.1)
assert(bar.text.value == "3000 / 6000", "Keep the last HP text throughout the tooltip fade")
PyresinQoLDB.tooltipHealth = false
module.UpdateTooltips()
assert(bar.text.value == "", "Disabling HP still clears text during the fade")
PyresinQoLDB.tooltipHealth = true
unit = "mouseover"
Rebuild()
unit = nil
GameTooltip.scripts.OnHide()
assert(bar.text.value == "", "Clear HP when the tooltip finishes hiding")
unit = "mouseover"
Rebuild()
health = 0
bar.scripts.OnUpdate(bar, 0.1)
assert(bar.text.value == "0 / 6000", "Dead units retain numeric HP")
health, maximum = secret, secret
bar.scripts.OnUpdate(bar, 0.1)
assert(rawequal(bar.text.args[1], secret) and rawequal(bar.text.args[2], secret))
health, maximum = 1234, 5678
PyresinQoLDB.tooltipHealth, PyresinQoLDB.tooltipGuildRank = false, false
module.UpdateTooltips()
assert(bar.height == 8 and bar.text.value == "" and GameTooltip.lines[2].value == "<Test Guild>")
PyresinQoLDB.tooltipHealth, PyresinQoLDB.tooltipGuildRank = true, true
module.UpdateTooltips()
assert(bar.text.value == "1234 / 5678" and GameTooltip.lines[2].value == "|cff40ff40<Test Guild>|r |cff909090Officer|r")
rank = "Member"
Rebuild()
assert(GameTooltip.lines[2].value == "|cff40ff40<Test Guild>|r |cff909090Member|r")
guild, rank = "[Guild.%]", "Leader"
Rebuild("<[Guild.%]> - Realm")
assert(GameTooltip.lines[2].value == "|cff40ff40<[Guild.%]>|r - Realm |cff909090Leader|r", "Preserve realm and match guild literally")
guild, rank = nil, nil
Rebuild("Level 60")
assert(GameTooltip.lines[2].value == "Level 60", "Unguilded players and NPCs keep native lines")
guild, rank = secret, secret
Rebuild()
assert(GameTooltip.lines[2].value == "<Test Guild>")
guild, rank = "Test Guild", "Officer"
Rebuild(secret)
assert(rawequal(GameTooltip.lines[2].value, secret), "Do not inspect restricted tooltip text")
postCall({}) -- Ignore other tooltips.
GameTooltip.scripts.OnTooltipCleared()
unit = secret
module.UpdateTooltips()
assert(bar.text.value == "", "Do not query restricted unit tokens")
unit = nil
GameTooltip.scripts.OnTooltipCleared()
bar.scripts.OnUpdate(bar, 0.1)
assert(bar.text.value == "", "No stale HP on item or spell tooltips")
PyresinQoLDB.tooltipObjectCursor = true
GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
GameTooltip.data = { type = Enum.TooltipDataType.Object }
GameTooltip.info = { getterName = "GetWorldCursor" }
GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -17, 70)
GameTooltip.lines = { Text("Goldshire") }
objectPostCall(GameTooltip)
assert(GameTooltip.anchor == "ANCHOR_CURSOR" and not GameTooltip.point, "Signs use the native cursor anchor")
assert(GameTooltip.lines[1].value == "Goldshire", "Anchoring preserves the object's text")
objectPostCall({}) -- Other tooltip frames stay untouched.
for _, info in ipairs({ {}, { getterName = "GetHyperlink" } }) do
    GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
    GameTooltip.info, GameTooltip.data = info, { type = Enum.TooltipDataType.Object }
    objectPostCall(GameTooltip)
    assert(GameTooltip.anchor == "ANCHOR_RIGHT", "Only world cursor objects move")
end
GameTooltip.info = nil
objectPostCall(GameTooltip)
assert(GameTooltip.anchor == "ANCHOR_RIGHT", "Ignore missing tooltip info")
-- SetWorldCursor resets the owner/anchor before processing each new world hover.
GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
GameTooltip.info, GameTooltip.data = { getterName = "GetWorldCursor" }, { type = Enum.TooltipDataType.Unit }
postCall(GameTooltip)
assert(GameTooltip.anchor == "ANCHOR_NONE", "Units retain Blizzard's anchor after hovering an object")
PyresinQoLDB.tooltipObjectCursor = false
objectPostCall(GameTooltip)
assert(GameTooltip.anchor == "ANCHOR_NONE", "Disabling the option preserves Blizzard's anchor")
print("PASS: live tooltip HP, restricted values, guild ranks, native text preservation and toggles")
print("PASS: world object cursor anchoring, tooltip isolation and toggle")

local writes, clears, reads = 0, 0, 0
local setFormattedText, setText = bar.text.SetFormattedText, bar.text.SetText
local getHealth, getMaximum = UnitHealth, UnitHealthMax
bar.text.SetFormattedText = function(self, ...)
    writes = writes + 1
    return setFormattedText(self, ...)
end
bar.text.SetText = function(self, ...)
    clears = clears + 1
    return setText(self, ...)
end
UnitHealth = function(...) reads = reads + 1; return getHealth(...) end
UnitHealthMax = function(...) reads = reads + 1; return getMaximum(...) end
unit, health, maximum = "mouseover", 1234, 5678
PyresinQoLDB.tooltipHealth = true
Rebuild()
assert(writes == 1, "Showing a unit tooltip must immediately render HP")
writes, reads = 0, 0
for _ = 1, 240 do bar.scripts.OnUpdate(bar, 1 / 240) end
assert(writes > 0 and writes <= 10 and reads == writes * 2, "Health refresh must not scale with FPS")
PyresinQoLDB.tooltipHealth = false
module.UpdateTooltips()
local cleared = clears
writes, reads = 0, 0
for _ = 1, 240 do bar.scripts.OnUpdate(bar, 1 / 240) end
assert(writes == 0 and reads == 0 and clears == cleared, "Disabled polling must not read or rewrite health")
PyresinQoLDB.tooltipHealth = true
module.UpdateTooltips()
assert(writes == 1, "Enabling must refresh immediately")
GameTooltip.scripts.OnHide()
cleared = clears
GameTooltip.scripts.OnTooltipCleared()
assert(clears == cleared, "Clear already-empty text only once")
print("PASS: bounded health refresh, immediate display and no disabled text writes")

-- Exercise the new metadata, target, appearance and positioning controls.
local itemLoaded, itemIcon, itemStack = true, 134400, 200
local lookups = 0
C_Item = {
    GetItemInfoInstant = function(id)
        assert(id == 123); lookups = lookups + 1
        return id, nil, nil, nil, itemIcon
    end,
    GetItemInfo = function(id)
        assert(id == 123); lookups = lookups + 1
        if itemLoaded then return "Item", nil, 3, nil, nil, nil, nil, itemStack end
    end,
    GetItemQualityColor = function(quality)
        assert(quality == 3); return 0.2, 0.4, 0.8
    end,
}
C_Spell = { GetSpellTexture = function(id) assert(id == 456); return 135000 end }
local function Build(tooltip, kind, id)
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip.lines, tooltip.data = { Text("Native title") }, { type = kind, id = id }
    tooltip.info, tooltip.refreshRequested = { getterName = "GetHyperlink" }, false
    callbacks[kind](tooltip, tooltip.data)
end
local function Value(tooltip, label)
    for index, line in ipairs(tooltip.lines) do
        if line.value == label then return tooltip.rightLines[index] end
    end
end
unit = nil
PyresinQoLDB = {
    tooltipItemID = true, tooltipItemIconID = true, tooltipItemStack = true,
    tooltipSpellID = true, tooltipSpellIconID = true, tooltipItemQualityBorder = true,
}
for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1 }) do
    Build(tooltip, Enum.TooltipDataType.Item, 123)
    assert(Value(tooltip, ns.L.tooltipItemIDLine).value == "123")
    assert(Value(tooltip, ns.L.tooltipIconIDLine).value == "134400")
    assert(Value(tooltip, ns.L.tooltipStackLine).value == "200")
    assert(tooltip.border[3] == 0.8)
    callbacks[Enum.TooltipDataType.Item](tooltip, tooltip.data)
    assert(#tooltip.lines == 4, "Repeated processing must not duplicate metadata")
    callbacks[Enum.TooltipDataType.Item](tooltip, { type = Enum.TooltipDataType.Item, id = 789 })
    assert(#tooltip.lines == 4, "Embedded recipe metadata must not replace the primary item")
    Build(tooltip, Enum.TooltipDataType.Spell, 456)
    assert(Value(tooltip, ns.L.tooltipSpellIDLine).value == "456")
    assert(Value(tooltip, ns.L.tooltipIconIDLine).value == "135000")
    assert(not Value(tooltip, ns.L.tooltipStackLine) and tooltip.border[3] == 1)
end
local calls = lookups
Build(GameTooltip, Enum.TooltipDataType.Item, secret)
assert(#GameTooltip.lines == 1 and lookups == calls, "Restricted IDs never reach item APIs")
itemIcon, itemStack = secret, secret
Build(GameTooltip, Enum.TooltipDataType.Item, 123)
assert(#GameTooltip.lines == 2, "Restricted icon/stack values are omitted")
itemIcon, itemStack, itemLoaded = 134400, 200, false
Build(GameTooltip, Enum.TooltipDataType.Item, 123)
assert(#GameTooltip.lines == 3, "Uncached items still show public ID and instant icon")
itemLoaded = true
Build(GameTooltip, Enum.TooltipDataType.Item, 123)
assert(#GameTooltip.lines == 4)
module.UpdateTooltips()
assert(GameTooltip.refreshRequested and ItemRefTooltip.refreshRequested,
    "Changed settings rebuild visible item and spell tooltips")
PyresinQoLDB = {}
calls = lookups
Build(GameTooltip, Enum.TooltipDataType.Item, 123)
assert(#GameTooltip.lines == 1 and lookups == calls, "Disabled metadata avoids API lookups")

local targetExists, targetName, targetPlayer = true, "Other", false
FACTION_BAR_COLORS = { [5] = { r = 0, g = 1, b = 0 } }
function UnitExists(token) assert(token == unit .. "target"); return targetExists end
function UnitName(token) assert(token == unit .. "target"); return targetName end
function UnitIsUnit(token, other)
    assert(token == unit .. "target" and other == "player"); return targetPlayer
end
local originalIsPlayer, originalClass = UnitIsPlayer, UnitClass
function UnitIsPlayer(token)
    if token == unit .. "target" then return true end
    return originalIsPlayer(token)
end
function UnitClass(token)
    if token == unit .. "target" then return "Warrior", "WARRIOR" end
    return originalClass(token)
end
function UnitReaction(token, other) assert(other == "player"); return 5 end
unit = "mouseover"
PyresinQoLDB = { tooltipTarget = true, tooltipUnitClassBorder = true,
    tooltipCustomBackground = true, tooltipBackgroundColor = "FF112233", tooltipBackgroundOpacity = 0.5 }
Rebuild()
assert(Value(GameTooltip, ns.L.tooltipTargetLine).value == "Other")
assert(Value(GameTooltip, ns.L.tooltipTargetLine).color[1] == 0.78)
assert(GameTooltip.border[1] == 0.25 and GameTooltip.background[4] == 0.5)
targetPlayer = true
bar.scripts.OnUpdate(bar, 0.1)
assert(Value(GameTooltip, ns.L.tooltipTargetLine).value == ">>You<<")
targetPlayer, targetName = false, secret
bar.scripts.OnUpdate(bar, 0.1)
assert(rawequal(Value(GameTooltip, ns.L.tooltipTargetLine).args[1], secret),
    "Restricted names go directly to the native formatter")
targetExists, GameTooltip.refreshRequested = false, false
bar.scripts.OnUpdate(bar, 0.1)
assert(GameTooltip.refreshRequested, "Disappearing targets request a native rebuild")
Rebuild()
assert(not Value(GameTooltip, ns.L.tooltipTargetLine), "No empty target row")
targetExists, targetName = true, "New target"
bar.scripts.OnUpdate(bar, 0.1)
assert(Value(GameTooltip, ns.L.tooltipTargetLine).value == "New target",
    "Targets update even when health text is disabled")
SharedTooltip_SetBackdropStyle(GameTooltip)
assert(GameTooltip.background[4] == 0.5, "Native styling preserves the chosen background")
GameTooltip.scripts.OnHide()
assert(GameTooltip.background[1] == 0.1 and GameTooltip.background[4] == 1)

unit = nil
PyresinQoLDB = { tooltipAnchor = "fixed", tooltipAnchorPoint = "TOPLEFT",
    tooltipAnchorX = 40, tooltipAnchorY = -20 }
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
GameTooltip.data, GameTooltip.info = { type = Enum.TooltipDataType.Item }, {}
GameTooltip.scripts.OnShow()
assert(GameTooltip.anchor == "ANCHOR_NONE" and GameTooltip.point[1] == "TOPLEFT"
    and GameTooltip.point[4] == 40 and GameTooltip.point[5] == -20)
PyresinQoLDB.tooltipAnchorCombat, combat = true, true
GameTooltip.scripts.OnEvent(GameTooltip, "PLAYER_REGEN_DISABLED")
assert(GameTooltip.point[1] == "BOTTOMRIGHT" and GameTooltip.point[4] == -17)
combat = false
GameTooltip.scripts.OnEvent(GameTooltip, "PLAYER_REGEN_ENABLED")
assert(GameTooltip.point[1] == "TOPLEFT")
PyresinQoLDB.tooltipAnchor, PyresinQoLDB.tooltipCursorAnchor = "cursor", "ANCHOR_CURSOR_LEFT"
PyresinQoLDB.tooltipCursorX, PyresinQoLDB.tooltipCursorY = -12, 24
module.UpdateTooltips()
assert(GameTooltip.anchor == "ANCHOR_CURSOR_LEFT" and GameTooltip.anchorX == -12
    and GameTooltip.anchorY == 24 and not GameTooltip.point)
GameTooltip:SetOwner({}, "ANCHOR_RIGHT")
GameTooltip.data = { type = Enum.TooltipDataType.Item }
module.UpdateTooltips()
assert(GameTooltip.anchor == "ANCHOR_RIGHT", "Explicit frame anchors remain native")
PyresinQoLDB.tooltipAnchorSpells = true
GameTooltip_SetDefaultAnchor(GameTooltip, {})
GameTooltip.data = { type = Enum.TooltipDataType.Spell }
GameTooltip.scripts.OnShow()
assert(GameTooltip.anchor == "ANCHOR_RIGHT", "Spell owner anchoring takes precedence over cursor mode")
print("PASS: metadata isolation, restricted values, cache misses, live targets, NineSlice colors and anchors")
