-- luajit tests/nameplates.lua [optional /path/to/Blizzard_NamePlates.lua]
local module, events, hooks, plates, states = {}, nil, {}, {}, {}
local reads, creations = 0, 0
local role = "DAMAGER"
local function Region(x, y, width, height, scale)
    local region = { x = x, y = y, width = width, height = height, scale = scale or 1, visible = true }
    function region:IsForbidden() return false end
    function region:IsVisible() return self.visible end
    function region:GetRect() error("Cannot measure restricted regions") end
    function region:GetPoint() error("Cannot measure restricted regions") end
    function region:GetParent() return self.parent end
    function region:GetEffectiveScale() return self.scale end
    return region
end
function UnitGroupRolesAssigned(unit) assert(unit == "player"); return role end
local function SecretAccess() error("Calculated or compared a secret") end
local secret = setmetatable({}, { __lt = SecretAccess, __le = SecretAccess,
    __div = SecretAccess, __concat = SecretAccess, __tostring = SecretAccess })
local secretZero = setmetatable({}, getmetatable(secret))
local secretFraction = setmetatable({}, getmetatable(secret))
local nativeValues = { [secret] = 83, [secretZero] = 0, [secretFraction] = 0.4 }
function issecretvalue(value) return nativeValues[value] ~= nil end
local function Secret(value)
    local token = setmetatable({}, getmetatable(secret))
    nativeValues[token] = value
    return token
end
C_StringUtil = {}
function C_StringUtil.TruncateWhenZero(value)
    local number = issecretvalue(value) and nativeValues[value] or value
    local integer = math.floor(number)
    local text = integer == 0 and "" or tostring(integer)
    return issecretvalue(value) and Secret(text) or text
end
function C_StringUtil.WrapString(value, prefix, suffix)
    local text = issecretvalue(value) and nativeValues[value] or value
    local result = text == "" and "" or prefix .. text .. suffix
    return issecretvalue(value) and Secret(result) or result
end
Enum = { NumericRuleFormatRounding = { Down = 2 } }
function C_StringUtil.CreateNumericRuleFormatter()
    local formatter = {}
    function formatter:SetBreakpoints(points) self.points = points end
    function formatter:FormatNumber(value)
        assert(not issecretvalue(value), "FormatNumber: secret values are only allowed during untainted execution")
        local number = issecretvalue(value) and nativeValues[value] or value
        local rule
        for _, point in ipairs(self.points) do
            if number >= point.threshold then rule = point end
        end
        assert(rule, "Missing numeric format rule")
        if rule.step then
            assert(rule.rounding == Enum.NumericRuleFormatRounding.Down)
            number = math.floor(number / rule.step) * rule.step
        end
        local text = string.format(rule.format, number)
        return issecretvalue(value) and Secret(text) or text
    end
    return formatter
end
PyresinQoLDB = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local threatColors = { [0] = { 0.69, 0.69, 0.69 }, { 1, 1, 0.47 }, { 1, 0.6, 0 }, { 1, 0, 0 } }
function GetThreatStatusColor(status)
    assert(not issecretvalue(status), "Native threat color lookup rejects secret arguments")
    return unpack(assert(threatColors[status]))
end
function UnitThreatSituation(_, unit) return states[unit].status end
NamePlateConstants = { PREVIEW_UNIT_TOKEN = "preview" }
NamePlateDriverFrame = {}
function NamePlateDriverFrame:GetNamePlateForUnit(unit) return plates[unit] end
function NamePlateDriverFrame:IsScriptNamePlateRegistered(unit) return plates[unit] ~= nil end
function hooksecurefunc(owner, method, callback)
    assert(owner == NamePlateDriverFrame)
    hooks[method] = callback
