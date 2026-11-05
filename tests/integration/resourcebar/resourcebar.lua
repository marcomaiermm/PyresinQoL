-- Run from the addon directory: luajit tests/integration/resourcebar/resourcebar.lua
-- Restricted values are a table, so any Lua arithmetic or comparison on them fails the test.
local secret = setmetatable({}, { __tostring = function() return "secret" end })
function issecretvalue(value) return rawequal(value, secret) end

local function Object(kind)
    local object = { kind = kind, shown = true, points = {}, calls = {} }
    return setmetatable(object, { __index = function(_, key)
        return function(self, ...) self.calls[key] = { ... } end
    end })
end
local frames
local function Frame(kind, parent, template)
    local frame = Object(kind)
    frame.parent, frame.template, frame.events = parent, template, {}
    frame.Dialog = false -- CustomDisplay.lua builds it on first selection
    function frame:SetShown(value) self.shown = value and true or false end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetFrameLevel() return 1 end
    function frame:GetEffectiveScale() return 1 end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function frame:SetValue(value) self.value = value end
    function frame:SetStatusBarTexture(texture) self.texture = texture end
    function frame:SetStatusBarColor(r, g, b, a) self.color = { r, g, b, a } end
    function frame:SetReverseFill(value) self.reverse = value end
    function frame:SetOrientation(value) self.orientation = value end
    function frame:GetStatusBarTexture()
        self.fill = rawget(self, "fill") or Object("fill")
        return self.fill
    end
    function frame:SetScript(script, callback) self[script] = callback end
    function frame:RegisterEvent(event) self.events[event] = true end
    frame.RegisterUnitEvent = frame.RegisterEvent
    function frame:CreateTexture()
        local texture = Object("texture")
        function texture:SetColorTexture(...) self.color = { ... } end
        return texture
    end
    function frame:CreateFontString()
        local text = Object("text")
        function text:SetShown(value) self.shown = value end
        function text:IsShown() return self.shown end
        function text:GetFont() return "font", 10, "OUTLINE" end
        function text:SetFont(_, size) self.size = size end
        function text:SetFormattedText(format, ...) self.format, self.args = format, { ... } end
        frame.text = text
        return text
    end
    frames[#frames + 1] = frame
    return frame
end
function CreateFrame(kind, name, parent, template)
    local frame = Frame(kind, parent, template)
    if name then _G[name] = frame end
    return frame
end

Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3, ComboPoints = 4 },
    StatusBarInterpolation = { ExponentialEaseOut = 1 } }
DRUID_CAT_FORM, DRUID_TRAVEL_FORM, DRUID_ACQUATIC_FORM, DRUID_FLIGHT_FORM = 1, 3, 4, 27
PowerBarColor = { MANA = { r = 0, g = 0, b = 1, atlasElementName = "Mana" }, COMBO_POINTS = { r = 1, g = 0.96, b = 0.41 } }
PowerBarColor[0] = PowerBarColor.MANA
PowerBarColor[1] = { r = 1, g = 0, b = 0, atlasElementName = "Rage" }
CurveConstants = { ScaleTo100 = "curve" }
PixelUtil = { GetPixelToUIUnitFactor = function() return 0.5 end }
UIParent = {}
function CreateColorFromHexString(hex)
    local a, r, g, b = hex:match("(%x%x)(%x%x)(%x%x)(%x%x)")
    local function C(value) return tonumber(value, 16) / 255 end
    return { GetRGB = function() return C(r), C(g), C(b) end, GetRGBA = function() return C(r), C(g), C(b), C(a) end }
end
function GetClassColor(class) return class == "WARLOCK" and 0.58 or 0.2, 0.51, 0.79 end

-- The world the bars read.
local state
local function World(class)
    state = { class = class, combat = false, target = false, mounted = false, form = nil, power = 0,
        current = 400, maximum = 1000, health = 900, healthMax = 1000, combo = 2, comboMax = 5, absorbs = 0,
        spirit = 300, rank = 11689, talent = 0, cvar = "1", cvarWrites = 0 }
end
function UnitClass() return state.class, state.class end
function InCombatLockdown() return state.combat end
function UnitExists() return state.target end
function IsMounted() return state.mounted end
function GetShapeshiftFormID() return state.form end
function UnitPowerType() return state.power end
function UnitPower(_, powerType) return powerType == state.power and state.current or 0 end
function UnitPowerMax(_, powerType)
    if powerType == Enum.PowerType.ComboPoints then return state.comboMax end
    return state.maximum
