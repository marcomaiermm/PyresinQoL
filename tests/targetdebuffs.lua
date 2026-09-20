-- luajit tests/targetdebuffs.lua
local module = {}
local ns, events, container = {}, nil, nil
local casterTooltipEnabled = false
function SetCVar(name, value)
    assert(name == "tooltipShowAuraCasterNames" and value == "1")
    assert(not casterTooltipEnabled, "Enable native caster tooltips once, not on every aura update")
    casterTooltipEnabled = true
end
PyresinQoLDB = {} -- Fresh install before deferred settings registration: both options default on.
TargetFrameAuraContainerDefaults = { MaxDebuffs = 16 }
AnchorUtil = { FlowDirection = { Right = 1, Up = 2, Down = 3 } }
local function Region(parent, layer)
    local region = { parent = parent, layer = layer }
    function region:SetPoint(...)
        local point = { ... }
        assert(not (TargetFrame and self == TargetFrame.spellbar and point[2] == container),
            "Anchoring disallowed: native castbar would inherit UntrustedLayoutScriptExecution")
        self.point = point
    end
    function region:ClearAllPoints() self.point = nil end
    function region:SetAllPoints() self.allPoints = true end
    function region:SetSize(w, h) self.width, self.height = w, h end
    function region:SetShown(shown) self.shown = shown end
    function region:SetShadowColor() end
    function region:SetShadowOffset() end
    function region:SetFrameLevel(level) self.level = level end
    function region:GetFrameLevel() return self.level or 1 end
    function region:CreateTexture(_, drawLayer) return Region(self, drawLayer) end
    function region:CreateFontString(_, drawLayer) return Region(self, drawLayer) end
    function region:AddForbiddenAspects(aspects) self.aspects = aspects end
    return region
end
local function Button()
    local button = Region()
    function button:SetTooltipAnchorPoint(point) self.tooltipAnchor = point end
    function button:SetIcon(icon) self.icon = icon end
    function button:AddDispelTypeTexture(border, options) self.border = border; self.borderOptions = options end
    function button:SetDurationCooldown(cooldown) self.cooldown = cooldown end
    function button:SetDurationText() error("Use the native cooldown countdown, not a separate duration label") end
    function button:SetApplicationCount(text) self.count = text end
    function button:SetCasterName() error("Caster names belong in Blizzard's tooltip, not on aura buttons") end
    return button
end
local native = { maximum = 16 }
function native:SetMaxDebuffs(maximum) self.maximum = maximum end
TargetFrame = { spellbar = Region() }
TargetFrame.spellbar.point = { "native" }
function TargetFrame:GetAuraContainer() return native end
function TargetFrame:IsTargetOfTargetShown() return self.haveToT end
function TargetFrame:ConfigureAuraContainer() native:SetMaxDebuffs(self.maxDebuffs or 16) end
function TargetFrame.spellbar:AdjustPosition() error("Blizzard must position its castbar in native context") end
function TargetFrame.spellbar:AddForbiddenAspects() error("Do not change the native castbar's forbidden aspects") end
function hooksecurefunc(owner, name, callback)
    assert(owner ~= TargetFrame.spellbar, "Do not hook native castbar positioning")
    local original = assert(owner[name])
    owner[name] = function(...) original(...); callback(...) end
end
function CreateFrame(kind, _, parent, template)
    local frame = Region(parent)
    if kind == "AuraContainer" then
        assert(template == "CustomAuraContainerTemplate" and parent == TargetFrame)
        container = frame
        frame.groups = {}
        function frame:SetUnit(unit) assert(unit == "target"); self.unit = unit end
        function frame:SetEnabled(enabled) self.enabled = enabled end
        function frame:AddAuraGroup(key, filter, options)
            local button = Button()
            options.initializeFrame(button)
            self.groups[key] = { filter = filter, options = options, button = button, enabled = true }
        end
        function frame:SetAuraGroupEnabled(key, enabled)
            assert(type(enabled) == "boolean")
            self.groups[key].enabled = enabled
        end
        function frame:SetFlowLayoutAnchorPoint(point) self.anchor = point end
        function frame:SetFlowLayoutGrowthDirection(x, y) self.growth = { x, y } end
        function frame:SetFlowLayoutMaximumLineSize(width) self.lineWidth = width end
        function frame:UpdateAllAuras() self.refreshes = (self.refreshes or 0) + 1 end
    elseif kind == "Cooldown" then
        assert(template == "CooldownFrameTemplate")
        function frame:SetReverse(reverse) self.reverse = reverse end
        function frame:SetHideCountdownNumbers(hidden) self.hideNumbers = hidden end
        function frame:SetCountdownFont(font) self.countdownFont = font end
        function frame:SetUseAuraDisplayTime(enabled) self.auraDisplayTime = enabled end
    elseif not parent then
        events = frame
        function frame:RegisterEvent(event) self.event = event end
        function frame:UnregisterEvent(event) assert(event == self.event); self.event = nil end
        function frame:SetScript(script, callback) assert(script == "OnEvent"); self.callback = callback end
    end
    return frame