end
function CreateFrame(_, _, parent)
    if parent then
        local badge = { textures = {}, scripts = {}, moves = 0 }
        parent.badge = badge
        function badge:SetSize(width, height) assert(width == 1 and height == 1) end
        function badge:SetPoint(point, anchor, relative, x, y)
            assert(anchor == parent)
            local expected = { RIGHT = { "LEFT", 42, 0 }, LEFT = { "RIGHT", -8, 0 },
                TOP = { "BOTTOM", 0, 6 }, BOTTOM = { "TOP", 0, -6 } }
            local position = assert(expected[relative])
            assert(point == position[1] and x == position[2] and y == position[3])
            self.side, self.offset, self.anchor, self.moves = relative, x, anchor, self.moves + 1
        end
        function badge:ClearAllPoints() end
        function badge:SetScript(name, callback) self.scripts[name] = callback end
        function badge:Show() self.shown = true end
        function badge:Hide() self.shown = false end
        function badge:SetAlphaFromBoolean(value, yes, no)
            self.alpha = issecretvalue(value) and secret or (value and yes or no)
        end
        function badge:CreateTexture() error("Threat labels must have no background or border") end
        function badge:CreateFontString(...) return parent:CreateFontString(...) end
        return badge
    end
    events = { registered = {} }
    function events:RegisterEvent(event) self.registered[event] = true end
    function events:SetScript(event, callback) assert(event == "OnEvent"); self.callback = callback end
    return events