end
function UnitHealth() return state.health end
function UnitHealthMax() return state.healthMax end
function UnitHealthPercent(_, _, curve) assert(curve == "curve"); return 90 end
function UnitPowerPercent(_, powerType, _, curve) assert(powerType == state.power and curve == "curve"); return 40 end
function UnitGetTotalAbsorbs() return state.absorbs end
function GetComboPoints(unit, target) assert(unit == "player" and target == "target"); return state.combo end
function UnitStat(_, index) assert(index == 5); return 10, state.spirit end
C_SpellBook = { IsSpellKnown = function(id) return id == state.rank end }
C_ClassTalents = { GetActiveConfigID = function() return 7 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 3 } } end,
    GetTreeNodes = function() return { 9 } end,
    GetNodeInfo = function() return { activeEntry = { entryID = 1 }, activeRank = state.talent } end,
    GetEntryInfo = function() return { definitionID = 2 } end,
    GetDefinitionInfo = function() return { spellID = 18182 } end,
}
C_CVar = {
    GetCVar = function(name) assert(name == "nameplateShowSelf"); return state.cvar end,
    SetCVar = function(name, value)
        assert(name == "nameplateShowSelf" and not state.combat, "Client settings wait for the end of combat")
        state.cvar, state.cvarWrites = value, state.cvarWrites + 1
    end,
}

