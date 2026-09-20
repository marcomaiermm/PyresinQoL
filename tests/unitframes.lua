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
PyresinQoLDB = { playerClassColor = false, targetClassColor = false, focusHideStatusText = true }
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
        RightText = setmetatable({ alpha = 1 }, { __index = text }) }
    bar.scripts.OnEnter = function(self) self.nativeTooltip = true end
    bar.scripts.OnLeave = function(self) self.nativeTooltip = false end
    function bar:HookScript() error("Leave native bar scripts untouched") end
    function bar:CreateFontString() error("Do not create a custom hover display") end
    function bar:GetStatusBarTexture() return texture end
    function bar:GetStatusBarColor() return unpack(self.color) end
    function bar:SetStatusBarColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
    function bar:SetStatusBarTexture() error("Preserve Blizzard's texture") end
    function bar:GetValue() error("Do not read restricted status-bar values") end
    function bar:GetMinMaxValues() error("Do not read restricted status-bar limits") end
    function bar:UpdateTextString() error("Do not run Blizzard's formatter in addon context") end
    function bar:UpdateTextStringWithValues() error("Do not run Blizzard's formatter in addon context") end
    return bar
end
PlayerFrame = { healthbar = Bar(), manabar = Bar() }
TargetFrame = { healthbar = Bar(), manabar = Bar(), Update = function() end }
PetFrame = { healthbar = Bar(), manabar = Bar() }
FocusFrame = { healthbar = Bar(), manabar = Bar() }
TargetFrame.totFrame = {
    healthbar = { DeadText = Bar().TextString, UnconsciousText = Bar().TextString }, manabar = {},
}
for _, frame in ipairs({ TargetFrame, FocusFrame }) do
    frame.TargetFrameContent = { TargetFrameContentMain = {
        HealthBarsContainer = { DeadText = Bar().TextString, UnconsciousText = Bar().TextString },
    } }
end
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
module.UpdateStatusText() -- Settings can change before PLAYER_LOGIN.
events:callback("PLAYER_LOGIN")
assert(events.event == nil)
assert(FocusFrame.healthbar.TextString.alpha == 0 and FocusFrame.manabar.LeftText.alpha == 0,
    "Apply saved visibility at login, even before a focus exists")
PyresinQoLDB.focusHideStatusText = false
module.UpdateStatusText()
assert(FocusFrame.healthbar.TextString.alpha == 0.8 and FocusFrame.manabar.LeftText.alpha == 0.6)
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

function SetCVar() error("Text visibility must not change global settings") end
for _, bar in ipairs({ hp, PlayerFrame.manabar, target, TargetFrame.manabar }) do
    bar.scripts.OnEnter(bar)
    assert(bar.nativeTooltip and bar.TextString.value == "native")
    assert(bar.TextString.alpha == 0.8 and bar.LeftText.alpha == 0.6 and bar.RightText.alpha == 1)
    bar.scripts.OnLeave(bar)
    assert(not bar.nativeTooltip)
end
print("PASS: native hover scripts and text retained, without custom overlays or restricted value reads")

local statusFrames = { pet = PetFrame, target = TargetFrame, focus = FocusFrame }
for _, unit in ipairs({ "pet", "target", "targettarget", "focus" }) do
    local key = unit .. "HideStatusText"
    PyresinQoLDB[key] = true
    module.UpdateStatusText()
    module.UpdateStatusText() -- Repeated changes must preserve the original opacity.
    for otherUnit, frame in pairs(statusFrames) do
        for _, bar in ipairs({ frame.healthbar, frame.manabar }) do
            assert(bar.TextString.alpha == (unit == otherUnit and 0 or 0.8))
            assert(bar.LeftText.alpha == (unit == otherUnit and 0 or 0.6))
            assert(bar.RightText.alpha == (unit == otherUnit and 0 or 1))
        end
    end
    for _, otherUnit in ipairs({ "target", "focus" }) do
        local container = statusFrames[otherUnit].TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
        assert(container.DeadText.alpha == (unit == otherUnit and 0 or 0.8))
        assert(container.UnconsciousText.alpha == (unit == otherUnit and 0 or 0.8))
    end
    assert(TargetFrame.totFrame.healthbar.DeadText.alpha == (unit == "targettarget" and 0 or 0.8))
    assert(TargetFrame.totFrame.healthbar.UnconsciousText.alpha == (unit == "targettarget" and 0 or 0.8))
    assert(PlayerFrame.healthbar.TextString.alpha == 0.8, "Never hide the player's text")
    TargetFrame:Update()
    PyresinQoLDB[key] = false
    module.UpdateStatusText()
end
assert(TargetFrame.totFrame.healthbar.DeadText.alpha == 0.8)
assert(FocusFrame.healthbar.TextString.alpha == 0.8)
for _, bar in ipairs({ target, TargetFrame.manabar }) do
    bar.scripts.OnEnter(bar)
    PyresinQoLDB.targetHideStatusText = true
    module.UpdateStatusText()
    assert(bar.nativeTooltip and bar.TextString.alpha == 0 and bar.LeftText.alpha == 0)
    bar.scripts.OnLeave(bar)
    bar.scripts.OnEnter(bar)
    assert(bar.nativeTooltip and bar.RightText.alpha == 0)
    PyresinQoLDB.targetHideStatusText = false
    module.UpdateStatusText()
    assert(bar.TextString.alpha == 0.8 and bar.LeftText.alpha == 0.6 and bar.RightText.alpha == 1)
    bar.scripts.OnLeave(bar)
end
print("PASS: independent pet/target/target-of-target/focus text, saved visibility, sparse state-only bars and opacity restoration")
