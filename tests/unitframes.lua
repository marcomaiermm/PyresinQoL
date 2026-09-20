-- luajit tests/unitframes.lua
local module = {}
local ns, events = {}, nil
local function SecretAccess() error("Calculated or compared a secret value") end
local secret = setmetatable({}, { __index = SecretAccess, __lt = SecretAccess,
    __le = SecretAccess, __div = SecretAccess, __concat = SecretAccess, __tostring = SecretAccess })
function issecretvalue(value) return rawequal(value, secret) end
local units = { player = "MAGE", target = "WARRIOR" }
function UnitClass(unit) return unit, units[unit] end
function UnitIsPlayer(unit) return units[unit] ~= nil end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
PyresinQoLDB = { playerClassColor = false, targetClassColor = false }
local threatCVars = { threatShowNumeric = "0", threatWarning = "0" }
function SetCVar(name, value)
    assert(threatCVars[name] and type(value) == "string")
    threatCVars[name] = value
end
local function Bar()
    local text = { value = "native", points = {}, alpha = 0.8 }
    function text:ClearAllPoints() self.points = {} end
    function text:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function text:SetText() error("Blizzard owns the status text") end
    function text:Show() error("Blizzard owns text visibility") end
    function text:Hide() error("Blizzard owns text visibility") end
    function text:GetAlpha() return self.alpha end
    function text:SetAlpha(alpha) self.alpha = alpha end
    local texture = { desaturation = 0 }
    function texture:GetDesaturation() return self.desaturation end
    function texture:SetDesaturation(value) self.desaturation = value end
    function texture:SetAtlas() error("Preserve Blizzard's atlas") end
    local bar = { TextString = text, texture = texture, color = { 1, 1, 1, 1 }, scripts = {},
        LeftText = setmetatable({ alpha = 0.6 }, { __index = text }),
        RightText = setmetatable({ alpha = 1 }, { __index = text }), current = 50, maximum = 100 }
    bar.scripts.OnEnter = function(self) self.nativeTooltip = true end
    bar.scripts.OnLeave = function(self) self.nativeTooltip = false end
    function bar:HookScript(name, callback)
        local original = self.scripts[name]
        self.scripts[name] = function(...)
            if original then original(...) end
            callback(...)
        end
    end
    function bar:CreateFontString(_, layer, template)
        assert(layer == "OVERLAY" and template == "TextStatusBarText")
        local hover = {}
        function hover:SetPoint(...) self.point = { ... } end
        function hover:Show() self.shown = true end
        function hover:Hide() self.shown = false end
        function hover:SetFormattedText(format, current, maximum)
            self.arguments = { format, current, maximum }
            if not issecretvalue(current) and not issecretvalue(maximum) then
                self.value = format:format(current, maximum)
            end
        end
        self.hover = hover
        return hover
    end
    function bar:GetStatusBarTexture() return texture end
    function bar:GetStatusBarColor() return unpack(self.color) end
    function bar:SetStatusBarColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
    function bar:SetStatusBarTexture() error("Preserve Blizzard's texture") end
    function bar:GetValue()
        assert(self.TextString.alpha == 0, "Read values only for the active hover display")
        return self.current
    end
    function bar:GetMinMaxValues()
        assert(self.TextString.alpha == 0, "Read values only for the active hover display")
        return secret, self.maximum
    end
    function bar:UpdateTextString() error("Do not run Blizzard's formatter in addon context") end
    function bar:UpdateTextStringWithValues() error("Do not run Blizzard's formatter in addon context") end
    return bar
end
PlayerFrame = { healthbar = Bar(), manabar = Bar() }
TargetFrame = { healthbar = Bar(), manabar = Bar(), Update = function() end }
local hooks = {}
function hooksecurefunc(owner, method, callback)
    assert(method ~= "UpdateTextStringWithValues" and method ~= "UpdateTextString", "Leave native text updates untouched")
    hooks[owner] = hooks[owner] or {}
    hooks[owner][method] = callback
    local original = assert(owner[method])
    owner[method] = function(...) original(...); callback(...) end
end
function CreateFrame()
    events = {}
    function events:RegisterEvent(name) self.event = name end
    function events:UnregisterEvent(name) assert(self.event == name); self.event = nil end
    function events:SetScript(_, callback) self.callback = callback end
    return events
end
ns.RegisterModule = function(id, initialize) assert(id == "unitFrames"); initialize(module) end
assert(loadfile("Modules/UnitFrames/UnitFrames.lua"))("PyresinQoL", ns)
module.UpdatePlayerFrame()
events:callback("PLAYER_LOGIN")
assert(events.event == nil)
assert(threatCVars.threatShowNumeric == "1" and threatCVars.threatWarning == "3",
    "Enable native numeric threat at login, including solo play")
PyresinQoLDB.targetThreat = false
module.UpdateTargetThreat()
assert(threatCVars.threatShowNumeric == "0" and threatCVars.threatWarning == "3",
    "Disabling numbers must preserve threat warnings")
