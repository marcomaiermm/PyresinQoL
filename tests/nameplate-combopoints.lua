-- luajit tests/nameplate-combopoints.lua
local module, events, hooks, plates = {}, nil, {}, {}
local class, maximum, vehicle = "ROGUE", 5, false
local reads, creations = 0, 0
local function SecretAccess() error("Compared or calculated a secret combo count") end
local secrets = {}
local function Secret(value)
    local token = setmetatable({}, { __lt = SecretAccess, __le = SecretAccess, __add = SecretAccess,
        __sub = SecretAccess, __tostring = SecretAccess })
    secrets[token] = value
    return token
end
function issecretvalue(value) return secrets[value] ~= nil end
local function Native(value) return issecretvalue(value) and secrets[value] or value end
PyresinQoLDB = {}
Enum = { PowerType = { ComboPoints = 4 } }
NamePlateConstants = { PREVIEW_UNIT_TOKEN = "preview" }
function UnitClass() return class, class end
function UnitPowerMax(unit, power) assert(unit == "player" and power == 4); return maximum end
function UnitHasVehicleUI() return vehicle end
function UnitCanAttack(_, unit) return not plates[unit].friendly end
function UnitIsDeadOrGhost(unit) return plates[unit].dead end
function GetComboPoints(unit, target)
    assert(unit == "player" and target ~= "target" and target ~= "preview")
    reads = reads + 1
    return assert(plates[target].count)
