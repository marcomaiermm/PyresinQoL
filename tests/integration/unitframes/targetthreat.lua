-- luajit tests/integration/unitframes/targetthreat.lua
local ns, module, events, combat = {}, {}, nil, false
assert(loadfile("Core/Database.lua"))("PyresinQoL", ns)
for _, case in ipairs({ { nil, "auto" }, { true, "auto" }, { false, "off" },
    { "off", "off" }, { "auto", "auto" }, { "combat", "combat" }, { "always", "always" }, { "invalid", "auto" } }) do
    PyresinQoLDB = { targetThreat = case[1], nameplateThreat = false, custom = "keep" }
    ns.InitializeDatabase()
    ns.InitializeDatabase()
    assert(PyresinQoLDB.targetThreat == case[2] and PyresinQoLDB.nameplateThreat == false
        and PyresinQoLDB.custom == "keep", "Migrate once without changing unrelated settings")
end

local secretValues = {}
local function SecretAccess() error("Addon compared or formatted a secret") end
local function Secret(value)
    local token = setmetatable({}, { __lt = SecretAccess, __le = SecretAccess,
        __concat = SecretAccess, __tostring = SecretAccess })
    secretValues[token] = value
    return token
end
function issecretvalue(value) return secretValues[value] ~= nil end
local function NativeValue(value)
    if issecretvalue(value) then return secretValues[value] end
    return value
end
function InCombatLockdown() return combat end
local states = { target = { tanking = false, percentage = 82, lead = 0, status = 1 }, focus = { absent = true } }
local reads = { target = 0, focus = 0 }
function UnitExists(unit) return not states[unit].absent end
function UnitCanAttack(_, unit) return not states[unit].friendly end
function UnitIsDeadOrGhost(unit) return states[unit].dead end
function UnitDetailedThreatSituation(_, unit)
    reads[unit] = reads[unit] + 1
    local state = states[unit]
    return state.tanking, state.status, 75, state.percentage
end
function UnitThreatPercentageOfLead(_, unit) return states[unit].lead end
function GetThreatStatusColor(status)
    assert(not issecretvalue(status), "Native color lookup cannot receive restricted values")
    return status, 0, 0
end
local cvars = { threatShowNumeric = "0", threatWarning = "0" }
function SetCVar(name, value) assert(cvars[name]); cvars[name] = value end
function hooksecurefunc(owner, method, callback)
    assert(method == "ConfigureAuraContainer", "Do not hook native threat updates or aura placement")
    local original = owner[method]
    owner[method] = function(...) original(...); callback(...) end
end
local function Region()
    local region = { alpha = 1 }
    function region:ClearAllPoints() self.point, self.anchor, self.rect = nil, nil, nil end
    function region:SetPoint(...)
        self.point = { ... }
        local point, owner, relative, x, y = ...
        if point == "LEFT" and type(owner) == "table" and owner.rect then
            assert(relative == "RIGHT")
            local left = owner.rect.right + x
            local bottom = (owner.rect.bottom + owner.rect.top - self.height) / 2 + y
            self.rect = { left = left, right = left + self.width, bottom = bottom, top = bottom + self.height }
        end
    end
    function region:SetAllPoints(owner) self.anchor = owner; self.rect = owner and owner.rect end
    function region:SetSize(width, height) self.width, self.height = width, height end
    function region:SetTexture(path) self.texture = path end
    function region:SetTexCoord(...) self.texCoord = { ... } end
    function region:SetVertexColor(...) self.color = { ... } end
    function region:SetText(text) self.text = NativeValue(text) end
    function region:SetFormattedText(format, value)
        self.argument = value
        self.text = string.format(format, NativeValue(value))
    end
    function region:SetAlpha(alpha) self.alpha = alpha end
    function region:SetAlphaFromBoolean(value, yes, no)
        assert(value ~= nil)
        self.alpha = NativeValue(value) and yes or no
    end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false; self.redraws = (self.redraws or 0) + 1 end
    return region
end
local function Owner()
    local parent = {}
    local native = { GetParent = function() return parent end, shown = false,
        rect = { left = 78, right = 127, bottom = 75, top = 93 } }
    setmetatable(native, { __index = function() error("Do not modify or measure the native indicator") end })
    local owner = { threatNumericIndicator = native, parent = parent,
        rect = { left = 0, right = 232, bottom = 0, top = 100 }, aura = {} }
    function owner:ConfigureAuraContainer()
        -- Pinned TargetFrame.lua: mirrored offset is -6, with 18 added only for native numbers.
        local bottom = 95 - 6 + (native.shown and 18 or 0)
        self.aura.rect = { left = 5, right = 127, bottom = bottom, top = bottom + 21 }
    end
    return owner