threatCVars.threatWarning = "1"
module.UpdateTargetThreat()
assert(threatCVars.threatWarning == "1", "Disabled feature must leave warning preferences alone")
PyresinQoLDB.targetThreat = true
module.UpdateTargetThreat()
assert(threatCVars.threatShowNumeric == "1" and threatCVars.threatWarning == "3")
local hp, target = PlayerFrame.healthbar, TargetFrame.healthbar
PyresinQoLDB.playerClassColor = true
module.UpdatePlayerFrame()
assert(hp.color[1] == 0.25 and hp.texture.desaturation == 1)
assert(target.color[1] == 1 and target.texture.desaturation == 0)
PyresinQoLDB.targetClassColor = true
module.UpdatePlayerFrame()
assert(target.color[1] == 0.78 and target.texture.desaturation == 1)
hp:SetStatusBarColor(0.8, 0.8, 0.8)
assert(hp.color[1] == 0.25, "Native refresh must retain class color without recursion")
units.target = "MAGE"
TargetFrame:Update()
assert(target.color[1] == 0.25, "Target changes must update class color")
units.target = nil
TargetFrame:Update()
assert(target.color[1] == 1 and target.texture.desaturation == 0, "NPCs and cleared targets restore native colors")
units.target = "WARRIOR"
TargetFrame:Update()
assert(target.color[1] == 0.78)
units.target = secret
TargetFrame:Update()
assert(target.color[1] == 1 and target.texture.desaturation == 0, "Restricted classes retain native appearance")
units.target = "WARRIOR"
TargetFrame:Update()

for _, point in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
    PyresinQoLDB.playerHPPosition = point
    module.UpdatePlayerFrame()
    assert(#hp.TextString.points == 1 and hp.TextString.points[1][1] == point
        and hp.TextString.points[1][2] == hp and hp.TextString.points[1][3] == point)
    assert(target.TextString.points[1][1] == "CENTER")
    assert(PlayerFrame.manabar.TextString.points[1][1] == "CENTER")
end
PyresinQoLDB.targetManaPosition = "LEFT"
TargetFrame:Update()
assert(TargetFrame.manabar.TextString.points[1][1] == "LEFT")
PyresinQoLDB.playerClassColor, PyresinQoLDB.targetClassColor = false, false
module.UpdatePlayerFrame()
assert(hp.texture.desaturation == 0 and hp.color[1] == 0.8, "Restore the latest native color")
assert(target.texture.desaturation == 0 and target.color[1] == 1)
hp.texture.desaturation = 0.35
PyresinQoLDB.playerClassColor = true
module.UpdatePlayerFrame()
assert(hp.texture.desaturation == 1)
PyresinQoLDB.playerClassColor = false
module.UpdatePlayerFrame()
assert(hp.texture.desaturation == 0.35)
print("PASS: independent player/target colors, target changes, NPCs, native texture restoration, nine positions and no restricted text access")

function SetCVar() error("Hover must not change global status-text settings") end
for _, bar in ipairs({ hp, PlayerFrame.manabar, target, TargetFrame.manabar }) do
    assert(not bar.hover.shown)
    bar.scripts.OnEnter(bar)
    assert(bar.nativeTooltip and bar.hover.shown and bar.hover.value == "50 / 100")
    assert(bar.TextString.alpha == 0 and bar.LeftText.alpha == 0 and bar.RightText.alpha == 0)
    bar.scripts.OnEnter(bar) -- Repeated entry must not overwrite the saved alpha values.
    bar.current = 30
    bar.scripts.OnValueChanged(bar)
    assert(bar.hover.value == "30 / 100")
    bar.maximum = 200
    bar.scripts.OnMinMaxChanged(bar)
    assert(bar.hover.value == "30 / 200")
    bar.current, bar.maximum = secret, secret
    bar.scripts.OnValueChanged(bar)
    assert(rawequal(bar.hover.arguments[2], secret) and rawequal(bar.hover.arguments[3], secret),
        "Pass restricted values unchanged into SetFormattedText")
    bar.scripts.OnLeave(bar)
    assert(not bar.nativeTooltip and not bar.hover.shown)
    assert(bar.TextString.alpha == 0.8 and bar.LeftText.alpha == 0.6 and bar.RightText.alpha == 1)
    assert(bar.TextString.value == "native", "Keep the native text and selected format untouched")
    bar.scripts.OnValueChanged(bar) -- No value reads while not hovered.
    bar.scripts.OnEnter(bar)
    assert(bar.hover.shown)
    bar.scripts.OnHide(bar) -- Target cleared or mana bar hidden while hovered.
    assert(not bar.hover.shown and bar.TextString.alpha == 0.8)
    bar.scripts.OnLeave(bar)
end
print("PASS: HP/mana hover on player/target, native tooltips, live values, secret forwarding and restoration on leave/hide")