-- Loads PyresinQoL's core and then the resource bar addon's TOC, as the client does with it enabled, and
-- starts its module as PLAYER_LOGIN does.
local ns, module, displays, events, callbacks
local function Load(class, saved)
    World(class)
    frames, displays, callbacks = {}, {}, {}
    PyresinQoLDB = saved or {}
    PyresinQoLDB.profileStore = PyresinQoLDB.profileStore or {}
    EventRegistry = { RegisterCallback = function(_, event, callback, owner)
        callbacks[#callbacks + 1] = { event = event, callback = callback, owner = owner }
    end }
    function GetLocale() return "enUS" end
    ns = {}
    assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
    assert(loadfile("Core/Modules.lua"))("PyresinQoL", ns)
    assert(loadfile("Settings/Controls.lua"))("PyresinQoL", ns)
    -- Edit Mode/CustomDisplay.lua has its own tests; record what the bars hand it.
    function ns.CreateEditModeDisplay(display, info)
        local entry = { info = info, restored = 0 }
        function entry.Restore() entry.restored = entry.restored + 1 end
        displays[info.positionKey], displays[display] = entry, entry
        return entry
    end
    function ns.CreateEditModeOptionsDialog(display, info)
        displays[display].dialog = info
        return function() end
    end
    for line in io.lines("PyresinQoL_ResourceBar/PyresinQoL_ResourceBar.toc") do
        if line:match("%.lua$") then assert(loadfile("PyresinQoL_ResourceBar/" .. line))("PyresinQoL_ResourceBar", {}) end
    end
    module = ns.GetModule("resourceBar")
    assert(module.addon and module.group == "unitFrames" and type(module.buildSettings) == "function")
    assert(not module.resourceBarViews, "Nothing runs before PLAYER_LOGIN")
    -- Settings.lua's controls write through these.
    for _, bar in ipairs(module.resourceBars) do
        for _, option in ipairs(bar.options) do
            option.setting = { SetValue = function(_, value) PyresinQoLDB[option.key] = value; module.UpdateResourceBars() end }
        end
    end
    PyresinQoLDB.modules = {}
    ns.InitializeAddonModules()
    events = nil
    for _, frame in ipairs(frames) do
        if frame.events.UNIT_POWER_FREQUENT then assert(not events, "One event frame drives every bar"); events = frame end
    end
end
local function View(id) return module.resourceBarViews[id] end
local function Fire(event) state.combat = event == "PLAYER_REGEN_DISABLED" or state.combat and event ~= "PLAYER_REGEN_ENABLED"; events.OnEvent(events, event) end
local function Set(key, value) PyresinQoLDB[key] = value; module.UpdateResourceBars() end

-- Visibility: every rule against combat and target.
Load("WARRIOR")
state.power = Enum.PowerType.Rage
for _, case in ipairs({
    { "always", false, false, true }, { "hidden", true, true, false },
    { "combat", false, true, false }, { "combat", true, false, true },
    { "target", false, true, true }, { "target", true, false, false },
    { "targetOrCombat", false, false, false }, { "targetOrCombat", true, false, true }, { "targetOrCombat", false, true, true },
}) do
    local visibility, combat, target, shown = case[1], case[2], case[3], case[4]
    Set("powerBarVisibility", visibility)
    state.target = target
    Fire(combat and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
    assert(View("powerBar").frame.shown == shown, visibility)
end
Set("powerBarVisibility", "always")
assert(not View("healthBar").frame.shown, "The health bar starts hidden, next to the player frame's")
state.mounted = true
Set("powerBarHideMounted", true)
assert(not View("powerBar").frame.shown)
state.mounted, state.form = false, DRUID_TRAVEL_FORM
Fire("UPDATE_SHAPESHIFT_FORM")
assert(not View("powerBar").frame.shown, "Travel forms count as mounted")
state.form = nil
Fire("UPDATE_SHAPESHIFT_FORM")
assert(View("powerBar").frame.shown and not View("comboPointsBar").frame.shown, "Warriors have no combo points")

-- Colors: Blizzard's atlas while the bar keeps its color, rage never takes the mana color.
local cell = View("powerBar").cells[1]
assert(cell.texture == "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage" and cell.color[1] == 1 and cell.color[2] == 1)
Set("powerBarColor", "class")
assert(cell.texture == "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage", "Only mana takes the class or custom color")
state.power = Enum.PowerType.Mana
Fire("UNIT_DISPLAYPOWER")
assert(cell.texture == "Interface\\TargetingFrame\\UI-StatusBar" and cell.color[1] == 0.2)
Set("powerBarColor", "custom")
Set("powerBarCustomColor", "FF336699")
assert(math.abs(cell.color[1] - 0.2) < 0.001 and math.abs(cell.color[3] - 0.6) < 0.001)
assert(cell.color[4] == 1)
Set("powerBarCustomColor", "80336699")
assert(cell.color[4] == 128 / 255, "The custom color keeps its opacity")
Set("powerBarColor", "default")
assert(cell.texture == "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana")
Set("powerBarTexture", "flat")
assert(cell.texture == "Interface\\Buttons\\WHITE8X8" and cell.color[3] == 1)

-- Layout: size, fill direction, border in physical pixels and background.
Set("powerBarFill", "down")
assert(cell.orientation == "VERTICAL" and cell.reverse and cell.points[1][1] == "TOPLEFT")
assert(View("powerBar").frame.width == 200 and View("powerBar").frame.height == 14)
Set("powerBarBorder", "thick")
assert(cell.border.shown and cell.border.calls.SetBackdrop[1].edgeSize == 1, "2 physical pixels at 0.5 UI units each")
Set("powerBarBorder", "none")
assert(not cell.border.shown)
assert(cell.background.color[4] == 128 / 255)

-- Restricted values reach only the native bar and text.
state.current, state.maximum = secret, secret
for format, expected in pairs({ current = "%d", currentMax = "%d / %d", percent = "%.0f%%", both = "%d (%.0f%%)" }) do
    Set("powerBarTextFormat", format)
    Fire("UNIT_POWER_FREQUENT")
    assert(View("powerBar").text.format == expected and cell.value == secret and cell.maximum == secret, format)
end
Set("powerBarTextFormat", "both")
assert(View("powerBar").text.args[1] == secret and View("powerBar").text.args[2] == 40)
Set("powerBarText", false)
assert(not View("powerBar").text.shown)
state.current, state.maximum = 400, 1000

-- Combo points: one native segment per point, filled by the point count, also when restricted.
Load("ROGUE")
local combo = View("comboPointsBar")
assert(combo.frame.shown and #combo.cells == 5 and not combo.text.shown)
for index, segment in ipairs(combo.cells) do
    assert(segment.minimum == index - 1 and segment.maximum == index and segment.value == 2)
end
assert(combo.cells[2].points[1][4] == (200 - 8) / 5 + 2, "Segments run along the fill with their gap")
state.combo = secret
Fire("UNIT_POWER_FREQUENT")
assert(combo.cells[5].value == secret)
state.comboMax = secret
Fire("UNIT_MAXPOWER")
assert(#combo.cells == 5, "A restricted maximum keeps the last readable one")
state.comboMax = 6
Fire("UNIT_MAXPOWER")
assert(combo.cells[6].shown and combo.cells[6].maximum == 6)
Load("DRUID")
assert(not View("comboPointsBar").frame.shown, "Druids show combo points in cat form only")
state.form = DRUID_CAT_FORM
Fire("UPDATE_SHAPESHIFT_FORM")
assert(View("comboPointsBar").frame.shown)

-- Edit Mode: one mover per bar, a short dialog, and every bar of the class shown with a sample.
state.form = nil
Fire("UPDATE_SHAPESHIFT_FORM")
local entry = displays.comboPointsBarPosition
assert(entry and displays.healthBarPosition and displays.powerBarPosition and entry.restored == 1)
assert(entry.info.default[5] == -140 and entry.info.IsAvailable() and entry.info.width.Get() == 200)
local keys = {}
for _, option in ipairs(displays.healthBarPosition.dialog.options) do keys[#keys + 1] = option.key end
assert(#keys == #module.resourceBars[1].options and keys[1] == "healthBarVisibility", "The dialog shows every option")
local sections = {}
for _, option in ipairs(displays.powerBarPosition.dialog.options) do
    if option.section then sections[#sections + 1] = option.section end
end
assert(table.concat(sections, ",") == "Visibility,Size,Appearance,Text,More")
-- Class options only for the classes they are for; their saved values stay.
local function PowerOptions(class)
    Load(class)
    local keys = {}
    for _, option in ipairs(displays.powerBarPosition.dialog.options) do keys[option.key] = true end
    return keys
end
local warlock, mage, warrior = PowerOptions("WARLOCK"), PowerOptions("MAGE"), PowerOptions("WARRIOR")
assert(warlock.powerBarLifeTap and warlock.powerBarColor and warlock.powerBarCustomColor)
assert(not mage.powerBarLifeTap and mage.powerBarColor, "Life Tap is the warlock's")
assert(not warrior.powerBarLifeTap and not warrior.powerBarColor and not warrior.powerBarCustomColor, "No mana color without mana")
assert(warrior.powerBarHidePersonal and module.GetResourceBarOption("powerBarLifeTap") == false)
Load("DRUID")
state.form = nil
Fire("UPDATE_SHAPESHIFT_FORM")
entry = displays.comboPointsBarPosition
entry.info.width.Set(150)
entry.info.OnEnter()
assert(View("comboPointsBar").frame.shown and View("healthBar").frame.shown, "Edit Mode shows hidden bars")
assert(PyresinQoLDB.comboPointsBarWidth == 150 and View("comboPointsBar").frame.width == 150, "Match width")
assert(View("comboPointsBar").cells[1].value == 3, "A sample of combo points")
entry.info.OnExit()
assert(not View("comboPointsBar").frame.shown and not View("healthBar").frame.shown)
local profileCallbacks = 0
for _, callback in ipairs(callbacks) do
    if callback.event == "PyresinQoL.ProfileChanged" then profileCallbacks = profileCallbacks + 1 end
end
assert(profileCallbacks == 4, "A profile switch restyles the bars and moves all three")
Load("WARRIOR")
assert(not displays.comboPointsBarPosition.info.IsAvailable())

-- Health: the class color by option, absorbs continuing the fill.
Set("healthBarVisibility", "always")
local health = View("healthBar")
assert(health.cells[1].texture == "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health" and health.cells[1].value == 900)
Set("healthBarAbsorbs", true)
state.absorbs = secret
Fire("UNIT_ABSORB_AMOUNT_CHANGED")
assert(health.absorbs.shown and health.absorbs.value == secret and health.absorbs.maximum == 1000)
assert(health.absorbs.points[1][2] == health.cells[1].fill and health.absorbs.points[1][3] == "TOPRIGHT")

-- Blizzard's personal resource display: hidden by default, restored when the option is turned off.
Load("MAGE")
assert(state.cvar == "0" and state.cvarWrites == 1)
Fire("PLAYER_TARGET_CHANGED")
assert(state.cvarWrites == 1, "Unchanged client settings are not written again")
Fire("PLAYER_REGEN_DISABLED")
Set("powerBarHidePersonal", false)
assert(state.cvar == "0", "Wait for the end of combat")
Fire("PLAYER_REGEN_ENABLED")
assert(state.cvar == "1" and state.cvarWrites == 2)
state.cvar = "0" -- the player's own choice afterwards stays
Fire("PLAYER_TARGET_CHANGED")
assert(state.cvar == "0" and state.cvarWrites == 2)
Load("MAGE", { powerBarHidePersonal = false })
assert(state.cvarWrites == 0, "Off from the start never touches the client setting")
Load("MAGE")
state.cvar = nil
Set("powerBarHidePersonal", false)
assert(state.cvarWrites == 1 and state.cvar == nil, "An unavailable client setting is not created")
Load("MAGE", { powerBarHidePersonal = false })
state.cvar = "0" -- the player's own choice before the option
Set("powerBarHidePersonal", true)
Set("powerBarHidePersonal", false)
assert(state.cvar == "0" and state.cvarWrites == 0, "Turning the option off restores the player's own value")
local saved = {}
Load("MAGE", saved)
assert(state.cvar == "0" and saved.profileStore.personalDisplay == "1")
-- The addon disabled in the AddOns list: PyresinQoL alone at the next login gives the display back.
ns = {}
assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
assert(loadfile("Core/Modules.lua"))("PyresinQoL", ns)
PyresinQoLDB = saved
ns.InitializeAddonModules()
assert(state.cvar == "1" and saved.profileStore.personalDisplay == nil)
ns.InitializeAddonModules()
assert(state.cvarWrites == 2, "Given back once")

-- Combo points fill whole segments, so they have nothing to smooth.
Load("ROGUE")
for _, option in ipairs(module.resourceBars[3].options) do assert(option.key ~= "comboPointsBarSmooth") end

-- Life Tap: Forever's formula, and the preview from the fill's edge in all four directions.
Load("WARLOCK", { powerBarLifeTap = true })
for points, expected in pairs({ [0] = 730, [1] = 803, [2] = 876 }) do
    state.talent = points
    assert(module.LifeTapManaGain() == expected)
end
for _, sample in ipairs({ { 1454, 30 }, { 1455, 75 }, { 1456, 140 }, { 11687, 220 }, { 11688, 310 }, { 11689, 430 } }) do
    state.rank, state.spirit, state.talent = sample[1], 100, 0
    assert(module.LifeTapManaGain() == sample[2] + 100, "The highest learned rank")
end
state.rank, state.spirit = 11689, 300
Fire("UNIT_STATS")
local preview = View("powerBar").lifeTap
local fill = View("powerBar").cells[1].fill
assert(preview.shown and preview.width == 200 * 0.73 and preview.points[1][2] == fill)
for _, case in ipairs({ { "right", "TOPLEFT", "TOPRIGHT" }, { "left", "TOPRIGHT", "TOPLEFT" },
    { "up", "BOTTOMLEFT", "TOPLEFT" }, { "down", "TOPLEFT", "BOTTOMLEFT" } }) do
    Set("powerBarFill", case[1])
    assert(preview.points[1][1] == case[2] and preview.points[1][3] == case[3], case[1])
end
assert(preview.height == 14 * 0.73, "Vertical bars measure the gain along their height")
state.maximum = 500
Fire("UNIT_MAXPOWER")
assert(preview.height == 14, "The gain is capped at the bar; the cell clips the rest")
state.current = secret
Fire("UNIT_POWER_FREQUENT")
assert(preview.shown, "Restricted current mana keeps the preview")
state.maximum = secret
Fire("UNIT_POWER_FREQUENT")
assert(not preview.shown, "A restricted maximum hides it")
state.maximum, state.spirit = 1000, secret
Fire("UNIT_STATS")
assert(not preview.shown, "Never calculate with restricted Spirit")
state.spirit, state.rank = 300, nil
Fire("SPELLS_CHANGED")
assert(not preview.shown, "No Life Tap learned")
state.rank, state.power = 11689, Enum.PowerType.Rage
Fire("UNIT_DISPLAYPOWER")
assert(not preview.shown)
Load("MAGE", { powerBarLifeTap = true })
assert(not View("powerBar").lifeTap, "Warlocks only")

io.write("PASS: resource bar visibility, colors, layout, restricted values, combo segments, Edit Mode, personal display, Life Tap, loaded as an addon listed under PyresinQoL\n")