end
function UnitPower() error("Do not duplicate the player's global points across all enemies") end
NamePlateDriverFrame = {
    GetNamePlateForUnit = function(_, unit) return plates[unit] end,
    IsScriptNamePlateRegistered = function(_, unit) return plates[unit] ~= nil end,
}
C_NamePlate = { GetNamePlates = function()
    local result = {}
    for unit, plate in pairs(plates) do if unit ~= "preview" then result[#result + 1] = plate end end
    return result
end }
function hooksecurefunc(owner, method, callback)
    assert(owner == NamePlateDriverFrame)
    hooks[method] = callback
end
local function Widget(parent)
    local frame = { parent = parent, children = {}, shown = true, registered = {} }
    if parent then parent.children[#parent.children + 1] = frame end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetPoint(...) self.anchor = { ... } end
    function frame:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function frame:CreateTexture()
        return { SetAtlas = function(self, atlas) self.atlas = atlas end }
    end
    function frame:SetStatusBarTexture(texture) self.texture = texture end
    function frame:SetValue(value)
        self.argument = value
        self.fill = math.max(0, math.min(1, (Native(value) - self.minimum) / (self.maximum - self.minimum)))
    end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(value) self.shown = value end
    function frame:RegisterEvent(event) self.registered[event] = true end
    function frame:RegisterUnitEvent(event, unit) assert(unit == "player"); self.registered[event] = unit end
    function frame:SetScript(script, callback) assert(script == "OnEvent", "No polling"); self.callback = callback end
    return frame
end
function CreateFrame(kind, _, parent)
    creations = creations + 1
    local frame = Widget(parent)
    if not parent then events = frame end
    return frame
end
local function Plate(unit, count, frame)
    frame = frame or Widget()
    frame.healthBar, frame.CastBarsContainer = {}, {}
    function frame:IsForbidden() return self.forbidden end
    plates[unit] = { UnitFrame = frame, count = count, GetUnit = function() return unit end }
    return frame
end
local function Fire(event, unit, power) events.callback(events, event, unit, power) end
local function Add(unit) hooks.OnNamePlateAdded(NamePlateDriverFrame, unit) end
local function Remove(unit)
    plates[unit].UnitFrame = nil -- Native removal returns the UnitFrame to its pool first.
    hooks.OnNamePlateRemoved(NamePlateDriverFrame, unit)
    plates[unit] = nil
end
local function Check(frame, count, capacity)
    local row = assert(frame.children[1])
    assert(row.shown and row.width == capacity * 16 - 2)
    assert(row.anchor[2] == frame.CastBarsContainer and row.anchor[3] == "BOTTOM")
    for index, background in ipairs(row.children) do
        assert(background.shown == (index <= capacity))
        if index <= capacity then
            assert(background.fill == (count > 0 and 1 or 0), "Zero points must leave no empty row")
            assert(background.children[1].fill == (index <= count and 1 or 0), "Each enemy needs its own count")
        end
    end
    return row
end
local first, second, preview = Plate("nameplate1", 2), Plate("nameplate2", 4), Plate("preview", 0)
local ns = { RegisterModule = function(id, initialize) assert(id == "unitFrames"); initialize(module) end }
assert(loadfile("Modules/UnitFrames/NameplateComboPoints.lua"))("PyresinQoL", ns)
Fire("PLAYER_LOGIN")
Check(first, 2, 5); Check(second, 4, 5); Check(preview, 3, 5)
assert(reads == 2 and events.registered.UNIT_POWER_FREQUENT == "player")
local before = reads
Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
assert(reads == before, "Ignore unrelated power events")
plates.nameplate1.count, plates.nameplate2.count = 0, 1
Fire("PLAYER_TARGET_CHANGED")
Check(first, 0, 5); Check(second, 1, 5)
for count = 0, 5 do
    plates.nameplate2.count = Secret(count)
    Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
    Check(second, count, 5)
    for _, background in ipairs(second.children[1].children) do
        assert(rawequal(background.argument, plates.nameplate2.count))
        assert(rawequal(background.children[1].argument, plates.nameplate2.count))
    end
end
maximum = 7
Fire("UNIT_MAXPOWER", "player", "COMBO_POINTS")
Check(second, 5, 7)
maximum = Secret(7)
plates.nameplate2.count = Secret(7)
Fire("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
Check(second, 7, 7)
maximum, plates.nameplate2.count = 5, 3
Fire("UNIT_MAXPOWER", "player", "COMBO_POINTS")
Check(second, 3, 5)
for _, flag in ipairs({ "dead", "friendly" }) do
    plates.nameplate2[flag] = true
    Fire("UNIT_HEALTH", "nameplate2")
    assert(not second.children[1].shown)
    plates.nameplate2[flag] = false
    Fire("UNIT_FACTION", "nameplate2")
    Check(second, 3, 5)
end
vehicle = true
Fire("UNIT_ENTERED_VEHICLE", "player")
assert(not first.children[1].shown and not second.children[1].shown)
vehicle = false
Fire("UNIT_EXITED_VEHICLE", "player")
Check(second, 3, 5)
local created = creations
Remove("nameplate2")
assert(not second.children[1].shown)
-- A pooled UnitFrame retains its native cast bar and our anchored children.
local castBar = second.CastBarsContainer
Plate("nameplate3", 0, second)
second.CastBarsContainer = castBar
Add("nameplate3")
Check(second, 0, 5)
assert(creations == created, "Recycle existing points without stale state or new frames")
PyresinQoLDB.nameplateComboPoints = false
module.UpdateNameplateComboPoints()
assert(not first.children[1].shown and not second.children[1].shown and not preview.children[1].shown)
before = reads
Fire("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
local third = Plate("nameplate4", 1)
Add("nameplate4")
assert(reads == before and creations == created)
PyresinQoLDB.nameplateComboPoints = true
module.UpdateNameplateComboPoints()
Check(third, 1, 5); Check(preview, 3, 5)
local forbidden = Plate("nameplate5", 1)
forbidden.forbidden = true
Add("nameplate5")
assert(#forbidden.children == 0)
Remove("nameplate5")
maximum = 0
Fire("UPDATE_SHAPESHIFT_FORM")
assert(not third.children[1].shown)
maximum = 5
Fire("UNIT_DISPLAYPOWER", "player")
Check(third, 1, 5)
class, module, plates, hooks = "DRUID", {}, {}, {}
local druid = Plate("nameplate1", 3)
assert(loadfile("Modules/UnitFrames/NameplateComboPoints.lua"))("PyresinQoL", ns)
Fire("PLAYER_ENTERING_WORLD")
local row = Check(druid, 3, 5)
assert(row.children[1].texture.atlas == "UF-DruidCP-BG-Dis")
assert(row.children[1].children[1].texture.atlas == "UF-DruidCP-Icon")
class, module = "MAGE", {}
created = creations
assert(loadfile("Modules/UnitFrames/NameplateComboPoints.lua"))("PyresinQoL", ns)
assert(creations == created and not module.UpdateNameplateComboPoints, "Other classes need no combo tracking")
print("PASS: per-enemy combo points, secret/zero counts, capacity, recycling, preview, live toggle and class gating")
