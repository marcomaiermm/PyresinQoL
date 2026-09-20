-- luajit tests/tooltip.lua
FACTION_ALLIANCE = arg[1] == "de" and "Allianz" or "Alliance"
FACTION_HORDE = "Horde"
local module = {}
local ns, postCall, objectPostCall = {}, nil, nil
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
GameTooltip = { StatusBar = bar, scripts = {}, lines = {} }
function GameTooltip:GetUnit() return "Name", unit end
function GameTooltip:NumLines() return #self.lines end
function GameTooltip:GetLeftLine(index) return self.lines[index] end
function GameTooltip:HookScript(event, callback) self.scripts[event] = callback end
function GameTooltip:GetPrimaryTooltipInfo() return self.info end
function GameTooltip:ClearAllPoints() self.point = nil end
function GameTooltip:SetAnchorType(anchor) self.anchor = anchor end
Enum = { TooltipDataType = { Unit = 2, Object = 4 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, callback)
    if kind == Enum.TooltipDataType.Object then objectPostCall = callback
    else assert(kind == Enum.TooltipDataType.Unit); postCall = callback end
end }
ns.RegisterModule = function(id, initialize) assert(id == "tooltips"); initialize(module) end
assert(loadfile("Modules/Tooltips/Tooltip.lua"))("PyresinQoL", ns)
bar.scripts.OnUpdate(bar, 0.1)
assert(bar.text.value == "", "Safe before settings load")
objectPostCall(GameTooltip)
assert(not GameTooltip.anchor, "Object tooltip is safe before settings load")
PyresinQoLDB = { tooltipHealth = true, tooltipGuildRank = true }
local function Rebuild(guildText, factionText)
    GameTooltip.scripts.OnTooltipCleared()
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
GameTooltip.info = { getterName = "GetWorldCursor" }
GameTooltip.anchor, GameTooltip.point = "ANCHOR_NONE", "BOTTOMRIGHT"
GameTooltip.lines = { Text("Goldshire") }
objectPostCall(GameTooltip)
assert(GameTooltip.anchor == "ANCHOR_CURSOR" and not GameTooltip.point, "Signs use the native cursor anchor")
assert(GameTooltip.lines[1].value == "Goldshire", "Anchoring preserves the object's text")
objectPostCall({}) -- Other tooltip frames stay untouched.
for _, info in ipairs({ {}, { getterName = "GetHyperlink" } }) do
    GameTooltip.info, GameTooltip.anchor = info, "ANCHOR_RIGHT"
    objectPostCall(GameTooltip)
    assert(GameTooltip.anchor == "ANCHOR_RIGHT", "Only world cursor objects move")
end
GameTooltip.info = nil
objectPostCall(GameTooltip)
assert(GameTooltip.anchor == "ANCHOR_RIGHT", "Ignore missing tooltip info")
-- SetWorldCursor resets the owner/anchor before processing each new world hover.
GameTooltip.info, GameTooltip.anchor = { getterName = "GetWorldCursor" }, "ANCHOR_NONE"
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
