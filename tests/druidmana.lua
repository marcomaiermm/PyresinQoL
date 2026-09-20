-- luajit tests/druidmana.lua
local function SecretAccess() error("Do not calculate or inspect restricted mana") end
local secret = setmetatable({}, { __index = SecretAccess, __lt = SecretAccess,
    __le = SecretAccess, __div = SecretAccess, __concat = SecretAccess, __tostring = SecretAccess })
function issecretvalue(value) return rawequal(value, secret) end
Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3 } }
PowerBarColor = { MANA = { r = 0, g = 0.4, b = 1 } }
PlayerFrame = { manabar = {} }
local class, power, vehicle = "DRUID", 0, false
local current, maximum, reads = 700, 1000, 0
function UnitClass(unit) assert(unit == "player"); return class, class end
function UnitPowerType(unit) assert(unit == "player"); return power end
function UnitHasVehicleUI(unit) assert(unit == "player"); return vehicle end
function UnitPower(unit, kind)
    assert(unit == "player" and kind == Enum.PowerType.Mana)
    reads = reads + 1
    return current
end
function UnitPowerMax(unit, kind)
    assert(unit == "player" and kind == Enum.PowerType.Mana)
    return maximum
end
local frames, bar = {}, nil
function CreateFrame(kind, name, parent, template)
    assert(not template, "Do not run native restricted text formatters from addon context")
    local frame = { events = {} }
    frames[#frames + 1] = frame
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event, unit) assert(unit == "player"); self.events[event] = unit end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, callback)
        assert(script == "OnEvent", "No per-frame polling")
        self.callback = callback
    end
    if kind == "StatusBar" then
        assert(name == "PyresinQoLDruidManaBar" and parent == PlayerFrame)
        bar = frame
        function bar:SetSize(w, h) assert(w == 124 and h == 10) end
        function bar:SetPoint(point, relative, relativePoint)
            assert(point == "TOPRIGHT" and relative == PlayerFrame.manabar and relativePoint == "BOTTOMRIGHT")
        end
        function bar:SetStatusBarTexture(texture) assert(type(texture) == "string") end
        function bar:SetStatusBarColor(r, g, b) assert(r == 0 and g == 0.4 and b == 1) end
        function bar:CreateTexture()
            return { SetPoint = function() end, SetColorTexture = function() end }
        end
        function bar:CreateFontString()
            return {
                SetPoint = function() end,
                SetFormattedText = function(self, format, value, max)
                    assert(format == "%d / %d")
                    self.current, self.maximum = value, max
                end,
            }
        end
        function bar:SetShown(shown) self.shown = shown end
        function bar:SetMinMaxValues(min, max) assert(min == 0); self.maximum = max end
        function bar:SetValue(value) self.current = value end
    end
    return frame
end
local function Initialize()
    frames, bar = {}, nil
    local module = {}
    local ns = { RegisterModule = function(id, initialize)
        assert(id == "unitFrames")
        initialize(module)
    end }
    assert(loadfile("Modules/UnitFrames/DruidMana.lua"))("PyresinQoL", ns)
    return module
end
local function Fire(event, unit, token)
    local events = frames[1]
    if events.events[event] == true or events.events[event] == unit then
        events:callback(event, unit, token)
    end
end

PyresinQoLDB = { druidManaPreview = true } -- A saved temporary preview flag must no longer enable it.
local module = Initialize()
module.UpdateDruidMana() -- Settings may run before login.
Fire("PLAYER_LOGIN")
assert(not bar.shown and reads == 0 and not frames[1].events.PLAYER_LOGIN)
power = Enum.PowerType.Energy
Fire("UNIT_DISPLAYPOWER", "player")
assert(bar.shown and bar.current == 700 and bar.maximum == 1000)
current = 500
Fire("UNIT_POWER_FREQUENT", "player", "MANA")
assert(bar.current == 500 and bar.Text.current == 500)
local previousReads = reads
Fire("UNIT_POWER_FREQUENT", "target", "MANA")
Fire("UNIT_POWER_FREQUENT", "player", "ENERGY")
assert(reads == previousReads, "Ignore other units and energy/rage ticks")
maximum = 1500
Fire("UNIT_MAXPOWER", "player", "MANA")
assert(bar.maximum == 1500 and bar.Text.maximum == 1500)
power = Enum.PowerType.Rage
Fire("UNIT_DISPLAYPOWER", "player")
assert(bar.shown and bar.current == 500)
current, maximum = secret, secret
Fire("UNIT_POWER_FREQUENT", "player", "MANA")
assert(rawequal(bar.current, secret) and rawequal(bar.maximum, secret))
assert(rawequal(bar.Text.current, secret) and rawequal(bar.Text.maximum, secret))
vehicle = true
Fire("UNIT_ENTERED_VEHICLE", "player")
assert(not bar.shown)
vehicle = false
Fire("UNIT_EXITED_VEHICLE", "player")
assert(bar.shown)
PyresinQoLDB.druidMana = false
module.UpdateDruidMana()
previousReads = reads
Fire("UNIT_POWER_FREQUENT", "player", "MANA")
assert(not bar.shown and reads == previousReads)
PyresinQoLDB.druidMana = true
module.UpdateDruidMana()
assert(bar.shown)
power = Enum.PowerType.Mana
Fire("UNIT_DISPLAYPOWER", "player")
assert(not bar.shown)
power = secret
Fire("UNIT_DISPLAYPOWER", "player")
assert(not bar.shown, "Never compare a restricted power type")
power = Enum.PowerType.Energy
module = Initialize()
Fire("PLAYER_LOGIN")
assert(bar.shown, "Reloading while shapeshifted must immediately show mana")
Fire("PLAYER_ENTERING_WORLD")
assert(bar.shown)
for _, otherClass in ipairs({ "MAGE", "WARRIOR", "ROGUE", "WARLOCK" }) do
    class = otherClass
    module = Initialize()
    previousReads = reads
    module.UpdateDruidMana()
    assert(#frames == 0 and reads == previousReads, "Other classes must not create mana frames or read resources")
end
print("PASS: druid-only mana, cat/bear visibility, live values, restricted values, settings and reload")
print("PASS: saved preview flag ignored; other classes create no frames or listeners")