end
ns.RegisterModule = function(id, initialize) assert(id == "unitFrames"); initialize(module) end
assert(loadfile("Modules/UnitFrames/TargetDebuffs.lua"))("PyresinQoL", ns)
module.UpdateTargetDebuffs() -- Settings can initialize before login.
events:callback("PLAYER_LOGIN")
assert(not events.event and native.maximum == 0 and container.enabled and container.shown)
assert(casterTooltipEnabled, "Blizzard's native caster line must be enabled")
local own, other, timed = container.groups.Own, container.groups.Other, container.groups.OtherTimed
assert(own.filter == "HARMFUL|INCLUDE_NAME_PLATE_ONLY|PLAYER")
assert(other.filter == "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!PLAYER" and timed.filter == other.filter)
assert(not own.button.cooldown.hideNumbers and other.button.cooldown.hideNumbers and not timed.button.cooldown.hideNumbers)
assert(own.enabled and other.enabled and not timed.enabled)
for _, group in pairs(container.groups) do
    local button = group.button
    assert(button.icon and button.border and button.count and button.cooldown.reverse)
    assert(button.count.parent ~= button.cooldown, "Permanent auras must retain their stack counts")
    assert(button.cooldown.countdownFont == "NumberFontNormalSmall" and button.cooldown.auraDisplayTime)
    assert(button.tooltipAnchor == "ANCHOR_RIGHT")
end
assert(container.point[1] == "TOPLEFT" and container.point[2] == native and container.lineWidth == 122,
    "Debuffs must follow the target's aura area, not the castbar below target-of-target")
assert(container.point[3] == "BOTTOMLEFT" and container.point[4] == 0 and container.point[5] == -3)
assert(TargetFrame.spellbar.point[1] == "native" and not TargetFrame.spellbar.aspects)
PyresinQoLDB.targetDebuffsOnlyMine = false
module.UpdateTargetDebuffs()
assert(not other.enabled and timed.enabled and own.enabled)
TargetFrame.haveToT = true
TargetFrame:ConfigureAuraContainer()
assert(native.maximum == 0 and container.lineWidth == 101 and container.point[2] == native)
TargetFrame.spellbar:SetShown(false)
TargetFrame.spellbar:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 43, -100)
module.UpdateTargetDebuffs()
assert(container.point[2] == native and container.point[5] == -3, "Hidden or moved castbars must not move debuffs")
TargetFrame.spellbar:SetPoint("native")
assert(TargetFrame.spellbar.point[1] == "native")
TargetFrame.buffsOnTop = true
TargetFrame:ConfigureAuraContainer()
assert(container.point[1] == "BOTTOMLEFT" and container.point[2] == native and container.point[3] == "TOPLEFT")
assert(container.anchor == "BOTTOMLEFT" and container.growth[2] == AnchorUtil.FlowDirection.Up)
assert(TargetFrame.spellbar.point[1] == "native")
PyresinQoLDB.targetDebuffs = false
TargetFrame.maxDebuffs = 8
module.UpdateTargetDebuffs()
assert(native.maximum == 8 and not container.enabled and not container.shown)
TargetFrame.buffsOnTop = false
PyresinQoLDB.targetDebuffs = true
PyresinQoLDB.targetDebuffsOnlyMine = true
TargetFrame:ConfigureAuraContainer()
assert(native.maximum == 0 and container.shown and other.enabled and not timed.enabled)
local spellbar = TargetFrame.spellbar
TargetFrame.spellbar = nil
module.UpdateTargetDebuffs()
assert(container.point[2] == native and container.point[1] == "TOPLEFT")
TargetFrame.spellbar = spellbar
TargetFrame:ConfigureAuraContainer()
assert(container.point[2] == native and spellbar.point[1] == "native")
print("PASS: own/all timer toggle, native caster tooltip, permanent stacks, native restoration and aura placement independent of castbar/ToT")