end
C_NamePlate = { GetNamePlates = function()
    local result = {}
    for unit, plate in pairs(plates) do
        if unit ~= "preview" then result[#result + 1] = plate end
    end
    return result
end }
function UnitCanAttack(_, unit) return not states[unit].friendly end
function UnitIsDeadOrGhost(unit) return states[unit].dead end
function UnitDetailedThreatSituation(_, unit)
    reads = reads + 1
    local state = states[unit]
    return state.tanking, secret, 75, state.percent, secret
end
function UnitThreatPercentageOfLead(_, unit) return states[unit].lead end
local function Plate(unit, frame)
    if not frame then
        local bar = Region(100, 100, 100, 20)
        bar.texts = {}
        function bar:CreateFontString(_, layer, font)
            assert(layer == "OVERLAY" and font == "GameFontHighlight")
            creations = creations + 1
            local text = {}
            function text:SetFont(path, size, outline)
                assert(path == STANDARD_TEXT_FONT and size == 14 and outline == "OUTLINE")
            end
            function text:SetPoint(point, anchor, relative, x, y)
                local nearEdge = ({ RIGHT = "LEFT", LEFT = "RIGHT", TOP = "BOTTOM", BOTTOM = "TOP" })[bar.badge.side]
                assert(point == nearEdge and anchor == bar.badge and relative == nearEdge and x == 0 and y == 0,
                    "Anchor the visible text edge directly at the configured gap, independent of text width")
            end
            function text:ClearAllPoints() end
            function text:SetTextColor(...) self.color = { ... } end
            function text:SetText(value)
                self.argument = value
                self.value = issecretvalue(value) and nativeValues[value] or value
            end
            function text:SetAlphaFromBoolean(value, yes, no)
                self.boolean = value
                self.alpha = issecretvalue(value) and secret or (value and yes or no)
            end
            bar.texts[#bar.texts + 1] = text
            return text
        end
        frame = { healthBar = bar, IsForbidden = function(self) return self.forbidden end }
    end
    local plate = { UnitFrame = frame, GetUnit = function() return unit end }
    plates[unit] = plate
    return frame.healthBar.texts, frame
end
local function Fire(event, unit) events.callback(events, event, unit) end
local function Add(unit) hooks.OnNamePlateAdded(NamePlateDriverFrame, unit) end
local function Remove(unit)
    plates[unit].UnitFrame = nil -- Native removal releases the pooled frame before the hook.
    hooks.OnNamePlateRemoved(NamePlateDriverFrame, unit)
    plates[unit] = nil
end
local texts, frame = Plate("nameplate1")
states.nameplate1 = { tanking = false, percent = 82.4, lead = 0 }
local ns = { RegisterModule = function(id, initialize) assert(id == "unitFrames"); initialize(module) end }
assert(loadfile("Modules/UnitFrames/NameplateThreat.lua"))("PyresinQoL", ns)
Fire("PLAYER_LOGIN")
assert(texts[1].value == "82%" and texts[1].alpha == 1 and texts[2].value == "")
local badge = frame.healthBar.badge
assert(badge.shown and badge.alpha == 1)
assert(not badge.scripts.OnUpdate, "Manual positioning must not poll or measure protected frames")
for status = 0, 3 do
    states.nameplate1.status = status
    Fire("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
    for _, text in ipairs(texts) do
        assert(table.concat(text.color, ",") == table.concat(threatColors[status], ","))
    end
end
states.nameplate1 = { tanking = true, percent = 100, lead = 153.8 }
Fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
assert(texts[1].alpha == 0 and texts[2].value == "153%" and texts[2].alpha == 1)
for _, case in ipairs({ { 998.9, "998%" }, { 999, "999%" }, { 999.9, "999%" },
    { 1000, "999%+" }, { 22800, "999%+" }, { 1000000, "999%+" } }) do
    for _, value in ipairs({ case[1], Secret(case[1]) }) do
        local expected = issecretvalue(value) and (tostring(math.floor(case[1])) .. "%") or case[2]
        states.nameplate1 = { tanking = false, percent = value }
        Fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
        assert(texts[1].value == expected and texts[1].alpha == 1, "Cap public threat and forward restricted percentages")
        states.nameplate1 = { tanking = true, percent = 100, lead = value }
        Fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
        assert(texts[2].value == expected and texts[2].alpha == 1, "Cap public tank lead and forward restricted percentages")
        assert(issecretvalue(texts[2].argument) == issecretvalue(value), "Keep restricted values secret")
    end
end
states.nameplate1 = { tanking = secret, percent = secret, lead = secret, status = secret }
Fire("UNIT_THREAT_SITUATION_UPDATE", "player")
for _, text in ipairs(texts) do
    assert(issecretvalue(text.argument) and rawequal(text.boolean, secret))
end
assert(table.concat(texts[1].color, ",") == table.concat(threatColors[0], ","),
    "Secret threat states use a neutral text color without affecting percentage display")
states.nameplate1 = { tanking = true, percent = 100 }
Fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
assert(badge.alpha == 0, "Do not leave an empty badge when the tank lead is unavailable")
for _, state in ipairs({ {}, { percent = 0 }, { percent = 80, friendly = true }, { percent = 80, dead = true } }) do
    states.nameplate1 = state
    Fire("UNIT_HEALTH", "nameplate1")
    assert(texts[1].value == "" and texts[2].value == "")
    assert(not badge.shown)
end
for _, value in ipairs({ 0, 0.4, 0.99, secretZero, secretFraction }) do
    states.nameplate1 = { tanking = false, percent = value }
    Fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    assert(texts[1].value == "" and texts[2].value == "", "Zero percent must leave no number or percent sign")
    states.nameplate1 = { tanking = true, percent = 100, lead = value }
    Fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    assert(texts[2].value == "" and texts[1].alpha == 0, "Zero tank lead must also be invisible")
end
states.nameplate1 = { tanking = secret, percent = secretZero, lead = secretZero }
Fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
assert(texts[1].value == "" and texts[2].value == "", "All-secret zero data stays invisible")
states.nameplate1 = { tanking = false, percent = 1 }
Fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
assert(texts[1].value == "1%" and badge.shown, "The first nonzero integer must display again")
states.nameplate1 = { tanking = false, percent = 43.1 }
Fire("UNIT_FACTION", "nameplate1")
assert(texts[1].value == "43%")
Remove("nameplate1")
assert(texts[1].value == "" and texts[2].value == "")
Plate("nameplate2", frame)
states.nameplate2 = { tanking = false, percent = 91 }
Add("nameplate2")
assert(creations == 2 and texts[1].value == "91%", "Reuse labels without stale threat")
local preview = Plate("preview")
Add("preview")
assert(preview[1].value == "125%", "Preview uses a sample without reading live player threat")
local previewBadge = plates.preview.UnitFrame.healthBar.badge
assert(previewBadge.shown and previewBadge.alpha == 1 and preview[1].color[1] == 1 and preview[1].color[2] == 0)
for _, position in ipairs({ "LEFT", "TOP", "BOTTOM", "RIGHT" }) do
    PyresinQoLDB.nameplateThreatPosition = position
    module.UpdateNameplateThreat()
    assert(badge.side == position and previewBadge.side == position, "Live settings and preview must share the position")
end
PyresinQoLDB.nameplateThreatPosition = "invalid"
module.UpdateNameplateThreat()
assert(badge.side == "RIGHT" and previewBadge.side == "RIGHT", "Unknown saved positions use the default")
PyresinQoLDB.nameplateThreatPosition = "RIGHT"
role = "TANK"
local tankColors = { [0] = { 1, 1, 1 }, { 1, 1, 0.47 }, { 0.3, 0.7, 1 }, { 0.2, 1, 0.3 } }
for status = 0, 3 do
    states.nameplate2.status = status
    Fire("PLAYER_ROLES_ASSIGNED")
    for _, text in ipairs(texts) do
        assert(table.concat(text.color, ",") == table.concat(tankColors[status], ","))
    end
    assert(preview[1].color[2] == 1, "Tank preview must show positive aggro colors")
end
states.nameplate2.status = secret
Fire("UNIT_THREAT_SITUATION_UPDATE", "nameplate2")
assert(table.concat(texts[1].color, ",") == "1,1,1", "Restricted tank threat stays neutral")
states.nameplate2.status = 3
for _, otherRole in ipairs({ "HEALER", "DAMAGER", "NONE", secret }) do
    role = otherRole
    Fire("GROUP_ROSTER_UPDATE")
    assert(table.concat(texts[1].color, ",") == "1,0,0", "Role changes restore native threat colors")
end
role = "DAMAGER"
PyresinQoLDB.nameplateThreat = false
module.UpdateNameplateThreat()
assert(texts[1].value == "" and preview[1].value == "")
assert(not badge.shown and not previewBadge.shown)
local oldReads, oldCreations = reads, creations
Fire("UNIT_THREAT_LIST_UPDATE", "player")
Plate("nameplate3")
Add("nameplate3")
assert(reads == oldReads and creations == oldCreations, "Disabled display does no work")
states.nameplate3 = { percent = 0 }
PyresinQoLDB.nameplateThreat = true
module.UpdateNameplateThreat()
assert(texts[1].value == "91%" and preview[1].value == "125%")
assert(badge.shown and previewBadge.shown)
Remove("preview")
Plate("nameplate4", { healthBar = {}, forbidden = true, IsForbidden = frame.IsForbidden })
Add("nameplate4")
assert(events.registered.UNIT_HEALTH and not events.registered.NAME_PLATE_UNIT_ADDED)
print("PASS: nameplate percentages, tank lead, secret forwarding, faction/death, recycling, preview and live toggle")
print("PASS: borderless threat-colored text, larger outlined font, right placement and complete cleanup")
print("PASS: tank role colors, live role changes, matching preview and restricted role/status fallback")
print("PASS: zero suppression for public and secret values, empty suffix and nonzero restoration")
print("PASS: four live positions, matching preview, safe defaults and no restricted measurements or polling")

-- Optionally confirm that the pinned native driver calls our lifecycle hooks after setup/release.
if arg[1] then
    CVarCallbackRegistry = { SetCVarCachable = function() end }
    assert(loadfile(arg[1]))()
    local native = setmetatable({}, { __index = NamePlateDriverMixin })
    local ready, released = false, false
    local plate = {
        AcquireUnitFrame = function() ready = true end,
        SetUnit = function(_, unit) assert(ready and unit == "nameplate2") end,
        ClearUnit = function() ready = false end,
        ReleaseUnitFrame = function() released = true end,
    }
    function native:GetNamePlateForUnit() return plate end
    function native:SetupClassNameplateBars() end
    function native:UpdateSoftTargetIcon() end
    native:OnNamePlateAdded("nameplate2")
    assert(ready)
    native:OnNamePlateRemoved("nameplate2")
    assert(not ready and released)
    print("PASS: pinned Blizzard nameplate driver lifecycle")
end

print("PASS: public 999%+ cap, restricted percentage fallback, and tainted FormatNumber rejection")