end
TargetFrame, FocusFrame = Owner(), Owner()
function CreateFrame(_, _, parent)
    if not parent then
        events = { registered = {} }
        function events:RegisterEvent(event) self.registered[event] = true end
        function events:RegisterUnitEvent(event, ...) self.registered[event] = { ... } end
        function events:UnregisterEvent(event) self.registered[event] = nil end
        function events:SetScript(event, callback) assert(event == "OnEvent"); self.callback = callback end
        return events
    end
    local frame = Region()
    frame.texts, frame.textures = {}, {}
    parent.display = frame
    function frame:CreateTexture(_, layer)
        local texture = Region()
        self.textures[layer] = texture
        return texture
    end
    function frame:CreateFontString(_, layer, font)
        assert(layer == "OVERLAY" and font == "GameFontHighlight")
        local text = Region()
        self.texts[#self.texts + 1] = text
        return text
    end
    return frame
end
ns.RegisterModule = function(id, initialize) assert(id == "unitFrames"); initialize(module) end
PyresinQoLDB = nil
assert(loadfile("Modules/UnitFrames/TargetThreat.lua"))("PyresinQoL", ns)
module.UpdateTargetThreat() -- Files load before SavedVariables and PLAYER_LOGIN.
PyresinQoLDB = {}
ns.InitializeDatabase()
module.UpdateTargetThreat()
assert(not TargetFrame.parent.display, "Do not create regions before login")
local function Fire(event, unit) events.callback(events, event, unit) end
Fire("PLAYER_LOGIN")
assert(not events.registered.PLAYER_LOGIN and cvars.threatShowNumeric == "1" and cvars.threatWarning == "3")
assert(table.concat(events.registered.UNIT_HEALTH, ",") == "target,focus")
assert(events.registered.UNIT_FACTION == true, "Player faction changes also affect target and focus")
local target, focus = TargetFrame.parent.display, FocusFrame.parent.display
assert(target.anchor == TargetFrame.threatNumericIndicator and focus.anchor == FocusFrame.threatNumericIndicator)
assert(target.textures.BACKGROUND.width == 37 and target.textures.BACKGROUND.height == 14)
assert(target.textures.ARTWORK.texture == "Interface\\TargetingFrame\\NumericThreatBorder")
assert(not target.shown and not focus.shown, "Automatic retains native visibility")
local function Mode(value)
    PyresinQoLDB.targetThreat = value
    module.UpdateTargetThreat()
end
local function Text(frame)
    for _, text in ipairs(frame.texts) do if text.alpha == 1 then return text.text end end
end
Mode("always")
assert(cvars.threatShowNumeric == "0" and target.shown and Text(target) == "82%" and not focus.shown)
for _, case in ipairs({
    { name = "tank lead", state = { tanking = true, percentage = 100, lead = 125, status = 3 }, expected = "125%" },
    { name = "zero lead takeover", state = { tanking = true, percentage = 100, lead = 0, status = 3 }, expected = "100%", event = "UNIT_THREAT_SITUATION_UPDATE" },
    { name = "missing lead takeover", state = { tanking = true, percentage = 100, status = 3 }, expected = "100%", event = "UNIT_THREAT_SITUATION_UPDATE" },
    { name = "known tank without percentage", state = { tanking = true, status = 3 }, expected = "100%" },
    { name = "unknown threat", state = {}, expected = "—", event = "PLAYER_TARGET_CHANGED" },
    { name = "confirmed zero", state = { tanking = false, percentage = 0, lead = 0, status = 0 }, expected = "0%" },
}) do
    states.target = case.state
    Fire(case.event or "UNIT_THREAT_LIST_UPDATE")
    assert(target.shown and Text(target) == case.expected, case.name)
end
for _, flag in ipairs({ "friendly", "dead", "absent" }) do
    states.target[flag] = true
    Fire("UNIT_HEALTH", "target")
    assert(not target.shown)
    states.target[flag] = nil
end
states.focus = { tanking = false, percentage = 60, lead = 0, status = 1 }
Fire("PLAYER_FOCUS_CHANGED")
assert(focus.shown and Text(focus) == "60%")
for _, event in ipairs({ "UNIT_HEALTH", "UNIT_FACTION" }) do
    local targetReads, focusReads = reads.target, reads.focus
    local targetDraws, focusDraws = target.redraws, focus.redraws
    Fire(event, "raid20") -- Bypass the engine's registration filter to check the handler too.
    assert(reads.target == targetReads and reads.focus == focusReads
        and target.redraws == targetDraws and focus.redraws == focusDraws,
        "Unrelated units must not query or redraw either threat display")
    Fire(event, "target")
    assert(reads.target == targetReads + 1 and reads.focus == focusReads and focus.redraws == focusDraws)
    Fire(event, "focus")
    assert(reads.target == targetReads + 1 and reads.focus == focusReads + 1)
end
local targetReads, focusReads = reads.target, reads.focus
Fire("UNIT_HEALTH", "player")
assert(reads.target == targetReads and reads.focus == focusReads)
Fire("UNIT_FACTION", "player")
assert(reads.target == targetReads + 1 and reads.focus == focusReads + 1)

local function Overlaps(first, second)
    return first.left < second.right and first.right > second.left
        and first.bottom < second.top and first.top > second.bottom
end
for _, owner in ipairs({ TargetFrame, FocusFrame }) do
    local display, native = owner.parent.display, owner.threatNumericIndicator
    owner.buffsOnTop = true
    owner:ConfigureAuraContainer()
    local bottom = owner.aura.rect.bottom
    assert(Overlaps(native.rect, owner.aura.rect), "The old native footprint overlaps mirrored auras")
    native.shown = true
    owner:ConfigureAuraContainer()
    assert(owner.aura.rect.bottom - bottom == 18, "Native visibility accounts for the reproduced clearance loss")
    native.shown = false
    owner:ConfigureAuraContainer()
    assert(display.shown and not Overlaps(display.rect, owner.aura.rect)
        and not Overlaps(display.rect, native.rect), "Addon placement must clear mirrored auras without native numbers")
    assert(owner.aura.rect.bottom == bottom and native.rect.top == 93,
        "Addon placement must not change native aura or indicator geometry")
    local targetReads, focusReads = reads.target, reads.focus
    owner.buffsOnTop = false
    owner:ConfigureAuraContainer()
    assert(display.anchor == native and display.rect == native.rect, "Restore the original position when mirroring is disabled")
    assert(reads.target == targetReads and reads.focus == focusReads, "Layout updates must not re-query threat")
end
Mode("combat")
assert(not target.shown and not focus.shown)
combat = true
Fire("PLAYER_REGEN_DISABLED")
assert(target.shown and focus.shown)
combat = false
Fire("PLAYER_REGEN_ENABLED")
assert(not target.shown and not focus.shown)
Mode("always")
assert(target.shown and focus.shown, "Mode changes apply immediately")
for _, tanking in ipairs({ false, true }) do
    for _, lead in ipairs({ 0, 125 }) do
        states.target = { tanking = Secret(tanking), percentage = Secret(tanking and 100 or 82),
            lead = Secret(lead), status = Secret(3) }
        Fire("UNIT_THREAT_LIST_UPDATE")
        assert(target.shown and Text(target) == (tanking and "100%" or "82%"))
        assert(target.textures.BACKGROUND.color[1] == 0, "Restricted status uses a neutral color")
        assert(target.texts[1].argument == states.target.percentage, "Forward secret percentages to the display sink")
    end
end
states.target.lead = 125
Fire("UNIT_THREAT_LIST_UPDATE")
assert(Text(target) == "125%", "Select a public lead with the native secret-boolean alpha sink")
states.target.tanking = Secret(false)
Fire("UNIT_THREAT_LIST_UPDATE")
assert(Text(target) == "100%", "Do not treat a secret false tanking token as Lua true")
states.target.percentage = nil
Fire("UNIT_THREAT_LIST_UPDATE")
assert(Text(target) == "—")
Mode("off")
assert(cvars.threatShowNumeric == "0" and not target.shown and not focus.shown and cvars.threatWarning == "3")
cvars.threatWarning = "1"
module.UpdateTargetThreat()
assert(cvars.threatWarning == "1", "Off preserves the player's warning preference")
Fire("UNIT_THREAT_LIST_UPDATE")
assert(not target.shown and not focus.shown)
Mode("auto")
assert(cvars.threatShowNumeric == "1" and cvars.threatWarning == "3" and not target.shown and not focus.shown)
print("PASS: threat visibility, migration, target/focus changes, aggro takeover, restricted values, mirrored layout and scoped unit events")
